import std.string;
import std.conv;
import std.datetime;
import std.c.time;
import std.array;
import std.stdio;
import std.variant;
import std.path;
import std.file;
import std.algorithm;
import std.regex;
import std.typecons;

import template_support; 
import parse_template;

// XXX Implementar:

// csrf_token

// if / ifexists / ifequal / ifnotequal / ifempty / ifnotempty / ifchanged (+else)

// filter: cuando implemente los filtros

// XXX fuera, deberia ser un filtro
string toupper_(CommandInfo cinfo, ref DJTemplateParser parser)
{
    return toUpper(cinfo.text);
}


string comment(CommandInfo cinfo, ref DJTemplateParser parser)
{
    return "";
}


string repeat(CommandInfo cinfo, ref DJTemplateParser parser)
{
    auto paramtokens = std.array.split(cinfo.parameters);
    if (paramtokens.length != 2)
        throw new TemplateException("repeat command must have two parameters");

    auto numtimes = to!int(paramtokens[0]);
    auto var = paramtokens[1];
    
    Appender!string app;
    auto saveptr = parser.context.get(var);
    
    for(size_t i=0; i < numtimes; i++) {
        parser.context.set(var, Variant(i));
        size_t lineidx = 0;
        size_t col = 0;
        parser.processText(cinfo.unproc_lines, lineidx, col, app);
    }
    parser.context.remove(var);

    if (saveptr) parser.context.set(var, *saveptr);

    return app.data;
}


string with_(CommandInfo cinfo, ref DJTemplateParser parser)
{
    auto paramtokens = std.array.split(cinfo.parameters, "=");
    if (paramtokens.length != 2) {
        throw new TemplateException("\"with\" command must have the format: with alias=var");
    }
    
    // XXX cambiar
    auto source = parser.context.getFromStr(paramtokens[1]);

    // No error control; if it doesnt exists it will be aliases to ""

    auto saveptr = parser.context.get(paramtokens[0]);
    parser.context.set(paramtokens[0], source);

    Appender!string app;
    size_t linepos, colpos;
    parser.processText(cinfo.unproc_lines, linepos, colpos, app);
    parser.context.remove(paramtokens[0]);

    if (saveptr) parser.context.set(paramtokens[0], *saveptr);
    

    return app.data;
}


string for_(CommandInfo cinfo, ref DJTemplateParser parser)
{
    auto paramtokens = std.array.split(cinfo.parameters);
    if (paramtokens.length != 3)
        throw new TemplateException("\"for\" command must have two parameters");

    if (paramtokens[1] != "in")
        throw new TemplateException(format("wrong \"for\" command: %s %s", cinfo.name, cinfo.parameters));

    auto iterable = parser.context.getFromStr(paramtokens[2]);
    if (iterable == Variant("")) // probably inner loop and variable from the outer loop not yet set
        return cinfo.text;

    auto saveptr = parser.context.get(paramtokens[0]);

    Appender!string app;
    foreach(Variant i; iterable) {
        parser.context.set(paramtokens[0], i);
        size_t lineidx = 0;
        size_t col = 0;
        parser.processText(cinfo.unproc_lines, lineidx, col, app);
    }
    parser.context.remove(paramtokens[0]);

    if (saveptr) parser.context.set(paramtokens[0], *saveptr);

    return app.data;
}


string cycle(CommandInfo cinfo, ref DJTemplateParser parser)
{
    auto paramtokens = std.array.split(cinfo.parameters);

    if (paramtokens.length == 0) 
        throw new TemplateException("{% cycle %} command needs arguments");

    // See if we have been already called
    auto pseudohash = format("__cycle#%s", cinfo.parameters);
    Variant found = parser.context.getFromStr(pseudohash);
    size_t index;

    if (found == Variant("")) {
        // First time found, return the first element and save the internal context var
        index = 0;
    } else {
        index = found.get!size_t;
        index = ++index >= paramtokens.length ? 0 : index;
    }
    parser.context.set(pseudohash, Variant(index));

    auto toret = paramtokens[index];
    Variant ret = null;
    if ((toret.length > 2 && toret[0] == '"' && toret[$-1] == '"') || isDigitString(toret)) // string {
    {
        ret = Variant(paramtokens[index]); 
    }
    else { // context var 
        ret = parser.context.getFromStr(paramtokens[index]);
    }

    return ret.toString;
}


