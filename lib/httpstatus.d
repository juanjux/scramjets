module lib.httpstatus;

enum StatusType
{
    Unknown = 0,
    Informational,
    Successful,
    Redirection,
    ClientError,
    ServerError
}

// HTTP status codes as per RFC2616
enum StatusCode 
{
    CONTINUE = 100,
    SWITCHINGPROTOCOLS,

    OK = 200,
    CREATED,
    ACCEPTED,
    NONAUTH,
    NOCONTENT,
    RESET,
    PARTIAL,

    MULTIPLE = 300,
    MOVED,
    FOUND,
    SEEOTHER,
    NOTMODIFIED,
    USEPROXY,
    // 306 is reserved
    REDIRECT = 307,

    BADREQUEST = 400,
    UNAUTHORIZED,
    PAYMENT,
    FORBIDDEN,
    NOTFOUND,
    NOTALLOWED,
    NOTACCEPTABLE,
    PROXYAUTHREQUIRED,
    TIMEOUT,
    CONFLICT,
    GONE,
    LENGTHREQUIRED,
    PRECONDITIONFAIL,
    ENTITYTOOLARGE,
    URITOOLONG,
    UNSUPPORTEDMEDIA,
    RANGENOTSATISFIABLE,
    EXPECTATIONFAILED,

    INTERNALSERVERERROR = 500,
    NOTIMPLEMENTED,
    BADGATEWAY,
    UNAVAILABLE,
    GATEWAYTIMEOUT,
    HTTPVERSIONUNSUPPORTED
}


// Default status messages as per RFC2616
enum StatusMessages = [
    StatusCode.CONTINUE: "Continue",
    StatusCode.SWITCHINGPROTOCOLS: "Switching Protocols",
    StatusCode.OK: "Ok",
    StatusCode.CREATED: "Created",
    StatusCode.ACCEPTED: "Accepted",
    StatusCode.NONAUTH: "Non-Authoritative Information",
    StatusCode.NOCONTENT: "No Content",
    StatusCode.RESET: "Reset Content",
    StatusCode.PARTIAL: "Partial Content",

    StatusCode.MULTIPLE: "Multiple Choices",
    StatusCode.MOVED: "Moved Permanently",
    StatusCode.FOUND: "Found",
    StatusCode.SEEOTHER: "See Other",
    StatusCode.NOTMODIFIED: "Not Modified",
    StatusCode.USEPROXY: "Use Proxy",
    StatusCode.REDIRECT: "Temporary Redirect",

    StatusCode.BADREQUEST: "Bad Request",
    StatusCode.UNAUTHORIZED: "Unauthorized",
    StatusCode.PAYMENT: "Payment Required",
    StatusCode.FORBIDDEN: "Forbidden",
    StatusCode.NOTFOUND: "Not Found",
    StatusCode.NOTALLOWED: "Method Not Allowed",
    StatusCode.NOTACCEPTABLE: "Not Acceptable",

    StatusCode.PROXYAUTHREQUIRED: "Proxy Authentication Required",
    StatusCode.TIMEOUT: "Request Timeout",
    StatusCode.CONFLICT: "Conflict",
    StatusCode.GONE: "Gone",
    StatusCode.LENGTHREQUIRED: "Length Required",
    StatusCode.PRECONDITIONFAIL: "Precondition Failed",
    StatusCode.ENTITYTOOLARGE: "Request Entity Too Large",
    StatusCode.URITOOLONG: "Request-URI Too Long",
    StatusCode.UNSUPPORTEDMEDIA: "Unsupported Media Type",
    StatusCode.RANGENOTSATISFIABLE: "Request Range Not Satisfiable",
    StatusCode.EXPECTATIONFAILED: "Expectation Failed",

    StatusCode.INTERNALSERVERERROR: "Internal Server Error",
    StatusCode.NOTIMPLEMENTED: "Not Implemented",
    StatusCode.BADGATEWAY: "Bad Gateway",
    StatusCode.UNAVAILABLE: "Service Unavailable",
    StatusCode.GATEWAYTIMEOUT: "Gateway Timeout",
    StatusCode.HTTPVERSIONUNSUPPORTED: "HTTP Version Not Supported"
];


string status_text(StatusCode code)
{
    return StatusMessages[code];
}


StatusType status_type(StatusCode code)
{
    if (code >=100 && code < 200)
        return StatusType.Informational;
    else if (code >= 200 && code < 300)
        return StatusType.Successful;
    else if (code >= 300 && code < 400)
        return StatusType.Redirection;
    else if (code >= 400 && code < 500)
        return StatusType.ClientError;
    else if (code >= 500)   
        return StatusType.ServerError;
    return StatusType.Unknown;
}
