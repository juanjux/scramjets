module core.render_view;

import std.variant;
import std.stdio;

import core.request;
import core.request_context;
import core.response;


alias string function(RequestContext) ViewFunction;

HttpResponse response_from_view(ViewFunction view, HttpRequest request, Variant[string] view_params) 
{
    auto context = RequestContext(request, view_params);
    return new HttpResponse(render_view(view, context));
}

HttpResponse response_from_view(ViewFunction view, HttpRequest request, RequestContext context)
{
    return new HttpResponse(render_view(view, context));
}


string render_view(ViewFunction view, RequestContext context) 
{
    return view(context);
}

