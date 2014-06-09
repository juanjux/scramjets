module core.bindselector;

import std.typecons;
import std.variant;
import std.stdio;
//import std.regexp;
import std.regex;
import std.container;
import core.memory;

import user.controllers;
import user.settings;
import core.urlsupport;
import core.request;
import core.response;
import core.middleware;
import lib.generic_controllers;


struct InternalUrl {
    string regex;
    ControllerFunc controllerfunc;
    Variant[string] userparams;
    // XXX Aniadir una std.regex.Regex compilada como miembro (y probar la estatica de paso?)
}


/* 
 * URLbinder is used to:
 * · Load and keep the URLs, controllers and controller data internally
 * · Compile the regexes so they can be tested quickly
 * · Classify the middlewares defined in the user's configuration
 * · Select the correct controller from a given URL and call it with the right parameters
 */

class URLbinder
{

    // Internal URL definition list
    private SList!InternalUrl url_definition_list;

    // Internal Middleware arrays. MWs are splitted on several arrays depending
    // on the interfaces they implemement, so they are faster to traverse. Please
    // note that a single instance will be on several arrays if it implements 
    // more than one interface
    private Middleware[] _request_mws,
                         _response_mws,
                         _controller_mws,
                         _view_mws,
                         _exception_mws;

    /* Constructor: take the user url definitions and parse them into a 
     * single linked list. Also, add the middlewares to different lists by its types
     */
    this(UrlDefinition[] definitions) {

        // Urls
        foreach_reverse (def; definitions) {
            url_definition_list.insertFront(InternalUrl(def.regex, def.controllerfunc, def.userparams));
        }
        debug foreach (def; url_definition_list) writeln(def.regex);

        // Middlewares
        foreach (mw; site_middlewares) {
            if (cast(IRequestMW)mw) {
                debug writeln("Adding RequestMW: ", mw);
                _request_mws ~= mw;
            }
            if (cast(IResponseMW)mw) {
                debug writeln("Adding ResponseMW: ", mw);
                _response_mws ~= mw;
            }
            if (cast(IControllerMW)mw) {
                debug writeln("Adding ControllerMW: ", mw);
                _controller_mws ~= mw;
            }
            if (cast(IViewMW)mw) {
                debug writeln("Adding ViewMW: ", mw);
                _view_mws ~= mw;
            }
            if (cast(IExceptionMW)mw) {
                debug writeln("Adding ExceptionMW: ", mw);
                _exception_mws ~= mw;
            }
        }
    }

    /**
     * Juanjo: somewhat complicated code, but not really complex logic.
     * This does:
     * 1. Check if some RequestMiddleware wants to take control of the request
     * 2. If not, find the matching URL
     * 3. If a URL (and controller) matched the request, check if some ControllerMiddleware takes control
     * 4. If not, call the matching controller to get the HttpResponse object
     * 5. Finally, apply all the ResponseMiddleware's to the response object and return it
     *
     * - If no controller matches the request, the controller_404 will generate it, with obvious results
     *
     * - If an exception is raised, it will be checked if some ExceptionMiddleware wants to process it. If 
     *   no ExceptionMiddleware generates a not null response, the default controller_500 will do it.
     *
     * That's it
     */
    public HttpResponse call_controller_from_url(string url, HttpRequest request) {
        HttpResponse response = null;

        try {
            // Check if some RequestMiddleware wants to take control here
            foreach (req_mw; _request_mws) {
                response = (cast(IRequestMW)req_mw).process_request(request);
                if (response !is null) 
                    break;
            }

            if (response is null) {
                // No RequestMiddleware took control, check the urls
                foreach (urldef; url_definition_list) {
                    auto mcaptures = match(url, urldef.regex).captures;

                    if (mcaptures.length > 0) {
                        // Bingo, the url matches the regexp
                        // Check if some ControllerMiddleware wants to take control here
                        mcaptures.popFront();

                        foreach (cont_mw; _controller_mws) {
                            response = (cast(IControllerMW)cont_mw).process_controller(urldef.controllerfunc, mcaptures, urldef.userparams, request);
                            if (response !is null) 
                                break;
                        }

                        if (response is null) {
                            // No ControllerMiddleware took control, call the defined Controller
                            response = urldef.controllerfunc(request, mcaptures, urldef.userparams);
                        }
                    }
                }
            }

        } catch (Exception matchex) {
            // Check if some ExceptionMiddleware wants to take control before calling the generic controller_500
            foreach_reverse (exc_mw; _exception_mws) {
                response = (cast(IExceptionMW)exc_mw).process_exception(matchex, request);   
                if (response !is null)
                    break;
            }

            if (response is null) {
                // No ExceptionMiddleware took control, call the default "error 500" controller
                response = controller_500(request, url, matchex);
            }
        }

        if (response is null) {
            // If response is null at this point no URL was found matching the request and no middleware took control;
            // generate a 404 error response
            response = controller_404(request, url);
        }

        // Finally apply all the ResponseMiddlewares to the response object and return it
        assert(response !is null);
        foreach_reverse(resp_mw; _response_mws) {
            (cast(IResponseMW)resp_mw).process_response(response);
        }
        return response;
    }
}


// Test
/*
void main() {
    auto binder = new URLbinder(get_url_selectors());
    Request request = new Request;
    //foreach(i; 1..1000000) {
        binder.call_controller_from_url("/home/", request);
        binder.call_controller_from_url("/user/5434/year/1977/", request);
        binder.call_controller_from_url("/user/12/year/1937/", request);
        binder.call_controller_from_url("/home/", request);
    //}

}
*/
