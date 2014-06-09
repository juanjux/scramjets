module user.views.main;

//import std.boxer;
import std.stdio;
import std.conv;
import std.variant;

import core.request;
import core.request_context;


string header(RequestContext params)
{
    string ret =
    `<html>
     <header>
        <title> ` ~ params.get("title", Variant("Scramjets Default Title")).get!string ~ `</title>
        <meta http-equiv="content-type" content="text/html; charset=UTF-8">
     </header>

     <body>`;


    return ret;
}

string footer(RequestContext params)
{
    string ret = 
    "<hr/>\n
    (c) 1-3000 Juanjo Alvarez\n
    </body>\n
    </html>\n";

    return ret;
}


string skeleton(RequestContext params)
// Main view. Other views should add a "content" param and call this one
{
    string ret = header(params);
    ret ~= params.get("content", Variant("")).get!string;
    ret ~= footer(params);

    return ret;
}


string index(RequestContext params) 
{
 
    string content = "
    <h1> Hello World desde el Index usando D-on-Scramjets!</h1>\n
    <h2> Variables de plantilla </h2>
    ";

    // Note how since params.context is a dictionary of Variants containing
    // diverse types we get the correct string representation using
    // value.toString()
    foreach (key, value; params.context) 
        content ~= key ~ " => " ~ value.toString() ~ "<br/>\n";


    content ~= "<h2> Request vars: </h2>";

    foreach (key, value; params.request.META) 
        content ~= key ~ " => " ~ value ~ "<br/>\n";

    params["content"] = Variant(content);
    return skeleton(params);
}


string testform(RequestContext params) {

    string content;

    if (params.request.POST.length > 0) {
        content ~= "POST Data:<br/><hr/>";

        foreach (key, values; params.request.POST) {
            content ~= key ~ ": ";

            foreach (value; values) {
                content ~= value ~ " ";
            }
            content ~= "<br/>\n";
        }
        content ~= "<hr/>";
    }

    
    content ~= 
    `
    <FORM METHOD="POST" ACTION="http://localhost/post/">

    <P>Name field: <INPUT TYPE="text" Name="name" SIZE=30 VALUE = "XXX">

    <P>Name field: <TEXTAREA TYPE="textarea" ROWS=5 COLS=30 Name="textarea">Your comment.</TEXTAREA>

    <P>Your age: <INPUT TYPE="radio" NAME="radiobutton" VALUE="youngun" CHECKED> younger than 21,
    <INPUT TYPE="radio" NAME="radiobutton" VALUE="middleun"> 21 -59,
    <INPUT TYPE="radio" NAME="radiobutton" VALUE="oldun"> 60 or older

    <P>What you like most: <SELECT NAME="selectitem">
    <OPTION>pizza<OPTION>hamburgers<OPTION SELECTED>spinich<OPTION>mashed potatoes<OPTION>other
    </SELECT>


    <P>Submit: <INPUT TYPE="submit" NAME="submitbutton" VALUE="Do it!" ACTION="SEND">
    </FORM>
    `;

    //<P>Attach file: <INPUT TYPE="file" NAME="uploadedfile" SIZE="40">

    params["content"] = Variant(content);
    return skeleton(params);
} 


string testform_multipart(RequestContext params) 
{

    string content;

    if (params.request.POST.length > 0) {
        content ~= "POST Data:<br/><hr/>";

        foreach (key, values; params.request.POST) {
            content ~= key ~ ": ";

            foreach (value; values) {
                content ~= value ~ " ";
            }
            content ~= "<br/>\n";
        }
        content ~= "<hr/>";
    }

    
    content ~= 
    `
    <FORM ENCTYPE="multipart/form-data" METHOD="POST" ACTION="http://localhost/post/">

    <P>Name field: <INPUT TYPE="text" Name="name" SIZE=30 VALUE = "XXX">

    <P>Name field: <TEXTAREA TYPE="textarea" ROWS=5 COLS=30 Name="textarea">Your comment.</TEXTAREA>

    <P>Your age: <INPUT TYPE="radio" NAME="radiobutton" VALUE="youngun" CHECKED> younger than 21,
    <INPUT TYPE="radio" NAME="radiobutton" VALUE="middleun"> 21 -59,
    <INPUT TYPE="radio" NAME="radiobutton" VALUE="oldun"> 60 or older

    <P>What you like most: <SELECT NAME="selectitem">
    <OPTION>pizza<OPTION>hamburgers<OPTION SELECTED>spinich<OPTION>mashed potatoes<OPTION>other
    </SELECT>

    <P>Attach file: <INPUT TYPE="file" NAME="uploadedfile" SIZE="40">

    <P>Submit: <INPUT TYPE="submit" NAME="submitbutton" VALUE="Do it!" ACTION="SEND">
    </FORM>
    `;


    params["content"] = Variant(content);

    return skeleton(params);
} 