string debug_(CommandInfo cinfo, ref DJTemplateParser parser)
{
    Appender!string dbgInfo;

    dbgInfo.put("<hr/>\nDEBUG INFORMATION\n");
    dbgInfo.put("<h2>Context Vars: </h2>\n<ul>\n");
    dbgInfo.put(parser.context.toString());
    dbgInfo.put("<h2>Registered Commands: </h2>\n<ul>\n");
    foreach(key; parser.templateCommands.byKey()) {
        dbgInfo.put(format("<li>%s</li>\n", key));
    }
    dbgInfo.put("</ul>\n");

    dbgInfo.put(format("<h2>Template name: %s</h2>\n", parser.name));
    dbgInfo.put(format("<h2>Template path: %s</h2>\n", parser.fullPath));
    
    dbgInfo.put("<hr/>\n");
    return dbgInfo.data;
}


string include(CommandInfo cinfo, ref DJTemplateParser parser)
{
    auto temp_name = cinfo.parameters.removechars("\"");

    if (temp_name.length == 0)
        throw new TemplateException("\"include\" command must have one parameter (the template name)");


    auto second = new DJTemplateParser(temp_name, parser.searchPaths, parser.context);
    second.render();
    return second.result;
}


string ssi(CommandInfo cinfo, ref DJTemplateParser parser)
{
    

    auto matches = match(cinfo.parameters, QUOTED_REGEX);
    if (matches.empty)
        throw new TemplateException("SSI command without argument(s)");

    string[] params;
    foreach(match; matches) {
        params ~= match.hit;
    }

    if (params.length > 3) 
        throw new TemplateException(format("SSI command can have 2 or 3 parameters, not: %s", cinfo.parameters));
    if (params.length == 2 && params[1] != "parsed")
        throw new TemplateException(format("SSI command 2nd parameter, if exists, can only be \"parsed\", not: %s", params[1]));
    if (!isValidPath(params[0]))
        throw new TemplateException(format("Invalid path for SSI command: %s", cinfo.parameters));
    if (!exists(params[0]))
        throw new TemplateException(format("Path given to SSI command doesnt exists: %s", params[0]));

    bool found = false;
    version(Windows) { auto lowPath = toLower(params[0]); }

    foreach(allowed; parser.allowedIncludeRoots) {
        version(Windows) {
            if (startsWith(lowPath, toLower(allowed))) {
                found = true;
                break;
            }
        }
        version(Posix) {
            if (startsWith(params[0], allowed)) {
                found = true;
                break;
            }
        }
    }
    if (!found)
        throw new TemplateException(format("Path given to SSI not in allowed include roots: %s", params[0]));

    if (params.length == 1) 
        return readText(params[0]);
    
    // parsed used
    auto second = new DJTemplateParser(params[0], parser.context);
    second.render();
    return second.result;
}


string firstof(CommandInfo cinfo, ref DJTemplateParser parser)
{
    auto vars = std.array.split(cinfo.parameters);
    if (vars.length > 0) {
        // Loop over the vars and return the first that exists and have a value != ""
        foreach(ref var; vars) {
            auto value = parser.context.getFromStr(var);
            if (value != Variant("")) {
                return value.toString;
            }
        }
    }
    return "";
}


string templatetag(CommandInfo cinfo, ref DJTemplateParser parser) 
{
    auto cmd = cinfo.parameters;

    switch (cmd) {
        case "openblock":     return COMMAND_OPEN_TAG;
        case "closeblock":    return COMMAND_CLOSE_TAG;
        case "openvariable":  return VAR_OPEN_TAG;
        case "closevariable": return VAR_CLOSE_TAG;
        case "openbrace":     return "{";
        case "closebrace":    return "}";
        case "opencomment":   return ONELINECOMMENT_OPEN_TAG;
        case "closecomment":  return ONELINECOMMENT_CLOSE_TAG;
        default:              return "";
    }
    return "";
}


