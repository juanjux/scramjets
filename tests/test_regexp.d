#!/usr/bin/dmd

import std.regex;
import std.stdio;

struct CommandBlock {
    string command;
    string[] command_params;
    string text;
}


// XXX control de errores: que no haya parentesis de apertura, nueva línea, punto y coma (no entre comillas), etc
void save_command(ref CommandBlock cb, string command_text) {
    //cb.command = command_text[2 .. std.string.lastIndexOf(command_text, "__")];
    cb.command = std.regex.match(command_text, regex(r"[a-zA-Z]+")).hit;
    auto params_match = match(command_text, regex(r"\(.*?\)")).captures;
    writeln("params_match.length: ", params_match.length);
    writeln("params_match.hit: ", params_match.hit);
    auto arg_tokens = splitter(params_match.hit,
}

void main() {
    string cadena = `
        <h2>Template 0.1 test</h2>

        __block(bloque1, bloque2, bloque3, "polompos", 1234)__
            Dentro de bloque1.
            Blablabla.
        __endblock__

        Texto libre blabla
        polompos pok

        __block(bloque2)__

            Dentro de bloque2
            blabla

        __endblock__

        Texto libre 2 blabla
        wiwiwiwiwi

    `;

  /*  writeln("---Contenidos---");*/

    //// Cuando el otro funcione:
    ////auto r = ctRegex!(r"(__.*?__)", "m");

    //auto r =  regex(r"__.*?__", "g");
    //auto r2 = regex(r"__.*?__", "g");
    //string [] contenidos;
    //string [] comandos;

    //foreach(c; splitter(cadena, r)) {
        //writeln("Match: ");
        //writeln(c);
    /*}*/

    // Parece que splitter mete los cachos pero no los comandos como el de Python
    // Habría que hacer otro bucle con la misma regex para sacar los comandos:
    
/*    writeln("---Comandos---");*/
    //foreach(c; match(cadena, r2)) {
        //writeln("------------------------------");
        //writeln("------------------------------");
        //writeln("Hit: -------------------------");
        //writeln(c.hit);    
        //writeln("Pre: -------------------------");
        //writeln(c.pre);
        //writeln("Post: ------------------------");
        //writeln(c.post);
    //}

    auto i = 0;
    auto n = cadena.length;

    string resultado;
    string comando;

    CommandBlock[] cb_list;

    while (i >= 0 && i < n) {
        auto capture = std.regex.match(cadena[i..$], regex(r"__.*?__", "g")).captures;
        if (capture.empty) {
            // No more commands left
            resultado ~= cadena[i..$];
            break;
        }

        // Save the command
        CommandBlock cb;
        save_command(cb, capture.hit);

        break;

        // Find the 
    }

}
