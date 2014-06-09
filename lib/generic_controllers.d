module lib.generic_controllers;

import std.stdio;

import core.request;
import core.response;
import lib.htmlutils;
import lib.httpstatus;

// XXX: use the user provided controller if its defined
HttpResponse controller_404(const HttpRequest request, string url) 
{
    return new HttpResponse("<h1>Error 404</h1> Page not found: <br/> " ~ url, StatusCode.NOTFOUND);
}

HttpResponse controller_500(const HttpRequest request, string url, Exception ex) 
{
    return new HttpResponse("<h1>Error 500</h1> " ~ newlinetobr(ex.toString()), StatusCode.INTERNALSERVERERROR);
}