string now(CommandInfo cinfo, ref DJTemplateParser parser)
{
    immutable(char[]) ampm(const tm* tms, Flag!"withdots" dotted, Flag!"lowered" lower) {
        char[3] b;
        auto len = strftime(b.ptr, b.length, toStringz("%p"), tms);
        if (len == 2) {
            char[] res = b[0..2];
            if (lower) {
                res = toLower(b[0..2]);
            }
            if (dotted) {
                res.length = 4;
                res = to!(char[])(format("%s.%s.", res[0], res[1]));
            }
            return res.idup;
        }
        return [];
    }

    char[] unzeroed(in char[] input) {
        return to!(char[])( to!(int)(input.dup) );
    }

    char[] simplehour(const tm* tms, Flag!"withampm" withmeridian) {
        char[3] bfhour, bfmin;
        char[] buffer;
        auto lenhour = strftime(bfhour.ptr, bfhour.length, toStringz("%I"), tms);
        auto lenmin  = strftime(bfmin.ptr, bfmin.length, toStringz("%M"), tms);
        if (lenhour > 0 && lenmin > 0) {
            buffer ~= unzeroed(bfhour[0..2]);
            if (bfmin[0..2] != ['0', '0']) {
                buffer ~= ":" ~ bfmin[0..2].dup;
            }
        }

        if (withmeridian) {
            buffer ~= " " ~ ampm(tms, Yes.withdots, Yes.lowered);
        }
        return buffer;
    }

    auto format = cinfo.parameters;
    if (format.length == 0) {
        // Shortcut, no parameters
        cinfo.parameters = "\"c, p\"";
        return now(cinfo, parser);
    }

    if (format.length < 3 || format[0] != '"' || format[$-1] != '"')
        throw new TemplateException("{% now %} arguments must be \"quoted\"!");

    // Remove quotes
    format = format[1..$-1];

    char[] buffer;
    auto systime = Clock.currTime;
    auto unix_t = systime.toUnixTime();
    tm* tms = localtime(&unix_t);

    // FIXME: this could be optimized converting the format strings
    // and only calling strftime at the end, but we're also calling D's
    // datetime functions so it would be a little messy. This should be
    // changed once D's datetime has a strftime-alike function

    bool escapeNext = false;
    foreach(char c; format) {
        if (escapeNext) {
            buffer ~= c;
            escapeNext = false;
            continue;
        }
        switch(c) {
            case 'a': // a.m. / p.m.
                buffer ~= ampm(tms, Yes.withdots, Yes.lowered);
                break;

            case 'A': // AM / PM
                buffer ~= ampm(tms, No.withdots, No.lowered);
                break;

            case 'b': // jan / feb / apr
                char[4] bb;
                auto len = strftime(bb.ptr, bb.length, toStringz("%b"), tms);
                if (len == 3) {
                    buffer ~= toLower(bb[0..1]) ~ bb[1..3].dup;
                }
                break;

            case 'c': // 2012-09-03
                buffer ~= (cast(Date)systime).toISOExtString();
                break;

            case 'd': // month day with 0: 01 to 31
                char[3] bd;
                auto len = strftime(bd.ptr, bd.length, toStringz("%d"), tms);
                if (len == 2) {
                    buffer ~= bd[0..2].dup;
                }
                break;

            case 'D': // Weekday: Mon Fri Sun
                char[4] bD;
                auto len = strftime(bD.ptr, bD.length, toStringz("%a"), tms);
                if (len == 3) {
                    buffer ~= bD[0..3].dup;
                }
                break;

            case 'e':
            case 'T': // timezone 
                char[64] be;
                auto len = strftime(be.ptr, be.length, toStringz("%Z"), tms);
                if (len > 0) {
                    buffer ~= be[0..len].dup;
                }
                break;

            case 'E': // january / february
                char[64] bE;
                auto len = strftime(bE.ptr, bE.length, toStringz("%B"), tms);
                if (len > 0) {
                    buffer ~= toLower(bE[0..1]) ~ bE[1..len].dup;
                }
                break;

            case 'f':  // hour: 1 / 1:12 / 2:09 / 11:33
                buffer ~= simplehour(tms, No.withampm);
                break;

            case 'F': // September / January
                 char[64] bF;
                auto len = strftime(bF.ptr, bF.length, toStringz("%B"), tms);
                if (len > 0) {
                    buffer ~= bF[0..len].dup;
                }
                break;

            case 'g': // 12-hour without leading zeroes
                char[3] bg;
                auto len = strftime(bg.ptr, bg.length, toStringz("%I"), tms);
                if (len > 0) {
                    buffer ~= unzeroed(bg[0..len]);
                }
                break;

             case 'G': // 24-hour without leading zeroes
                char[3] bG;
                auto len = strftime(bG.ptr, bG.length, toStringz("%H"), tms);
                if (len > 0) {
                    buffer ~= unzeroed(bG[0..len]);
                }
                break;

            case 'h': // 12-hour with zeros
                char[3] bh;
                auto len = strftime(bh.ptr, bh.length, toStringz("%I"), tms);
                if (len > 0) {
                    buffer ~= bh[0..len].dup;
                }
                break;

            case 'H': // 24-hour with zeros
                char[3] bH;
                auto len = strftime(bH.ptr, bH.length, toStringz("%H"), tms);
                if (len > 0) {
                    buffer ~= bH[0..len].dup;
                }
                break;

             case 'i': // Minutes with zero
                char[3] bi;
                auto len = strftime(bi.ptr, bi.length, toStringz("%M"), tms);
                if (len > 0) {
                    buffer ~= bi[0..2].dup;
                }
                break;

            case 'j': 
                char[3] bj;
                auto len = strftime(bj.ptr, bj.length, toStringz("%d"), tms);
                if (len > 0) {
                    buffer ~= unzeroed(bj[0..2]);
                }
                break;

             case 'l': 
                char[64] bl;
                auto len = strftime(bl.ptr, bl.length, toStringz("%A"), tms);
                if (len > 0) {
                    buffer ~= bl[0..len].dup;
                }
                break;

             case 'm': // month number with zeroes
                char[3] bm;
                auto len = strftime(bm.ptr, bm.length, toStringz("%m"), tms);
                if (len > 0) {
                    buffer ~= bm[0..2].dup;
                }
                break;

              case 'M': // Month short name like Jan
                char[4] bM;
                auto len = strftime(bM.ptr, bM.length, toStringz("%b"), tms);
                if (len > 0) {
                    buffer ~= bM[0..3].dup;
                }
                break;

             case 'n': // month number without zeroes
                char[3] bn;
                auto len = strftime(bn.ptr, bn.length, toStringz("%m"), tms);
                if (len > 0) {
                    buffer ~= unzeroed(bn[0..2]);
                }
                break;

            case 'p': // 1.42 p.m.
                buffer ~= simplehour(tms, Yes.withampm); 
                break;


            case 'r': // RFC822
                // FIXME: different in Windows
                char[64] br;
                auto len = strftime(br.ptr, br.length, toStringz("%c"), tms);
                if (len > 0) {
                    buffer ~= br[0..len].dup;
                }

             case 's': // seconds with zeroes 
                char[3] bs;
                auto len = strftime(bs.ptr, bs.length, toStringz("%S"), tms);
                if (len > 0) {
                    buffer ~= bs[0..2].dup;
                }
                break;

            case 't': // days in month
                buffer ~= to!(char[])(systime.daysInMonth());
                break;

            case 'U': // unix time
                buffer ~= to!(char[])(systime.toUnixTime());
                break;

            case 'w': // day of week, number, sunday = 0
                char[2] bw;
                auto len = strftime(bw.ptr, bw.length, toStringz("%w"), tms);
                if (len > 0) {
                    buffer ~= bw[0..1].dup;
                }
                break;

            case 'W': // number of week in the year, 1-53
                char[3] bW;
                auto len = strftime(bW.ptr, bW.length, toStringz("%W"), tms);
                if (len > 0) {
                    buffer ~= bW[0..2].dup;
                }
                break;

            case 'y': // year, two digits
                char[3] by;
                auto len = strftime(by.ptr, by.length, toStringz("%y"), tms);
                if (len > 0) {
                    buffer ~= by[0..2].dup;
                }
                break;

            case 'Y': // year, four digits
                char[5] bY;
                auto len = strftime(bY.ptr, bY.length, toStringz("%Y"), tms);
                if (len > 0) {
                    buffer ~= bY[0..4].dup;
                }
                break;

            case 'z': // day of the year, 0-365
                char[4] bz;
                auto len = strftime(bz.ptr, bz.length, toStringz("%j"), tms);
                if (len > 0) {
                    buffer ~= to!(char[])(to!(int)(bz[0..3].dup)-1);
                }
                break;

            case '\\':
                escapeNext = true;
                break;

            default:
                buffer ~= c;
                break;
        }
    }
    return to!string(buffer);
}


