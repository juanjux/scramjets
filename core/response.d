module core.response;

import lib.httpstatus;
import core.cookie;
import user.settings;

import std.stream;
import std.encoding;
import std.conv;
import std.stdio;
import std.string;
import std.file;
import std.variant;

/* TODO: 
 * Unittests for HttpResponse
 * opApply
 * Shortcut functions for redirect, file, etc
 * 
 * Pruebas (a mano y en unittest):
 *  · Cargando el HttpResponse con un resultado de una view
 *  · Cargando el HttpResponse con un resultado de un fichero
 *  · Cargando el HttpResponse con un encoding distinto al declarado
 *  · all_to_string()
 *  · get_headers_string()
 *  · set_cookie()
 *  · opIndex()
 */

static immutable SERVER = "SCGI/1.0 Scramjets/0.01";

class ResponseException: Exception 
{
    this(string msg) 
    {
        super(msg);
    }
}

class ResponseBody
{
    this(ubyte[] data)
    {
        _ubyte_content = data; // .dup? .idup?
        _store_type = ContentStore.BYTEARRAY;
    }  
    this(string data)
    {
        _string_content = data;
        _store_type = ContentStore.STRING;
    }
    this(InputStream istream)
    {
        _istream_content = istream;
        _store_type = ContentStore.ISTREAM;
    }
    this()
    {
        _store_type = ContentStore.EMPTY;
    }
 
    @property content(ubyte[] data)
    {
        _ubyte_content = data;
        _store_type = ContentStore.BYTEARRAY;
        // Clear the other _*_content members?
    }
 
    @property content(string data)
    {
        _string_content = data;
        _store_type = ContentStore.STRING;
    }
 
    @property content(InputStream istream)
    {
        _istream_content = istream;
        _store_type = ContentStore.ISTREAM;
    }

    ubyte[] get_content_as_bytes()
    {
        return get_content_as_bytes(Settings.get("default_charset", Variant("latin-1")).get!string, false);
    }
 
    ubyte[] get_content_as_bytes(string charset, bool use_charset=true)
    {

        if (use_charset && _store_type != ContentStore.STRING)
            throw new EncodingException("Can't encode content loaded from file or ubyte[]");

        ubyte[] output;

        // No conversion is done if read from a file or inputstream, the user should take care of that if needed
        if (_store_type == ContentStore.EMPTY) 
            return output; // Throw exception instead?
 
        else if (_store_type == ContentStore.BYTEARRAY) 
            output = _ubyte_content;
 
        else if (_store_type == ContentStore.STRING) {
            if (!use_charset)
                return cast(ubyte[])_string_content;

            string charset_simp = charset.toLower().removechars("-");

            // is a string, encode into the specified encoding
            if (charset_simp == "utf8")
                output = cast(ubyte[])_string_content;
 
            else if (charset_simp == "ascii") {
                AsciiString s;
                transcode(_string_content, s);
                output = cast(ubyte[]) s;
            }
            else if (charset_simp == "latin1") {
                Latin1String s;
                transcode(_string_content, s);
                output = cast(ubyte[]) s;
            }
            else if (charset_simp == "utf16") {
                wstring s;
                transcode(_string_content, s);
                output = cast(ubyte[]) s;
            }
            else if (charset_simp == "utf32") {
                dstring s;
                transcode(_string_content, s);
                output = cast(ubyte[]) s;
            }
            else
                throw new EncodingException("Encoding " ~ charset ~ " is not supported");
        }
 
        else if (_store_type == ContentStore.ISTREAM) {
            ubyte[1024] partial;
            output.length = 1024*128;
 
            uint readed, totalread;
            while ((readed = _istream_content.read(partial)) > 0) {
                if (output.length < totalread+readed)
                    output.length *= 2;
                //output ~= partial[0..readed];
                output[totalread..totalread+readed] = partial[0..readed];
                totalread += readed;
            }
            output.length = totalread;
        }
           
        return output;
    }
 

