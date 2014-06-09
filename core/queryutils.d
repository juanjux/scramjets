module core.queryutils;

private import std.string;
private import std.stdio;
private import std.uri;
private import std.array;
private import std.conv;
private import std.c.stdlib;
import std.encoding;



// Function : xtoul() - Hex string to an unsigned decimal whole number 
// Author   : David 'SpottedTiger' L. Davis
// ----------------------------------------
// Converts a Hex string from 0x0 to 0xFFFFFFFFFFFFFF
// into a ulong value 0 to 18,446,744,073,709,551,615
// also it handles the lowercase 'a' thru 'f'.
private ulong xtoul(string sx)
{
    ulong  ul = 0L;
    int    j = 7;
    //char   c, c1, c2;
    char c;
    ulong c1, c2;
    char[] st  = cast(char[])sx;
    int    len = st.length;
    
    const char[] zeros = "0000000000000000"c;
    union u { ulong ul; char[8] c; }
    
    u U;
    
    if (len == 0 || len > 16)
        throw new Exception( "xtoul() the string parameter is either an empty
string,"c ~
                             " or its length is greater than 16 characters."c );
     
    // isHex()                         
    for (int i = 0; i < st.length; i++)                             
    {
        //c = ( sx[i] > 'F' ? sx[i] - 32 : sx[i] );
        c = st[i];

        if ((c >= '0' && c <= '9') || 
            (c >= 'A' && c <= 'F') ||
            (c >= 'a' && c <= 'f'))
           continue;
        else     
          throw new Exception("xtoul() invalid hex character used."c);   
    }
          
    if (len < 16)
        st = zeros[0..16 - len] ~ st;
    
    j = 7;
    for (int i = 0; i < 16; i += 2)
    {
        c1 = (st[i] > 'F' ? st[i] - 32 : st[i]) ; 
        c2 = (st[i + 1] > 'F' ? st[i + 1] - 32 : st[i + 1]);
        c1 = (c1 > 52 ? c1 - 55 : c1 - 48) << 4;
        U.c[j--] = cast(char) (c1 + (c2 > 52 ? c2 - 55 : c2 - 48));
    }

    return U.ul;
} 

unittest
{
    debug( hexconv ) writefln( "hexconv.xtoul( string ).unittest"c );
    ulong ul;

    ul = xtoul("0"c); 
    assert( ul == 0x0 );
    ul = xtoul("FF"c); 
    assert( ul == 0xFF );
    ul = xtoul("eea"c); 
    assert( ul == 0xEEA );
    ul = xtoul("AB"c);
    assert( ul == 0xAB );
    ul = xtoul("ABCD"c);
    assert( ul == 0xABCD );
    ul = xtoul("A12CD00"c);
    assert( ul == 0xA12CD00 );
    ul = xtoul("FFFFFFFFFFFFFFFF"c); 
    assert( ul == 0xFFFFFFFFFFFFFFFF );
}

/+
// Function : ultox() - Decimal unsigned whole number to Hex string
// Author   : David 'SpottedTiger' L. Davis
// Created  : 04.May.05
// CPU      : Intel x86 (Numercials stored as "Low byte to High byte")
// Last Test: dmd v2.002
// -----------------------------------------
// Accepts any positive number from 0 to 18,446,744,073,709,551,615
// and the returns an even number of hex strings up to 16 characters
// (from 0x0 to 0xFFFFFFFFFFFFFF).
string ultox(in ulong ul)
{
    char[16] sx;
    char     c1, c2;
    union    u { ulong ul; char[8] c; }
    int      i = 0, j = 0, k = 0;
    bool     z = true;
    u U;

    U.ul = ul;
    
    for (i = 7; i >= 0; i--)
    {
        c1 = U.c[i] >> 4;
        c1 = cast(char)(c1 > 9 ? c1 + 55 : c1 + 48);
        c2 = U.c[i] & 0x0F;
        c2 = cast(char)(c2 > 9 ? c2 + 55 : c2 + 48);
        
        if (z && c1 == '0' && c2 == '0')
            continue;

        z = false;
        sx[j++] = c1;
        sx[j++] = c2;
    }
    
    if (j > 0)
        //Copying a fixed array into a dynamic array, must COW.
        return sx[0..j].dup;
    else
        return "00"c;    
}

