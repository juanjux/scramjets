import std.array;
import std.stdio;

string escape(string input) 
{
    return input.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
}



void main()
{
    string cad = "&, >, <, \", '";
    writeln(cad.escape);
}