    InputStream get_content_as_istream() {
        if (_store_type == ContentStore.EMPTY) {
            ubyte[] empty;
            return new MemoryStream(empty); // Throw exception instead?
        }
 
        else if (_store_type == ContentStore.BYTEARRAY)
            return new MemoryStream(get_content_as_bytes());
 
        else if (_store_type == ContentStore.STRING)
            return new MemoryStream( to!(char[])(_string_content) );
 
        else if (_store_type == ContentStore.ISTREAM)
            return _istream_content;
 
        assert(0);
    }
 
    private:
        InputStream _istream_content;
        ubyte[] _ubyte_content;
        string _string_content;
        enum ContentStore { EMPTY, STRING, BYTEARRAY, ISTREAM };
        ContentStore _store_type = ContentStore.STRING;
 
}
 

unittest // for ResponseBody
{
        string ascii_chars_in_utf = "En un lugar de la mancha";
        string latin1_chars_in_utf = "ñaña";

        ubyte[] bodybytes;
     
        // utf-8 input input, utf-8 output
        auto b = new ResponseBody("ñaña w8");
        bodybytes = b.get_content_as_bytes("utf-8");
        assert(cast(string)bodybytes == "ñaña w8");
     
        // utf-8 input, ascii output
        auto a = new ResponseBody(ascii_chars_in_utf);
        bodybytes = a.get_content_as_bytes("ascii");
        AsciiString ascii_chars;
        transcode(ascii_chars_in_utf, ascii_chars);
        assert(cast(AsciiString)bodybytes == ascii_chars);
     
        // utf-8 input, latin1 output
        auto l = new ResponseBody(latin1_chars_in_utf);
        bodybytes = l.get_content_as_bytes("latin-1");
        Latin1String latin1_chars;
        transcode(latin1_chars_in_utf, latin1_chars);
        assert(cast(Latin1String)bodybytes == latin1_chars);
     
        // utf-8 input, utf-16 output
        auto w = new ResponseBody("ñaña w16");
        bodybytes = w.get_content_as_bytes("utf-16");
        assert(cast(wstring)bodybytes == "ñaña w16"w);
     
        // utf-8 input, utf-32 output
        auto d = new ResponseBody("ñaña w32");
        bodybytes = d.get_content_as_bytes("utf-32");
        assert(cast(dstring)bodybytes == "ñaña w32"d);

        // input from file with utf8 encoding, utf-8 output
        // (no conversion is done when reading from istream)
        auto f = new BufferedFile("tests/textfile.txt", FileMode.In);
        scope(exit) f.close();
        auto fromfile = new ResponseBody(f);
        bodybytes = fromfile.get_content_as_bytes();
        assert(cast(string)bodybytes == "Software is like sex - it's better when is free\n");

        // input from file with utf8 encoding and non-ascii chars
        // (ditto)
        auto flat = new BufferedFile("tests/textfile_latin1.txt", FileMode.In);
        scope(exit) flat.close();
        auto fromfile_lat = new ResponseBody(flat);
        bodybytes = fromfile_lat.get_content_as_bytes();
        assert(cast(string)bodybytes == "¡Socorro! ¡Hay una araña! ¿Pero araña o no araña?\n");

        // input from file with binary data, output as ostream
        auto f1name = "tests/binaryfile.jpg";
        auto bin = new BufferedFile(f1name, FileMode.In);
        scope(exit) bin.close();
        auto fromfile_bin = new ResponseBody(bin);
        InputStream fstream = fromfile_bin.get_content_as_istream();
        // copy the file, check that the result is the same
        auto f2name = "tests/output.jpg";
        auto bin2 = new BufferedFile(f2name, FileMode.Out);
        try {
            bin2.copyFrom(cast(Stream)fstream);
        } finally {
            bin2.flush();
            bin2.close();
        }
        // compare both files
        auto f1size = to!uint(getSize(f1name));
        auto f2size = to!uint(getSize(f2name));
        assert(f1size == f2size);
        byte[] f1buffer; f1buffer.length = f1size;
        byte[] f2buffer; f2buffer.length = f2size;
        bin.readExact(cast(void*)f1buffer.ptr, f1size);
        bin2 = new BufferedFile(f2name, FileMode.In);
        bin2.readExact(cast(void*)f2buffer.ptr, f2size);
        assert(f1buffer == f2buffer);
}


