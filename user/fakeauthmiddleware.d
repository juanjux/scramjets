module user.fakeauthmiddleware;

import std.stdio;
import std.variant;
import std.regex;
import core.middleware;
import core.response;
import core.request;
import core.request_context;
import core.urlsupport;
import core.render_view;

class FakeAuthMiddleware: Middleware, IRequestMW, IResponseMW, IExceptionMW, IControllerMW, IViewMW
{
    // IRequestMW
    HttpResponse process_request(ref HttpRequest request) { 
        debug writeln("In FakeAuthMiddleware's process_request");
        return null; 
    }

    // IResponseMW
    void process_response(ref HttpResponse request) {
        debug writeln("In FakeAuthMiddleware's process_response");
    } 

    // IControllerMW
    HttpResponse process_controller(ControllerFunc controller, Captures!string named_groups, Variant[string] userparams, HttpRequest request) {
        debug writeln("In FakeAuthMiddleware's process_controller");
        return null;
    }

    // IViewMW
    HttpResponse process_view(ViewFunction view, RequestContext context) {
        debug writeln("In FakeAuthMiddleware's process_view");
        return null;
    }

    // IExceptionMW
    HttpResponse process_exception(Exception exc, HttpRequest request) {
        debug writeln("In FakeAuthMiddleware's process_exception");
        return null;
    }
}


