module core.request;

private import std.stdio;
private import std.string;
private import std.uri;
private import std.conv;
private import std.variant;
static import std.encoding;

private import lib.sjsocket;
private import core.queryutils;
private import core.cookie;
private import core.multipart;
private import core.uploadedfile;
private import user.settings;

enum HttpMethod {
    GET,
    POST,
    PUT,
    DELETE,
}


abstract class Request 
{

}


// Default implementation (valid for SCGI at least), connection handlers should
// override the constructor if the way to get these values is different
class HttpRequest : Request 
{

    this(string[string] env, ref SJSocket socket) 
    {
        // META = raw environment object. Not urlencoded.
        META = env;
        this.socket = socket;
        // XXX excepciones si no tiene algo importante? (capturar IndexOutOfBoundsException)
        _script_name = env.get("SCRIPT_NAME", "");
        path_info = env.get("PATH_INFO", "/");
        path = _script_name ~ path_info;
        _relative_url = env.get("SCRIPT_URL", "");

        switch(env.get("REQUEST_METHOD", "GET")) 
        {
            case "GET":
                method = HttpMethod.GET;
                break;
            case "POST":  
                method = HttpMethod.POST;
                break;
            case "PUT":
                method = HttpMethod.PUT;
                break;
            case "DELETE":
                method = HttpMethod.DELETE;
                break;
            default:
                method = HttpMethod.GET;
                break;
        }

        _parse_GET();

        if (method == HttpMethod.POST)
            _parse_POST();

        // Cookies are parsed lazyly when the COOKIE member is first accesed
    }


    public:
        string[][string] GET;
        string[][string] POST;
        UploadedFile[] FILES;
        // COOKIES is a property

        string path = null;
        string path_info = null;
        HttpMethod method;       
        string encoding = null;
        string[string] META;


        @property bool is_https() 
        {
            return META.get("HTTPS", "off") == "on";
        }


        @property bool is_ajax() 
        {
            return META.get("HTTP_X_REQUESTED_WITH", "http") == "XMLHttpRequest";
        }


        @property string host() 
        {
            if (_host is null) {
                string host;

                if ("HTTP_X_FORWARDED_HOST" in META) 
                    host = META["HTTP_X_FORWARDED_HOST"];
                else if ("HTTP_HOST" in META)
                    host = META["HTTP_HOST"];
                else {
                    host = META["SERVER_NAME"];
                    string port = META["SERVER_PORT"];

                    if ( (is_https() && port != "443") || (port != "80") )
                        host ~= ":" ~ port;
                }
                _host = host;
            }

            return _host;
        }


       @property string full_path()
        {

            if (_full_path is null) {
                _full_path = path;
                if ("QUERY_STRING" in META) 
                    _full_path ~= "?" ~ META["QUERY_STRING"];
            }
            return _full_path;
        }


        @property byte[] raw_post_data() 
        {
            if (_raw_post_data is null) {

                if (method != HttpMethod.POST || socket is null || !socket.isAlive())
                    return new byte[0];

                uint content_len = to!uint(META.get("CONTENT_LENGTH", META.get("HTTP_CONTENT_LENGTH", "0")));
                auto buf = socket.receive_until(content_len);
                debug writeln("Read raw_post_data from socket: ", buf);

                if (buf.length > 0)
                    _raw_post_data = cast(byte[])buf;
                else
                    _raw_post_data = new byte[0];
            }

            return _raw_post_data;
        }


        @property string[string] COOKIES()
        {
            if (_COOKIES is null) {
                string cookies = META.get("HTTP_COOKIE", null);
                if (cookies is null || cookies.length == 0) {
                    // No cookies; assign empty COOKIES object
                    string[string] tmpcookies;
                    _COOKIES = tmpcookies;
                    return _COOKIES;
                }

                auto cookie_obj_list = parse_cookie_header(cookies);
                foreach (cookie; cookie_obj_list)
                    _COOKIES[cookie.name] = cookie.value;
            }

            return _COOKIES;
        }


        override string toString() 
        {
            return "HttpRequest:GET:<" ~ to!string(GET) ~ ">;POST:<" ~ to!string(POST) ~ ">;COOKIES:<"  ~ to!string(COOKIES) ~ ">;META:<" ~ to!string(META) ~ ">";            
        }


    private:
        string _script_name = "";
        string _relative_url = null;
        byte[] _raw_post_data = null;
        string _host = null;
        string _full_path = null;
        string[string] _COOKIES = null;
        SJSocket socket = null;


        // Loads the GET member
        void _parse_GET() 
        {
            if ("QUERY_STRING" in META && META["QUERY_STRING"].length > 0) {
                auto keyvalues = META["QUERY_STRING"].split("&");

                foreach (keyvalue; keyvalues) {
                    auto keyandvalue = keyvalue.split("=");
                    debug writeln("keyvalue: ", decode(keyvalue));

                    string key = decode(keyandvalue[0]).strip;

                    if (key in GET) {   
                        if (keyandvalue.length == 2)
                            GET[key] ~= decode(keyandvalue[1]);
                    }
                    else {
                        if (keyandvalue.length == 2) 
                            GET[key] = [decode(keyandvalue[1])];
                        else
                            GET[key] = [""];
                    }
                }
                debug { foreach(k, v; GET) writeln(k, " => ", v); }
            }
        }


        // Loads the POST member 
        void _parse_POST() 
        {
            auto content_type = META.get("CONTENT_TYPE", "");
            if (content_type.startsWith("multipart")) {
                _parse_FILES_and_POST(content_type);
            }
            else {
                POST = core.queryutils.parse_qsl(cast(string)raw_post_data);
                debug writeln("POST Data: ", POST);
            }
        }

        
        // Get the boundary from the environment (or null)
        string _get_multipart_boundary() 
        in
        {   
            assert(META.get("CONTENT_TYPE", "").startsWith("multipart"));
        }

        body
        {
            auto ctype_parts = META["CONTENT_TYPE"].split("; ");
            string boundary = null;

            // XXX Regexp better, probably...
            foreach(keyvalue; ctype_parts) {

                auto keyvalue_low = keyvalue.toLower();

                if (keyvalue_low.startsWith("boundary=")) {
                    auto boundary_parts = keyvalue_low.split("=");

                    if (boundary_parts.length == 2) {
                        boundary = boundary_parts[1].strip();
                        break;
                    }
                    else
                        return null; // Wrong request??
                }
            }
            return boundary;
        }


        // Loads the POST and FILES members (when there are any files)
        void _parse_FILES_and_POST(string content_type)
        {
            auto boundary = _get_multipart_boundary();
            if (boundary is null) 
                return;

            ulong content_length = to!ulong( META.get("CONTENT_LENGTH", META.get("HTTP_CONTENT_LENGTH", "0")) );

            if (content_length <= 0) // XXX Log something when we've a logger
                return;

            try {
                // POST and FILES are "out" parameters on this functions and
                // thus will be overwritten 
                parse_multipart_form(boundary,  
                                        socket, 
                                        META, 
                                        content_type, content_length, 
                                        POST, FILES);

                // No raw_post_data for multipart forms
                _raw_post_data = cast(byte[])"";

                debug {
                    writeln("After parse_multipart:");
                    writeln("POST: ", POST);
                    writeln("FILES: ", FILES);
                }

            } catch(MultipartParserException e) {
                // XXX Log
                string[][string] emptypost;
                UploadedFile[] emptyfiles;
                POST  = emptypost;
                FILES = emptyfiles;
                return;
            }
        }
}