class HttpResponse
{

    this(ubyte[] content, StatusCode status, string mimetype, string charset=null)
    {
        if (content != null) 
            _content = new ResponseBody(content);
        else
            _content = new ResponseBody();

        if (charset == null)
            _charset = Settings.get("default_charset", Variant("latin-1")).get!string;
        else
            _charset = charset;

        _status_code = status;
        _mimetype = mimetype;
        _headers["Content-Type"] = mimetype ~ "; charset=" ~ _charset;
    }
    // some shortcuts
    this(ubyte[] content, StatusCode status) { this(content, status, "text/html"); }
    this(ubyte[] content)                    { this(content, StatusCode.OK, "text/html"); }
    this()                                   { this("", StatusCode.OK, "text/html"); }

    // string constructors; charset is set to utf8 since D strings are utf8
    this(string content, StatusCode status, string mimetype)
    {
        // XXX: check against the default_charset setting and log a warning once the log is done: 
        // "warning: using string (utf8) constructor but default charset is not utf8. utf8 will be used for the response"
        _charset = "utf-8";   
        this(cast(ubyte[])content, status, mimetype, _charset);
    }
    this(string content, StatusCode status) { this(content, status, "text/html"); }
    this(string content)                    { this(content, StatusCode.OK, "text/html"); }


    // Returns a string with the headers (without the body). Use all_to_string() to get the body too
    override string toString()
    {
        return get_headers_string();
    }


    // Return a string with the headers, a newline, and the body (converted to string)
    string all_to_string()
    {
        string ret = get_headers_string();


        ret ~= "\r\n";
        ret ~= cast(string)_content.get_content_as_bytes;

        return ret;
    }


    // Header methods

    void set_header(string header_name, string value)
    {
        if (header_name == null || header_name.length == 0)
            throw new ResponseException("The header name can't be null or empty");

        if (value == null || value.length == 0)
            throw new ResponseException("The header value can't be null or empty");


        foreach(c; header_name) {
            if (!canEncode!AsciiChar(c))
                throw new ResponseException("Can't encode the header name's char '" ~ c ~ "' in ASCII");
            if (c == '\n' || c == '\r')
                throw new ResponseException("Header names can't contain newline characters");
        }

        foreach(c; value) {
            if (!canEncode!AsciiChar(c))
                throw new ResponseException("Can't encode the header value's char '" ~ c ~ "' in ASCII");
            if (c == '\n' || c == '\r')
                throw new ResponseException("Header values can't contain newline characters");
        }

        _headers[header_name] = value;
    }


    void remove_header(string header_name)
    {
        if (header_name in _headers)
            _headers.remove(header_name);               
    }


    string get_header(string header_name, string default_ = null)
    {
        if (default_ != null)
            return _headers.get(header_name, default_);

        return _headers[header_name];
    }


    // XXX: Use a set instead of this dummy set when sets are implemented
    string get_headers_string(int[string] except=null)
    {
        string ret = "";
        foreach(header, value; _headers) {
            if (!(header in except))
                ret ~= header ~ ": " ~ value ~ "\r\n";
        }

        if (_cookies.length > 0)
            ret ~= get_cookie_headers();

        return ret;
    }

    bool has_header(string key)
    {
        return (key in _headers) !is null;
    }