string spaceless(CommandInfo cinfo, ref DJTemplateParser parser)
{
    Appender!string app;
    size_t linepos, colpos;
    parser.processText(cinfo.unproc_lines, linepos, colpos, app);
    return std.regex.replace(app.data, SPACE_BETWEEN_TAGS_REGEX, "><");
}

string autoescape(CommandInfo cinfo, ref DJTemplateParser parser)
{
    if (cinfo.parameters.length == 0)

    if (cinfo.parameters.length == 0 || (cinfo.parameters != "on" && cinfo.parameters != "off"))
        throw new TemplateException("\"autoscape\" must have a parameter (on or off)");

    auto saved_autoescape = parser.context.autoescape;

    bool toescape = (cinfo.parameters == "on");
    parser.context.autoescape = toescape;
    size_t linepos, colpos;
    Appender!string app;
    parser.processText(cinfo.unproc_lines, linepos, colpos, app);

    parser.context.autoescape = saved_autoescape;

    return app.data;

}

string verbatim(CommandInfo cinfo, ref DJTemplateParser parser)
{
    return std.string.join(cinfo.unproc_lines, "\n");
}


class DefaultTemplateLib : TemplateLib
{
    this() 
    {
        name = "DefaultLib";
        libCommands = ["toupper":  TemplateCommand(&toupper_, Yes.HasContext),
                       "comment":  TemplateCommand(&comment, Yes.HasContext),
                       "verbatim": TemplateCommand(&verbatim, Yes.HasContext),
                       "extends":  TemplateCommand(null, No.HasContext), // implemented internally in the parser
                       "block":    TemplateCommand(null, Yes.HasContext),  // idem
                       "repeat":   TemplateCommand(&repeat, Yes.HasContext),
                       "for":      TemplateCommand(&for_, Yes.HasContext),
                       "cycle":    TemplateCommand(&cycle, No.HasContext),
                       "debug":    TemplateCommand(&debug_, No.HasContext),
                       "include":  TemplateCommand(&include, No.HasContext),
                       "ssi":      TemplateCommand(&ssi, No.HasContext),
                       "templatetag": TemplateCommand(&templatetag, No.HasContext),
                       "with":     TemplateCommand(&with_, Yes.HasContext),
                       "now":      TemplateCommand(&now, No.HasContext),
                       "firstof":  TemplateCommand(&firstof, No.HasContext),
                       "spaceless":TemplateCommand(&spaceless, Yes.HasContext),
                       "autoescape": TemplateCommand(&autoescape, Yes.HasContext),
                       "verbatim": TemplateCommand(&verbatim, Yes.HasContext),

        ];
    }
}
