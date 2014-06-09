module core.middleware;
 
/++ 
Middleware interfaces. Classes with middlewares should implement one or more (or all) of 
these interfaces
+/
import std.variant;
import std.regex: Captures;

import core.request;
import core.request_context;
import core.response;
import core.urlsupport;
import core.render_view;
 
// Base of all middlewares
abstract class Middleware 
{
}

// Interface definitions for middleware classes
interface IMiddleware
{
}

 
/++
Called on every request, before even resolving the URL to a controller. If the middleware
returns an HttpResponse object instead of null the handling of the request stops and the response is returned after running
the defined ResponseMiddlewares on it
+/
interface IRequestMW: IMiddleware
{
    HttpResponse process_request(ref HttpRequest request);
}
 
/++
Called after the HttpResponse has been generated (by a Controller, an error or another middleware). All defined IResponseMWs will
be called on the middleware, on reverse order of definition.
+/
interface IResponseMW: IMiddleware
{
    void process_response(ref HttpResponse response);
}
 
/++
Called just before calling a controller. If the middleware returns an HttpResponse object instead of null, the handling of
the request stops and the response is returned after running the defined ResponseMiddlewares on it
+/
interface IControllerMW: IMiddleware
{
    HttpResponse process_controller(ControllerFunc controller, Captures!string captures, Variant[string] userparams, HttpRequest request);
}
 
/++
Called just before calling a view. If the middleware returns an HttpResponse object instead of null, the handling of the request stops
and the response is returned after running the defined ResponseMiddlewares on it
+/
interface IViewMW: IMiddleware
{
    HttpResponse process_view(ViewFunction view, RequestContext context);
}
 
/++
Called when an exception is catched on the top level of the cycle handler. If the middleware returns a HttpResponse object instead of null,
the Response will be returned after running the defined ResponseMiddlewares on it. If all IMiddlewares return null, the exception will be raised
+/
interface IExceptionMW: IMiddleware
{
    HttpResponse process_exception(Exception exc, HttpRequest request);
}

