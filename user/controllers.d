module user.controllers;

import std.stdio;
import std.variant;
import std.conv;
import std.regex: Captures;

import core.request;
import core.response;
import core.render_view;
// FIXME: Cambiar a core.render_template
import core.template_parser;

import user.views.main;


HttpResponse index(HttpRequest request, Captures!string urlargs, Variant[string] userargs) 
{

    // Some example params added by the controller
    Variant[string] viewargs = ["polompos": Variant("1"), "pok": Variant("valorpork")];

    // Forwarding urlargs (usually not needed, you're expected to do something with it here)
    auto idx = 0;
    foreach (arg; urlargs) {
        ++idx;
        viewargs["urlarg_" ~ to!string(idx)] = Variant(arg);
    }

    // Forwarding user controller args, same as before
    foreach (key, value; userargs) 
        viewargs["userarg_" ~ key] = value;

    return response_from_view(&user.views.main.index, request, viewargs);
}


HttpResponse index_template(HttpRequest request, Captures!string urlargs, Variant[string] userargs)
{
     // Some example params added by the controller
    Variant[string] viewargs = ["polompos": Variant("1"), "pok": Variant("valorpork")];

    // Forwarding urlargs (usually not needed, you're expected to do something with it here)
    auto idx = 0;
    foreach (arg; urlargs) {
        ++idx;
        viewargs["urlarg_" ~ to!string(idx)] = Variant(arg);
    }

    // Forwarding user controller args, same as before, usually not passed to template
    foreach (key, value; userargs) 
        viewargs["userarg_" ~ key] = value;

    viewargs["title"] = "Template Test";
    return response_from_template("index.tmpl", request, viewargs);
}


HttpResponse testform(HttpRequest request, Captures!string urlargs, Variant[string] userargs)
{
    Variant[string] viewargs;

    if ("multi" in userargs && userargs["multi"].get!bool == true) {
        return response_from_view(&user.views.main.testform_multipart, request, viewargs);
    }
 
    return response_from_view(&user.views.main.testform, request, viewargs);
}