unittest
{
    debug( hexconv ) writefln( "hexconv.ultox( in ulong ).unittest"c );
    string sx;

    sx = ultox(0); //0x0
    assert( sx == "00"c );

    sx = ultox(255); //0xFF
    assert( sx == "FF"c );
    sx = ultox(171); //0xAB
    assert( sx == "AB"c );
    sx = ultox(43981); //0xABCD
    assert( sx == "ABCD"c );
    sx = ultox(169004288); //0xA12CD00
    assert( sx == "0A12CD00"c );
    sx = ultox(0xA12CD00); //169004288
    assert( sx == "0A12CD00"c );
   
    sx = ultox(ulong.max); //0xFFFFFFFFFFFFFFFF
    assert( sx == "FFFFFFFFFFFFFFFF"c );
}
+/

private bool isHex(string sx)   
{          
    char c;
                
    for (int i = 0; i < sx.length; i++)                             
    {
        c = sx[i];
        
        if ((c >= '0' && c <= '9') || 
            (c >= 'A' && c <= 'F') ||
            (c >= 'a' && c <= 'f'))
            continue;
        else     
            return false;   
    }
    
    return true;
}

unittest
{
    debug( hexconv ) writefln( "hexconv.isHex( string ).unittest"c );
    
    assert( isHex("00"c) );
    assert( isHex("FF"c) );
    assert( isHex("Ffae0"c) );
    assert( isHex("AB"c) );
    assert( isHex("abdef"c) );
    assert( isHex("ABCD"c) );
    assert( isHex("0A12CD00"c) );
    assert( isHex("FFFFFFFFFFFFFFFF"c) );
    
    assert( isHex("00ER"c) == false );
    assert( !isHex("0xW"c) );
}


// XXX Create a static AA to serve as cache for the more common unicode chars (first 255)
string unquote(string cad) 
{
    auto parts = cad.split("%");

    if (parts.length == 1) {
        return cad;
    }

    string res = parts[0];
    
    foreach(item; parts[1..$]) {
        if (isHex(item[0..2])) {
            res ~= cast(char)xtoul(item[0..2]) ~ item[2..$];
        }
    }
    
    return res;
}

string[][string] parse_qsl(string querystring) 
{
    // "polompos=pok&cogorcios=beifos&hurl=3;another=other&yetmore=more"
    // split by ';', then by '&'; then by '=', return an AA with name as string and a list of values as value
    string[][string] result;
    string[] bysemicolon = querystring.split(";");
    string[] namevalues;


    foreach(item; bysemicolon) {
        namevalues ~= item.split("&");
    }

    foreach(namevalue; namevalues) {
       if (namevalue.length == 0)
           continue;

       string[] name_value_list = namevalue.split("=");
       string name = name_value_list[0];

       if (name.length == 0)
           continue;

       name = unquote(name).replace("+", " ");

       string value;
       if (name_value_list.length == 1 || name_value_list[1].length == 0)
           value = "";
       else
           value = unquote(name_value_list[1].replace("+", " "));

       if (name in result) 
           result[name] ~= value;
       else 
           result[name] = [value];
    }

    return result;

}

unittest 
{
    string query = "polompos=pok&cogorc%20ios=beifos&hurl=3;another=other&yetmore=more&polompos=anotherpok&empty";
    auto result = parse_qsl(query);

    assert(result.length == 6);
    assert(result["polompos"] == ["pok", "anotherpok"]);
    assert(result["cogorc ios"] == ["beifos"]);
    assert(result["hurl"] == ["3"]);
    assert(result["another"] == ["other"]);
    assert(result["yetmore"] == ["more"]);
    assert(result["empty"] == [""]);
}



