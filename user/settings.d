module user.settings;

import std.variant;
import std.conv;
import std.container;

import core.middleware;
import user.fakeauthmiddleware;

static Variant[string] Settings = null;
static SList!Middleware site_middlewares;


// XXX: (añadir un comprobador del settings.d, tanto valores obligatorios como tipos)


static this() 
{
    // XXX: Atajo "add_middlewares(FakeAuthMiddleware, PolomposMiddleware)" de modo que
    // se pueda usar directamente en el Variant
    site_middlewares.insertFront(new FakeAuthMiddleware);

    Settings = [
        // File uploads
        "default_charset":             Variant("utf-8"),
        "default_content_type":        Variant("text/html"),
        "file_upload_max_memory_size": Variant(1024UL*1024UL*20UL), // 20 MB
        "file_upload_max_size":        Variant(1024UL*1024UL*40UL), // 40 MB
        "file_upload_temp_dir":        Variant("/tmp"),
        "file_upload_dir":             Variant("/home/juanjux/scramjets/uploads"),
        "file_upload_permissions":     Variant(std.conv.octal!644),
        "file_upload_chunk_size":      Variant(64UL*1024UL), // 64 kbs
        "templates_path":              Variant("/home/juanjux/scramjets/user/templates"),
    ];
}
