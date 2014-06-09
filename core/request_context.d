module core.request_context;

import std.variant;
import core.request;

struct RequestContext
{

    this(HttpRequest request, Variant[string] context)
    {
        _context = context;
        _request = request;

        /* Enable this once context processors are added
         * foreach(ContextProcessor processor; Settings["context_processors"].get!ContextProcessor[])) {
         *  processor(context);
         * }
         */
    }
   
    @property HttpRequest request() { return _request; }
    // XXX: Remove after implementing opApply!
    @property ref Variant[string] context() { return _context; }

    // bla["key"]
    Variant opIndex(string key)
    {
        return _context[key];
    }
    
    // bla["key"] = "blo";
    void opIndexAssign(Variant value, string key)
    {
        _context[key] = value;
    }

    Variant get(string key, Variant def)
    {
        if (key in _context)
            return _context[key];
        return def;
    }

    // XXX: Implement opApply

    private:
        HttpRequest _request;
        Variant[string] _context;
}
