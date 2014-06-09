module core.urlsupport;

import std.typecons;
import std.variant;
import std.regex: Captures;

import core.request;
import core.response;

alias HttpResponse function(HttpRequest, Captures!string, Variant[string]) ControllerFunc;

// Shortcut to use when no params are specified
Variant[string] noparams;

struct UrlDefinition {
    string regex;
    ControllerFunc controllerfunc;
    Variant[string] userparams;

    this(string regex, ControllerFunc controllerfunc, Variant[string] userparams) {
        this.regex = regex;
        this.controllerfunc = controllerfunc;
        this.userparams = userparams; 
    }
}

