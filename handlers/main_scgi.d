module handlers.main_scgi;

/*
 * Modelled after Quixote's scgi.py
 */

import std.socket;
import std.stdio;
import std.string;
import std.file;
import std.conv;
import std.c.linux.linux;
import std.c.process: exit;
import std.exception;
import std.typecons;
import core.memory;
import core.sys.posix.sys.socket;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.stdc.time;
import core.stdc.locale;

import lib.sjsocket;
import lib.generic_controllers;
import core.bindselector;
import core.request;
import core.response;

import user.urls;

static this() 
{
    setlocale(LC_TIME, "en_US");
}


string get_http_date_header()
{
    time_t t;
    time(&t);
    char[128] tmp;

    strftime(tmp.ptr, 128,"%a, %d %b %Y %H:%M:%S %z", localtime(&t)); 

    return "Date: " ~ to!string(tmp.ptr) ~ "\r\n";
}


extern(C) 
{
    static int recv_fd(int);
    static int send_fd(int, int);
}


class Scgi2Exception : Exception
{
    this(string str) { super(str); }
}



uint ns_read_size(SJSocket input) 
{
    string size;
    string c;
    
    while(true) {
        c = cast(string)input.receive_until(1);
        if (c == ":") {
            break;
        }
        else if (c.length == 0) {
            throw new Scgi2Exception("short netstring size read");
        }
        size ~= c;
    }

    return to!uint(size);
}


string ns_reads(SJSocket input) 
{
    uint size = ns_read_size(input);
    string data;

    while (size > 0) {
        void[] s;
        s = input.receive_until(size);
        if (s.length == 0) 
            throw new Scgi2Exception("short netstring read");

        data ~= cast(string)s;
        size -= s.length;
    }

    if ( cast(string)input.receive_until(1) != "," ) 
        throw new Scgi2Exception("missing netstring terminator");

    return data;
}


string[string] read_env(SJSocket input) 
{

    string headers = ns_reads(input);
    string[] items = headers.split("\0");
    items = items[0..$-1];

        debug {
            writeln("Env Dictionary: ");
            for(int i = 0; i<items.length; i+=2) 
                writeln(items[i], " => ", items[i+1]);
        }

    if ((items.length % 2) != 0)
        throw new Scgi2Exception("malformed headers");

    string[string] env;
    for(int i=0; i<items.length; i+=2) {
        env[items[i]] = items[i+1];
    }
    return env;
}


class Child 
{
    uint pid;
    lib.sjsocket.socket_t fd;
    bool closed;

    this(uint pid, lib.sjsocket.socket_t fd) {
        this.pid = pid;
        this.fd  = fd;
        closed = false;
    }

    void close() {  
        if (!closed)
            .close(fd);
        closed = true;
    }
}



class SCGIHandler
{
    this(lib.sjsocket.socket_t parent_fd, URLbinder binder) {
        this.parent_fd = parent_fd;
        _binder = binder;
    }

    
    void serve() 
    {

        while(true) {
            errnoEnforce( 
                std.c.linux.linux.write(parent_fd, toStringz("1"), 1) != -1 
            );
            fd = cast(lib.sjsocket.socket_t) recv_fd(parent_fd);

            // Create a socket from the existing file descriptor
            auto conn = new SJSocket(fd, AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
            conn.blocking(true);
            std.c.linux.linux.close(fd);
            handle_connection(conn);
        }
    }


    string[string] read_env(SJSocket input) 
    {
        return .read_env(input);
    }


    void handle_connection(SJSocket conn) 
    {
        string[string] env = read_env(conn);
        uint bodysize = to!int(env.get("CONTENT_LENGTH", "0"));
        produce(env, bodysize, conn);
    }


    void produce(string[string] env, uint bodysize, SJSocket conn) 
    {
        scope(exit) {
            conn.shutdown(lib.sjsocket.SocketShutdown.BOTH);
            conn.close();
        }

        // Call the binder with the url and the HttpRequest, get the HttpResponse:
        auto request = new HttpRequest(env, conn);
        HttpResponse response = null;
        try {
            response = _binder.call_controller_from_url(env["SCRIPT_URL"], request);
        } catch (Exception e) {
            // This inner trycatch is ugly but necesary, like taxes
            try 
                response = controller_500(request, env["SCRIPT_URL"], e);
            catch (Exception e) 
                response = new HttpResponse("OMG, there was an error trying to put up the error 500 page!");
        }

        // Preamble (HTTP + Date + Server) -----------------------------
        int[string] already_sent;
        conn.send(format("HTTP/1.1 %d %s\r\n", response.status_code, to!string(response.status_code)));
        if (!response.has_header("Date"))
            conn.send(get_http_date_header());
        else {
            conn.send(response.get_header("Date"));
            already_sent["Date"] = 1;
        }

        if (!response.has_header("Server")) 
            conn.send("Server: " ~ SERVER ~ "\r\n");
        else {
            conn.send(response.get_header("Server"));
            already_sent["Server"] = 1;
        }

        // Other headers ----------------------------
        debug writeln(response.get_headers_string(already_sent));
        conn.send(response.get_headers_string(already_sent));
        conn.send("\r\n");

        // Body -------------------------------------
        auto response_stream = response.get_content_as_istream();
        ubyte[1024*64] buffer;
        uint readed;
        while ( (readed = response_stream.read(buffer)) > 0 ) {
            conn.send(buffer[0..readed]);
        }
    }

    private:
        lib.sjsocket.socket_t parent_fd;
        lib.sjsocket.socket_t fd;
        URLbinder _binder = null;
}


class SCGIServer 
{
    ushort DEFAULT_PORT = 4000;

