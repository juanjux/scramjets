module core.template_parser;

import std.file;
import std.path;
import std.conv;
import std.variant;
import std.string;
import std.stdio;
import std.array;

import core.request;
import core.request_context;
import core.response;

import user.settings;

HttpResponse response_from_template(string template_file, HttpRequest request, Variant[string] view_params)
{
    auto context = RequestContext(request, view_params);
    return new HttpResponse(parse_template(template_file, request, view_params));
}


string parse_template(string name, HttpRequest request, Variant[string] view_params) 
{
    // FIXME: exists, is readable, is file, etc... (do it a function)
    char[] temp_text = to!(char[]) (readText(std.path.buildPath( Settings["templates_path"].get!string, name )));

    // 1. Resolve inserts [-insert: "subtemplate" -]
    execute_inserts(temp_text);
    // 2. Replace variable values [[variable]]
    execute_substitutions(temp_text, request, view_params);

    return to!string(temp_text);
}


void execute_inserts(ref char[] temp_text)
{
    // FIXME: Ignore escaped commands: \[-insert "blabla" \-]
    char[] final_text;
    uint current_pos;
    auto relative_pos = -1;
    uint relative_endpos;
    string command_str = "[-insert:";

    do {
        // Search for the start of the command just before the "[-insert:"
        relative_pos = indexOf(temp_text[current_pos..$], command_str);       

        if (relative_pos != -1) {
            // Found
            relative_endpos = indexOf(temp_text[current_pos..$], "-]");
            if (relative_endpos == -1) {
                // No end command. Probably b0rk3d template, just add everything to final_text and return
                final_text = final_text ~ temp_text[current_pos..$];
                break;
            } 
            // Some alias for readability
            auto command_start = current_pos + relative_pos;
            auto command_end   = current_pos + relative_endpos + 2;
            // Get only the insert command: "[-insert: "polompos.tmpl" -]"
            auto insert_call = temp_text[command_start .. command_end];
            // Get only the template name: "polompos.tmpl"
            auto template_to_insert = strip(insert_call[command_str.length..$-2]);

            // Insert the template
            // FIXME: exists, readable, file, etc...
            auto subtempl_text = to!(char[]) (readText(std.path.buildPath( Settings["templates_path"].get!string, template_to_insert )));

            final_text = final_text ~ temp_text[current_pos .. command_start] ~ subtempl_text;
            // Advance the current position
            current_pos = command_end;
        }
        else {
            final_text = final_text ~ temp_text[current_pos..$];
        }
    } while (relative_pos != -1);

    temp_text = final_text;
}


void execute_substitutions(ref char[] temp_text, HttpRequest request, Variant[string] view_params)
{
    // FIXME: Ignore escape secuences like "\[[escaped_var\]]"
    // FIXME XXX: FACTORIZAR! Es casi todo igual!
    // FIXME: Sustituir los Request.cosa.cosa. Los diccionarios van a dar guerra, salvo que definan un str decente...
    // quizas habria que definir un objeto separado que pueda actuar como un diccionario
    char[] final_text;
    uint current_pos;
    string command_str = "[[";
    auto relative_pos = -1;
    uint relative_endpos;

    do {
        relative_pos = indexOf(temp_text[current_pos..$], command_str);

        if (relative_pos != -1) {
            relative_endpos = indexOf(temp_text[current_pos..$], "]]");
            if (relative_endpos == -1) {
                final_text = final_text ~ temp_text[current_pos..$];
                break;
            }
            auto command_start = current_pos + relative_pos;
            auto command_end   = current_pos + relative_endpos + 2;
            auto subst_call = temp_text[command_start .. command_end];
            // XXX: Estas dos lineas son realmente la unica parte especifica
            auto var_to_replace = to!string( strip(subst_call[command_str.length..$-2]) );
            auto value = to!(char[])(view_params.get(var_to_replace, Variant("")));
            
            final_text = final_text ~ temp_text[current_pos .. command_start] ~ value;
            current_pos = command_end;
        }
        else {
            final_text = final_text ~ temp_text[current_pos..$];
        }
    } while (relative_pos != -1);

    temp_text = final_text;
}