    // Cookie methods
    // TODO: test
    // TODO: Validate that 'expires' is a date in the correct format =>http://www.cookiecentral.com/faq/#3.3 
    void set_cookie(string key, string value, ulong max_age, 
                    string expires, string path, string domain, bool secure)
    {
        if (key == null || key.length == 0)
            throw new ResponseException("Cookie key must not be empty or null");

        string[string] cookie_params;

        if (max_age != 0)
            cookie_params["max_age"] = to!string(max_age);

        if (expires != null && expires.length > 0)
            cookie_params["expires"] = expires;

        if (path != null && path.length > 0)
            cookie_params["path"] = path;

        if (domain != null && domain.length > 0)
            cookie_params["domain"] = domain;

        if (secure)
            cookie_params["secure"] = "TRUE";

        auto c = new Cookie(key, value, cookie_params);
        _cookies[key] = c;
    }
    void set_cookie(string key, string value)              { set_cookie(key, value, 0, "", "", "", false); }
    void set_cookie(string key, string value, string path) { set_cookie(key, value, 0, "", path, "", false); }


    void delete_cookie(string key, string path, string domain) 
    {
        // If the cookie exists, change the expiry to the hippie past
        if (key in _cookies) {
            auto c = _cookies[key];
            auto params = c.params;
            if (path != null   && path.length > 0   && params.get("path", "")   != path)
                return;
            if (domain != null && domain.length > 0 && params.get("domain", "") != domain)
                return;

            params["expires"] = "Thu, 01-Jan-1970 00:00:01 GMT";
            c.params = params;
        }
        // If not, create a new cookie with the expiration hippie date (we don't have the cookie but maybe the client does)
        else {
            string[string] params = ["expires": "Thu, 01-Jan-1970 00:00:01 GMT"];
            if (path != null && path.length > 0)
                params["path"] = path;
            if (domain != null && domain.length > 0)
                params["domain"] = domain;

            auto c = new Cookie(key, "deleting", params);
            _cookies[key] = c;
        }
    }
    void delete_cookie(string key, string path)         { delete_cookie(key, path, ""); }
    void delete_cookie(string key)                      { delete_cookie(key, "", ""); }

    void delete_all_cookies() 
    {
        foreach(cookiekey, cookie; _cookies)
            delete_cookie(cookiekey);
    }

    string get_cookie_headers()
    {
        string res = "";
        foreach(cookie; _cookies)
            res ~= cookie.output() ~ "\r\n";

        return res;
    }

    // Status properties
    @property StatusCode status_code() { return _status_code; }

    @property string status_text()
    {
        return lib.httpstatus.status_text(_status_code);
    }

    // XXX TODO
    /*
    int opApply(int delegate(ref string) dg) 
    {
        assert(0);
    }
    */

    string opIndex(string header_name)
    {
        return _headers[header_name];
    }

    // response["header"] = value;
    void opIndex(string header_name, string header_value)
    {
        if (header_name.indexOf('\n') != -1 || header_name.indexOf('\r') != -1)
            throw new ResponseException("Header names can't contain newline characters");
        if (header_value.indexOf('\n') != -1 || header_value.indexOf('\r') != -1)
            throw new ResponseException("Header values can't contain newline characters");

        _headers[header_name] = header_value;
    }

    // Body
    @property void content(ubyte[] memorydata)
    {
        _content.content = memorydata;
    }


    @property void content(string stringcontent)
    {
        _content.content = stringcontent;
    }

    @property void content(InputStream istreamcontent)
    {
        _content.content = istreamcontent;
    }

    ubyte[] get_content_as_bytes(string charset)
    {
        return _content.get_content_as_bytes(charset);
    }
    ubyte[] get_content_as_bytes() { return get_content_as_bytes(_charset); }

    InputStream get_content_as_istream()
    {
        return _content.get_content_as_istream();
    }


   private:    
        ResponseBody _content;
        string _charset;
        string _mimetype;
        Cookie[string] _cookies;
        string[string] _headers;
        StatusCode _status_code;
}
