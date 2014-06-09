import std.string;
import std.conv;
import std.array;
import std.stdio;
import template_support; // XXX ruta completa
import std.variant;
import parse_template;


// XXX Implementar:
// if / else
// autoscape
// cycle
// debug
// filter
// firstof
// ifchanged
// ifequal
// include
// now
// regroup
// spaceless
// ssi
// url
// verbatim
// withratio
// with
// trans

string toupper_(CommandInfo cinfo, ref DJTemplateParser parser)
{
    return toUpper(cinfo.text);
}

string comment(CommandInfo cinfo, ref DJTemplateParser parser)
{
    return "";
}

// XXX implementar
string verbatim(CommandInfo cinfo, ref DJTemplateParser parser)
{
    writeln("XXX procesando verbatim ", cinfo.parameters);
    return cinfo.text;
}

// XXX implementar
string trans(CommandInfo cinfo, ref DJTemplateParser parser)
{
    return "XXX___COMANDO_TRANS___XXX";
}


string repeat(CommandInfo cinfo, ref DJTemplateParser parser)
{
    auto paramtokens = std.array.split(cinfo.parameters);
    if (paramtokens.length != 2)
        throw new TemplateException("repeat command must have two parameters");

    auto numtimes = to!int(paramtokens[0]);
    auto var = paramtokens[1];
    
    Appender!string app;
    auto save = parser.getContextVar(var);
    
    for(size_t i=0; i < numtimes; i++) {
        parser.setContextVar(var, Variant(i));
        size_t lineidx = 0;
        size_t col = 0;
        parser.processText(cinfo.unproc_lines, lineidx, col, app);
    }
    parser.removeContextVar(var);

    if (save) parser.setContextVar(var, *save);

    return app.data;
}


string for_(CommandInfo cinfo, ref DJTemplateParser parser)
{
    auto paramtokens = std.array.split(cinfo.parameters);
    if (paramtokens.length != 3)
        throw new TemplateException("\"for\" command must have two parameters");

    if (paramtokens[1] != "in")
        throw new TemplateException(xformat("wrong \"for\" command: %s %s", cinfo.name, cinfo.parameters));

    //writeln("XXX a");
    auto iterable = parser.getContextVarFromStr(paramtokens[2]);
    if (iterable == Variant("")) // probably inner loop and variable from the outer loop not yet set
        return cinfo.text;

    //writeln("XXX b");
    Appender!string app;
    auto save = parser.getContextVar(paramtokens[0]);

    //writeln("XXX c");
    foreach(Variant i; iterable) {
        parser.setContextVar(paramtokens[0], i);
        size_t lineidx = 0;
        size_t col = 0;
        parser.processText(cinfo.unproc_lines, lineidx, col, app);
    }
    //writeln("XXX d");
    parser.removeContextVar(paramtokens[0]);

    if (save) parser.setContextVar(paramtokens[0], *save);

    //writeln("XXX e");
    return app.data;
}


class DefaultTemplateLib : TemplateLib
{
    this() 
    {
        name = "DefaultLib";
        libCommands = ["toupper":  TemplateCommand(&toupper_, true),
                       "comment":  TemplateCommand(&comment, true),
                       "verbatim": TemplateCommand(&verbatim, true),
                       "trans":    TemplateCommand(&trans, false),
                       "extends":  TemplateCommand(null, false), // implemented internally in the parser
                       "block":    TemplateCommand(null, true),  // idem
                       "repeat":   TemplateCommand(&repeat, true),
                       "for":      TemplateCommand(&for_, true),

        ];
    }
}
