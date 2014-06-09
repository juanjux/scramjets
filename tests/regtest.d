import std.stdio, std.regex;

void testmatch(string str, string regex) {
    writeln("\n", regex, " => ", str);
    auto matchobj = match(str, regex);
    auto cap = matchobj.captures;

    if (cap.empty)
        writeln("NOOOOOOOOOO");
    else
        writeln("SIIIIIIIIII");
        if (cap.length > 1) {
            writeln(cap.length -1, " subgrupo", cap.length > 2? "s:" : ": ");
            cap.popFront();
            foreach(m; cap)
                writeln(m);
     
            try {
                writeln("Named con clave year: ", cap["year"]);
            } catch (core.exception.RangeError)
                writeln("No tiene el named year");

            try {
                writeln("Named con clave month: ", cap["month"]);
            } catch (core.exception.RangeError)
                writeln("No tiene el named month");
        }
}

void main() {
    string url_simple  = r"^articles/2003/$";
    string url_uno_pos = r"^articles/(\d{4})/$";
    string url_dos_pos = r"^articles/(\d{4})/(\d{2})/$";
    string url_dos_pos_variable = r"^articles/(\d{4})/(\d+)/$";
    string url_uno_named = r"^articles/(?P<year>\d{4})/$";
    string url_dos_named = r"^articles/(?P<year>\d{4})/(?P<month>\d{2})/$";
    string url_uno_pos_uno_named = r"^articles/(\d{4})/(?P<month>\d{2})/$";
    
    string test1 = "articles/2003/";

/*    testmatch(test1, url_simple);*/
    //testmatch("polompos", url_simple);
    //testmatch(test1, url_uno_pos);
    //testmatch("polompos", url_uno_pos);
    //testmatch(test1, url_dos_pos);

    string test2 = "articles/2003/10/";
    //testmatch(test2, url_simple);
    //testmatch(test2, url_uno_pos);
    //testmatch(test2, url_dos_pos);
    //testmatch(test2, url_dos_pos_variable);

    string test3 = "articles/2003/123/";
    //testmatch(test3, url_dos_pos);
    /*testmatch(test3, url_dos_pos_variable);*/

    testmatch(test2, url_dos_named);
}