    this(URLbinder binder, string host="localhost", ushort port=DEFAULT_PORT, uint max_children=1) 
    {
        this.binder = binder;
        this.host = host;
        this.port = port;
        this.max_children = max_children;

        spawn_child();

    }

    private:
        string host;
        ushort port;
        uint max_children;
        bool restart = false;
        SJSocket priv_sock = null;
        Child[] children;
        URLbinder binder = null;

        void hup_signal(int signum) 
        {
            restart = true;
        }


        void spawn_child(SJSocket conn=null) 
        {
            int[2] sockets;

            errnoEnforce( 
                socketpair(AF_UNIX, SOCK_STREAM , 0, sockets) != -1,
                          "Could not spawn child: socketpair failed" 
            );

            lib.sjsocket.socket_t parent_fd = cast(lib.sjsocket.socket_t) sockets[0];
            lib.sjsocket.socket_t child_fd  = cast(lib.sjsocket.socket_t) sockets[1];

            // make child_fd non-blocking
            auto flags = fcntl(child_fd, F_GETFL, 0);
            fcntl(child_fd, F_SETFL, flags | O_NONBLOCK);

            auto pid = fork();
            if (pid == 0) { // child
                if (conn !is null)
                    conn.close();
                close(child_fd);

                auto handler = new SCGIHandler(parent_fd, binder);
                handler.serve();
                exit(0);
            }
            else { // parent
                close(parent_fd);
                children ~= new Child(pid, child_fd);
            }
        }

        
        Child get_child(pid_t pid) 
        {
            foreach(child; children) {
                if (child.pid == pid)
                    return child;
            }
            return null;
        }


        void reap_children() 
        {
            while (children.length > 0) {
                
                int* status = new int;
                pid_t pid = waitpid(-1, status, WNOHANG); 

                if (pid <= 0)
                    break; // No more left
                auto child = get_child(pid);
                child.close();
            }
            children.length = 0;
        }


        void do_stop() 
        {
            foreach(child; children)
                child.close();
        }


        void do_restart() 
        {
            do_stop();
            restart = false;
        }


        void delegate_request(SJSocket conn) 
        {
            uint timeout = 0;

            while(true) {

                SJSocketSet sockets = new SJSocketSet;
                foreach(child; children) {
                    if (!child.closed)   
                        sockets.add(child.fd);
                }

                std.socket.timeval* tv = new std.socket.timeval;
                (*tv).seconds = timeout;
                int result = SJSocket.select(sockets, null, null, null);

                // XXX check -1, launch exception?
                if (result > 0) {

                    Child foundchild = null;
                    foreach (child; children) {
                        if ( (!child.closed) && sockets.isSet(child.fd) ) {
                            foundchild = child;
                            break;
                        }
                    }

                    if (foundchild is null) { // no child found, should not get here
                        debug writeln("no child found");
                        continue;
                    }

                    /* Try to read the single byte written by the child.
                     * This can fail if the child died or the pipe wasn't ready.
                     * The fd has been made non-blocking by the spawn_child. If
                     * this fails we fall throught the "reap_children" logic 
                     * and will retry the select call */

                     byte[1] buf;
                     auto bytesread = core.sys.posix.unistd.read( 
                                       cast(int) foundchild.fd, 
                                       cast(void*)buf.ptr, 1);

                     if (bytesread == 1) {
                        errnoEnforce(
                           send_fd(foundchild.fd, conn.handle()) != -1
                        );
                        return;
                     }

                } // ends "if (result > 0)"

                // didn't find any child, check if any died
                reap_children();

                // start more children if we haven't met max_children limit
                if (children.length < max_children) {
                    spawn_child(conn);
                }

                // Start blocking inside select. We might have reached max_children
                // limit and they're all budy
                timeout = 2;

            } // ends "while (1)"
        }


        @trusted SJSocket get_listening_socket() 
        {
            auto s = new SJSocket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
            s.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1); 
            try {
                s.bind(new SJInternetAddress(host, port));
            } catch (SocketException e) {
                writeln("Could not bind to serve, maybe there is another process running on the same port " 
                        ~ to!string(port) ~ "?\n" ~ e.toString());
            }

            return s;
        }


        @trusted void serve_on_socket(SJSocket sock) 
        {
            priv_sock = sock;
            priv_sock.listen(40);

            // XXX dont works :( can't pass a delegate, check how to do it
            //signal(SIGHUP, &hup_signal);

            while(true) {
                auto conn = priv_sock.accept();
                delegate_request(conn);
                conn.close();

                if (restart)
                    do_restart();
            }
        }

    
        @safe void serve() 
        {
            serve_on_socket(get_listening_socket());
        }
}


void main() 
{
    auto binder = new URLbinder(get_url_selectors());
    auto server = new SCGIServer(binder, "localhost", 12345, 10);
    server.serve();
}

