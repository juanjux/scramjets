module user.urls;

private import std.variant;

private import core.urlsupport;
private import lib.generic_controllers;
private import user.controllers;

UrlDefinition[] get_url_selectors() {
     UrlDefinition[] urldefs = [
        UrlDefinition(r"^/home/$",                    &user.controllers.index,    ["debug": Variant(true), "security": Variant("ssl")]),
        UrlDefinition(r"^/template/$",                &user.controllers.index_template, ["debug": Variant(true), "security": Variant("ssl"), "anumber": Variant(42)]),  
        UrlDefinition(r"^/post/$",                    &user.controllers.testform, noparams),
        UrlDefinition(r"^/post/multi/$",              &user.controllers.testform, ["multi": Variant(true)]),
    ];
    return urldefs;
}
