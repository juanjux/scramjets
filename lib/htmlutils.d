module lib.htmlutils;

private import std.string;
private import std.array;

/** 
 * Useful for simple string to html conversions (like printing an exception)
 */
string newlinetobr(string input) 
{
    return input.replace("\n", "<br/>\n");
}
