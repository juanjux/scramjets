// Written in the D programming language

// Scramjets developer NOTE:
// I had to "inherit by copy paste" this file because D's socket.d file
// has the handler set to "private" so I can't create the socket constructor
// that creates the socket object from an existing file descriptor
// AND THAT SUCKS


/*
        Copyright (C) 2004-2005 Christopher E. Miller

        This software is provided 'as-is', without any express or implied
        warranty.  In no event will the authors be held liable for any damages
        arising from the use of this software.

        Permission is granted to anyone to use this software for any purpose,
        including commercial applications, and to alter it and redistribute it
        freely, subject to the following restrictions:

        1. The origin of this software must not be misrepresented; you must not
           claim that you wrote the original software. If you use this software
           in a product, an acknowledgment in the product documentation would be
           appreciated but is not required.
        2. Altered source versions must be plainly marked as such, and must not
           be misrepresented as being the original software.
        3. This notice may not be removed or altered from any source
           distribution.

        socket.d 1.3
        Jan 2005

        Thanks to Benjamin Herr for his assistance.
*/

/**
 * Notes: For Win32 systems, link with ws2_32.lib.
 * Example: See /dmd/samples/d/listener.d.
 * Authors: Christopher E. Miller, $(WEB klickverbot.at, David Nadlinger)
 * Source:  $(PHOBOSSRC std/_socket.d)
 * Macros:
 *      WIKI=Phobos/StdSocket
 */

module lib.sjsocket;

import std.socket, core.stdc.stdint, std.string, std.c.string, std.c.stdlib, std.conv,
    std.traits;

import core.stdc.config;
import core.time : dur, Duration;
import std.algorithm : max;
import std.exception : assumeUnique, enforce;

version(unittest)
{
    private import std.c.stdio : printf;
}

version(Posix)
{
        version = BsdSockets;
}

version(Win32)
{
        pragma (lib, "ws2_32.lib");
        pragma (lib, "wsock32.lib");

        private import std.c.windows.windows, std.c.windows.winsock;
        private alias std.c.windows.winsock.timeval _ctimeval;

        // XXX revisar!
        //typedef SOCKET socket_t = INVALID_SOCKET;
        alias SOCKET socket_t;
        private const int _SOCKET_ERROR = SOCKET_ERROR;


        private int _lasterr()
        {
                return WSAGetLastError();
        }
}
else version(BsdSockets)
{
    version(Posix)
    {
        version(linux)
            import std.c.linux.socket : AF_IPX, AF_APPLETALK, SOCK_RDM,
                IPPROTO_IGMP, IPPROTO_GGP, IPPROTO_PUP, IPPROTO_IDP,
                SD_RECEIVE, SD_SEND, SD_BOTH, MSG_NOSIGNAL, INADDR_NONE;
        else version(OSX)
            private import std.c.osx.socket;
        else version(FreeBSD)
        {
            import core.sys.posix.sys.socket;
            import core.sys.posix.sys.select;
            import std.c.freebsd.socket;
            private enum SD_RECEIVE = SHUT_RD;
            private enum SD_SEND    = SHUT_WR;
            private enum SD_BOTH    = SHUT_RDWR;
        }
        else
            static assert(false);

        import core.sys.posix.netdb;
        private import core.sys.posix.fcntl;
        private import core.sys.posix.unistd;
        private import core.sys.posix.arpa.inet;
        private import core.sys.posix.netinet.tcp;
        private import core.sys.posix.netinet.in_;
        private import core.sys.posix.sys.time;
        //private import core.sys.posix.sys.select;
        private import core.sys.posix.sys.socket;
        private alias core.sys.posix.sys.time.timeval _ctimeval;
    }
    private import core.stdc.errno;

    // XXX Revisar que la asignacion a -1 al perderla no perdemos nada
    alias int32_t socket_t;
    //typedef int32_t socket_t = -1;
    private const int _SOCKET_ERROR = -1;


    private int _lasterr()
    {
        return errno;
    }
}
else
{
        static assert(0); // No socket support yet.
}

private __gshared typeof(&getnameinfo) getnameinfoPointer;

shared static this()
{
        version(Win32)
        {
                WSADATA wd;

                // Winsock will still load if an older version is present.
                // The version is just a request.
                int val;
                val = WSAStartup(0x2020, &wd);
                if(val) // Request Winsock 2.2 for IPv6.
                        throw new SocketException("Unable to initialize socket library");

                // See the comment in InternetAddress.toHostNameString() for
                // details on the getnameinfo() issue.
                auto ws2Lib = GetModuleHandleA("ws2_32.dll");
                if (ws2Lib)
                {
                        getnameinfoPointer = cast(typeof(getnameinfoPointer))
                                GetProcAddress(ws2Lib, "getnameinfo");
                }
        }
        else version(Posix)
        {
                getnameinfoPointer = &getnameinfo;
        }
}


shared static ~this()
{
        version(Win32)
        {
                WSACleanup();
        }
}



/**
 * Address is an abstract class for representing a network addresses.
 */
abstract class SJAddress
{
        protected sockaddr* name();
        protected int nameLen();
        AddressFamily addressFamily();  /// Family of this address.
        override string toString();             /// Human readable string representing this address.
}

/**
 *
 */
class SJUnknownAddress: SJAddress
{
        protected:
        sockaddr sa;


        override sockaddr* name()
        {
                return &sa;
        }


        override int nameLen()
        {
                return sa.sizeof;
        }


        public:
        override AddressFamily addressFamily()
        {
                return cast(AddressFamily)sa.sa_family;
        }


        override string toString()
        {
                return "Unknown";
        }
}


/**
 * InternetAddress is a class that represents an IPv4 (internet protocol version
 * 4) address and port.
 */
class SJInternetAddress: SJAddress
{
        protected:
        sockaddr_in sin;


        override sockaddr* name()
        {
                return cast(sockaddr*)&sin;
        }


        override int nameLen()
        {
                return sin.sizeof;
        }


        this()
        {
        }


        public:
        enum uint ADDR_ANY = INADDR_ANY;       /// Any IPv4 address number.
        enum uint ADDR_NONE = INADDR_NONE;     /// An invalid IPv4 address number.
        enum ushort PORT_ANY = 0;              /// Any IPv4 port number.

        /// Overridden to return AddressFamily.INET.
        override AddressFamily addressFamily()
        {
                return cast(AddressFamily)AddressFamily.INET;
        }

        /// Returns the IPv4 port number.
        ushort port()
        {
                return ntohs(sin.sin_port);
        }

        /// Returns the IPv4 address number.
        uint addr()
        {
                return ntohl(sin.sin_addr.s_addr);
        }

        /**
         * Params:
         *   addr = an IPv4 address string in the dotted-decimal form a.b.c.d,
         *          or a host name that will be resolved using an InternetHost
         *          object.
         *   port = may be PORT_ANY as stated below.
         */
        this(string addr, ushort port)
        {
                uint uiaddr = parse(addr);
                if(ADDR_NONE == uiaddr)
                {
                        InternetHost ih = new InternetHost;
                        if(!ih.getHostByName(addr))
                                //throw new AddressException("Invalid internet address");
                            throw new AddressException(
                                 "Unable to resolve host '" ~ addr ~ "'");
                        uiaddr = ih.addrList[0];
                }
                sin.sin_family = AddressFamily.INET;
                sin.sin_addr.s_addr = htonl(uiaddr);
                sin.sin_port = htons(port);
        }

        /**
         * Construct a new Address. addr may be ADDR_ANY (default) and port may
         * be PORT_ANY, and the actual numbers may not be known until a connection
         * is made.
         */
        this(uint addr, ushort port)
        {
                sin.sin_family = AddressFamily.INET;
                sin.sin_addr.s_addr = htonl(addr);
                sin.sin_port = htons(port);
        }

        /// ditto
        this(ushort port)
        {
                sin.sin_family = AddressFamily.INET;
                sin.sin_addr.s_addr = 0; //any, "0.0.0.0"
                sin.sin_port = htons(port);
        }

        /// Human readable string representing the IPv4 address in dotted-decimal form.
        string toAddrString()
        {
            return to!string(inet_ntoa(sin.sin_addr)).idup;
        }

        /// Human readable string representing the IPv4 port.
        string toPortString()
        {
                return std.conv.to!string(port());
        }

        /*
         * Returns the host name as a fully qualified domain name, if
         * available, or the IP address in dotted-decimal notation otherwise.
         */
        string toHostNameString()
        {
                // getnameinfo() is the recommended way to perform a reverse (name)
                // lookup on both Posix and Windows. However, it is only available
                // on Windows XP and above, and not included with the WinSock import
                // libraries shipped with DMD. Thus, we check for getnameinfo at
                // runtime in the shared module constructor, and fall back to the
                // deprecated getHostByAddr() if it could not be found. See also:
                // http://technet.microsoft.com/en-us/library/aa450403.aspx
                if (getnameinfoPointer is null)
                {
                        auto host = new InternetHost();
                        enforce(host.getHostByAddr(sin.sin_addr.s_addr),
                                new SocketException("Could not get host name."));
                        return host.name;
                }

                auto buf = new char[NI_MAXHOST];
                auto rc = getnameinfoPointer(cast(sockaddr*)&sin, sin.sizeof,
                        buf.ptr, cast(uint)buf.length, null, 0, 0);
                enforce(rc == 0, new SocketException( "Could not get host name"));
                return assumeUnique(buf[0 .. strlen(buf.ptr)]);
        }

        /// Human readable string representing the IPv4 address and port in the form $(I a.b.c.d:e).
        override string toString()
        {
            return toAddrString() ~ ":" ~ toPortString();
        }

        /**
         * Parse an IPv4 address string in the dotted-decimal form $(I a.b.c.d)
         * and return the number.
         * If the string is not a legitimate IPv4 address,
         * ADDR_NONE is returned.
         */
        static uint parse(string addr)
        {
                return ntohl(inet_addr(std.string.toStringz(addr)));
        }
}


unittest
{
    try
    {
        InternetAddress ia = new InternetAddress("63.105.9.61", 80);
        assert(ia.toString() == "63.105.9.61:80");
    }
    catch (Throwable e)
    {
        printf(" --- std.socket(%u) broken test ---\n", __LINE__);
        printf(" (%.*s)\n", e.toString());
    }
}


/** */
class SocketAcceptException: SocketException
{
        this(string msg)
        {
                super(msg);
        }
}

/// How a socket is shutdown:
enum SocketShutdown: int
{
        RECEIVE =  SD_RECEIVE,  /// socket receives are disallowed
        SEND =     SD_SEND,     /// socket sends are disallowed
        BOTH =     SD_BOTH,     /// both RECEIVE and SEND
}


/// Flags may be OR'ed together:
enum SocketFlags: int
{
        NONE =       0,             /// no flags specified

        OOB =        MSG_OOB,       /// out-of-band stream data
        PEEK =       MSG_PEEK,      /// peek at incoming data without removing it from the queue, only for receiving
        DONTROUTE =  MSG_DONTROUTE, /// data should not be subject to routing; this flag may be ignored. Only for sending
}


/// Duration timeout value.
extern(C) struct timeval
{
        // D interface
        c_long seconds;            /// Number of seconds.
        c_long microseconds;       /// Number of additional microseconds.

        // C interface
        deprecated
        {
                alias seconds tv_sec;
                alias microseconds tv_usec;
        }
}


/// A collection of sockets for use with Socket.select.
class SJSocketSet
{
        private:
        uint maxsockets; /// max desired sockets, the fd_set might be capable of holding more
        fd_set set;


        version(Win32)
        {
                uint count()
                {
                        return set.fd_count;
                }
        }
        else version(BsdSockets)
        {
                int maxfd;
                uint count;
        }


        public:

        /// Set the maximum amount of sockets that may be added.
        this(uint max)
        {
                maxsockets = max;
                reset();
        }

        /// Uses the default maximum for the system.
        this()
        {
                this(FD_SETSIZE);
        }

        /// Reset the SJSocketSet so that there are 0 Sockets in the collection.
        void reset()
        {
                FD_ZERO(&set);

                version(BsdSockets)
                {
                        maxfd = -1;
                        count = 0;
                }
        }


        void add(socket_t s)
        in
        {
                // Make sure too many sockets don't get added.
                assert(count < maxsockets);
        }
        body
        {
                FD_SET(s, &set);

                version(BsdSockets)
                {
                        ++count;
                        if(s > maxfd)
                                maxfd = s;
                }
        }

        /// Add a Socket to the collection. Adding more than the maximum has dangerous side affects.
        void add(SJSocket s)
        {
                add(s.sock);
        }

        void remove(socket_t s)
        {
                FD_CLR(s, &set);
                version(BsdSockets)
                {
                        --count;
                        // note: adjusting maxfd would require scanning the set, not worth it
                }
        }


        /// Remove this Socket from the collection.
        void remove(SJSocket s)
        {
                remove(s.sock);
        }

        int isSet(socket_t s)
        {
                return FD_ISSET(s, &set);
        }


        /// Returns nonzero if this Socket is in the collection.
        int isSet(SJSocket s)
        {
                return isSet(s.sock);
        }


        /// Return maximum amount of sockets that can be added, like FD_SETSIZE.
        uint max()
        {
                return maxsockets;
        }


        fd_set* toFd_set()
        {
                return &set;
        }


        int selectn()
        {
                version(Win32)
                {
                        return count;
                }
                else version(BsdSockets)
                {
                        return maxfd + 1;
                }
        }
}


/**
 *  Socket is a class that creates a network communication endpoint using the
 * Berkeley sockets interface.
 */
class SJSocket
{
        private:
        socket_t sock;
        AddressFamily _family;

        version(Win32)
            bool _blocking = false;     /// Property to get or set whether the socket is blocking or nonblocking.

        // The WinSock timeouts seem to be effectively skewed by a constant
        // offset of about half a second (value in milliseconds). This has
        // been confirmed on updated (as of Jun 2011) Windows XP, Windows 7
        // and Windows Server 2008 R2 boxes.
        enum WINSOCK_TIMEOUT_SKEW = 500;

        void setSock(socket_t handle)
        {
                assert(handle != socket_t.init);
                sock = handle;

                // Set the option to disable SIGPIPE on send() if the platform
                // has it (e.g. on OS X).
                static if (is(typeof(SO_NOSIGPIPE)))
                {
                        setOption(SocketOptionLevel.SOCKET, cast(SocketOption)SO_NOSIGPIPE, true);
                }
        }


        // For use with accepting().
        protected this()
        {
        }


        public:

        /**
         * Create a blocking socket. If a single protocol type exists to support
         * this socket type within the address family, the ProtocolType may be
         * omitted.
         */
        this(AddressFamily af, SocketType type, ProtocolType protocol)
        {
                _family = af;
                auto handle = cast(socket_t)socket(af, type, protocol);
                if(handle == socket_t.init)
                        throw new SocketException("Unable to create socket");
                setSock(handle);
        }


        // XXX Este es mi constructor a partir de un fd existente. Lo hace con el dup() de unistd.h
        this(socket_t fd, AddressFamily af, SocketType type, ProtocolType protocol)
        {
                socket_t tmpsock = cast(socket_t) dup(cast(int)fd);
                if (tmpsock < 0)
                        throw new SocketException("Unable to create socket from existing handler");
            
                sock = tmpsock;
                if(sock == socket_t.init)
                        throw new SocketException("Unable to create socket");
                _family = af;
        }


        // A single protocol exists to support this socket type within the
        // protocol family, so the ProtocolType is assumed.
        /// ditto
        this(AddressFamily af, SocketType type)
        {
                this(af, type, cast(ProtocolType)0); // Pseudo protocol number.
        }


        /// ditto
        this(AddressFamily af, SocketType type, string protocolName)
        {
                protoent* proto;
                proto = getprotobyname(toStringz(protocolName));
                if(!proto)
                        throw new SocketException("Unable to find the protocol");
                this(af, type, cast(ProtocolType)proto.p_proto);
        }


        ~this()
        {
                close();
        }


        /// Get underlying socket handle.
        socket_t handle()
        {
                return sock;
        }

        /**
         * Get/set socket's blocking flag.
         *
         * When a socket is blocking, calls to receive(), accept(), and send()
         * will block and wait for data/action.
         * A non-blocking socket will immediately return instead of blocking.
         */
        bool blocking()
        {
                version(Win32)
                {
                        return _blocking;
                }
                else version(BsdSockets)
                {
                        return !(fcntl(handle, F_GETFL, 0) & O_NONBLOCK);
                }
        }

        /// ditto
        void blocking(bool byes)
        {
                version(Win32)
                {
                        uint num = !byes;
                        if(_SOCKET_ERROR == ioctlsocket(sock, FIONBIO, &num))
                                goto err;
                        _blocking = byes;
                }
                else version(BsdSockets)
                {
                        int x = fcntl(sock, F_GETFL, 0);
                        if(-1 == x)
                                goto err;
                        if(byes)
                                x &= ~O_NONBLOCK;
                        else
                                x |= O_NONBLOCK;
                        if(-1 == fcntl(sock, F_SETFL, x))
                                goto err;
                }
                return; // Success.

                err:
                throw new SocketException("Unable to set socket blocking");
        }


        /// Get the socket's address family.
        AddressFamily addressFamily() // getter
        {
                return _family;
        }

        /// Property that indicates if this is a valid, alive socket.
        bool isAlive() // getter
        {
        int type;
        socklen_t typesize = cast(socklen_t) type.sizeof;
                return !getsockopt(sock, SOL_SOCKET, SO_TYPE, cast(char*)&type, &typesize);
        }

        /// Associate a local address with this socket.
        void bind(SJAddress addr)
        {
                if(_SOCKET_ERROR == .bind(sock, addr.name(), addr.nameLen()))
                        throw new SocketException("Unable to bind socket");
        }

        /**
         * Establish a connection. If the socket is blocking, connect waits for
         * the connection to be made. If the socket is nonblocking, connect
         * returns immediately and the connection attempt is still in progress.
         */
        void connect(SJAddress to)
        {
                if(_SOCKET_ERROR == .connect(sock, to.name(), to.nameLen()))
                {
                        int err;
                        err = _lasterr();

                        if(!blocking)
                        {
                                version(Win32)
                                {
                                        if(WSAEWOULDBLOCK == err)
                                                return;
                                }
                                else version(Posix)
                                {
                                        if(EINPROGRESS == err)
                                                return;
                                }
                                else
                                {
                                        static assert(0);
                                }
                        }
                        throw new SocketException("Unable to connect socket");
                }
        }

        /**
         * Listen for an incoming connection. bind must be called before you can
         * listen. The backlog is a request of how many pending incoming
         * connections are queued until accept'ed.
         */
        void listen(int backlog)
        {
                if(_SOCKET_ERROR == .listen(sock, backlog))
                        throw new SocketException("Unable to listen on socket");
        }

        /**
         * Called by accept when a new Socket must be created for a new
         * connection. To use a derived class, override this method and return an
         * instance of your class. The returned Socket's handle must not be set;
         * Socket has a protected constructor this() to use in this situation.
         */
        // Override to use a derived class.
        // The returned socket's handle must not be set.
        protected SJSocket accepting()
        {
                return new SJSocket;
        }

        /**
         * Accept an incoming connection. If the socket is blocking, accept
         * waits for a connection request. Throws SocketAcceptException if unable
         * to accept. See accepting for use with derived classes.
         */
        SJSocket accept()
        {
                auto newsock = cast(socket_t).accept(sock, null, null);
                if(socket_t.init == newsock)
                        throw new SocketAcceptException("Unable to accept socket connection");

                SJSocket newSocket;
                try
                {
                        newSocket = accepting();
                        assert(newSocket.sock == socket_t.init);

                        newSocket.setSock(newsock);
                        version(Win32)
                                newSocket._blocking = _blocking; //inherits blocking mode
                        newSocket._family = _family; //same family
                }
                catch(Throwable o)
                {
                        _close(newsock);
                        throw o;
                }

                return newSocket;
        }

        /// Disables sends and/or receives.
        void shutdown(SocketShutdown how)
        {
                .shutdown(sock, cast(int)how);
        }


        private static void _close(socket_t sock)
        {
                version(Win32)
                {
                        .closesocket(sock);
                }
                else version(BsdSockets)
                {
                        .close(sock);
                }
        }


        /**
         * Immediately drop any connections and release socket resources.
         * Calling shutdown before close is recommended for connection-oriented
         * sockets. The Socket object is no longer usable after close.
         */
        //calling shutdown() before this is recommended
        //for connection-oriented sockets
        void close()
        {
                _close(sock);
                sock = socket_t.init;
        }


        private SJAddress newFamilyObject()
        {
                SJAddress result;
                switch(_family)
                {
                        case cast(AddressFamily)AddressFamily.INET:
                                result = new SJInternetAddress;
                                break;

                        default:
                                result = new SJUnknownAddress;
                }
                return result;
        }


        /// Returns the local machine's host name. Idea from mango.
        static string hostName() // getter
        {
                char[256] result; // Host names are limited to 255 chars.
                if(_SOCKET_ERROR == .gethostname(result.ptr, result.length))
                        throw new SocketException("Unable to obtain host name");
                return to!string(cast(char*)result).idup;
        }

        /// Remote endpoint Address.
        SJAddress remoteAddress()
        {
                SJAddress addr = newFamilyObject();
                socklen_t nameLen = cast(socklen_t) addr.nameLen();
                if(_SOCKET_ERROR == .getpeername(sock, addr.name(), &nameLen))
                        throw new SocketException("Unable to obtain remote socket address");
                assert(addr.addressFamily() == _family);
                return addr;
        }

        /// Local endpoint Address.
        SJAddress localAddress()
        {
                SJAddress addr = newFamilyObject();
                socklen_t nameLen = cast(socklen_t) addr.nameLen();
                if(_SOCKET_ERROR == .getsockname(sock, addr.name(), &nameLen))
                        throw new SocketException("Unable to obtain local socket address");
                assert(addr.addressFamily() == _family);
                return addr;
        }

        /// Send or receive error code.
        enum int ERROR = _SOCKET_ERROR;

        /**
         * Send data on the connection. Returns the number of bytes actually
         * sent, or ERROR on failure. If the socket is blocking and there is no
         * buffer space left, send waits.
         */
        //returns number of bytes actually sent, or -1 on error
        Select!(size_t.sizeof > 4, long, int)
    send(const(void)[] buf, SocketFlags flags)
        {
                static if (is(typeof(MSG_NOSIGNAL)))
                {
                        flags = cast(SocketFlags)(flags | MSG_NOSIGNAL);
                }
                auto sent = .send(sock, buf.ptr, buf.length, cast(int)flags);
                return sent;
        }

        /// ditto
        Select!(size_t.sizeof > 4, long, int) send(const(void)[] buf)
        {
                return send(buf, SocketFlags.NONE);
        }

        /**
         * Send data to a specific destination Address. If the destination address is not specified, a connection must have been made and that address is used. If the socket is blocking and there is no buffer space left, sendTo waits.
         */
        Select!(size_t.sizeof > 4, long, int)
    sendTo(const(void)[] buf, SocketFlags flags, SJAddress to)
        {
                static if (is(typeof(MSG_NOSIGNAL)))
                {
                        flags = cast(SocketFlags)(flags | MSG_NOSIGNAL);
                }
                return .sendto(sock, buf.ptr, buf.length, cast(int)flags, to.name(), to.nameLen());
        }

        /// ditto
        Select!(size_t.sizeof > 4, long, int) sendTo(const(void)[] buf, SJAddress to)
        {
                return sendTo(buf, SocketFlags.NONE, to);
        }


        //assumes you connect()ed
        /// ditto
        Select!(size_t.sizeof > 4, long, int) sendTo(const(void)[] buf, SocketFlags flags)
        {
                static if (is(typeof(MSG_NOSIGNAL)))
                {
                        flags = cast(SocketFlags)(flags | MSG_NOSIGNAL);
                }
                return .sendto(sock, buf.ptr, buf.length, cast(int)flags, null, 0);
        }


        //assumes you connect()ed
        /// ditto
        Select!(size_t.sizeof > 4, long, int) sendTo(const(void)[] buf)
        {
                return sendTo(buf, SocketFlags.NONE);
        }


        /**
         * Receive data on the connection. Returns the number of bytes actually
         * received, 0 if the remote side has closed the connection, or ERROR on
         * failure. If the socket is blocking, receive waits until there is data
         * to be received.
         */
        //returns number of bytes actually received, 0 on connection closure, or -1 on error
    ptrdiff_t receive(void[] buf, SocketFlags flags)
        {
        return buf.length
            ? .recv(sock, buf.ptr, buf.length, cast(int)flags)
            : 0;
        }

        /// ditto
        ptrdiff_t receive(void[] buf)
        {
                return receive(buf, SocketFlags.NONE);
        }

        // Read until the specified bytes or the sockets errors or is closed
        void[] receive_until(uint bytes) {
            void[] buffer;
            buffer.length = bytes;
            uint read = 0;
            uint partialread = 0;

            while (read < bytes) {
                partialread = this.receive(buffer[read..$]);
                if (partialread == 0 || !isAlive())
                    break;
                read += partialread;
            }

            return buffer;
        }

        

        /**
         * Receive data and get the remote endpoint Address.
         * If the socket is blocking, receiveFrom waits until there is data to
         * be received.
         * Returns: the number of bytes actually received,
         * 0 if the remote side has closed the connection, or ERROR on failure.
         */
        Select!(size_t.sizeof > 4, long, int)
    receiveFrom(void[] buf, SocketFlags flags, out SJAddress from)
        {
                if(!buf.length) //return 0 and don't think the connection closed
                        return 0;
                from = newFamilyObject();
                socklen_t nameLen = cast(socklen_t) from.nameLen();
                auto read = .recvfrom(sock, buf.ptr, buf.length, cast(int)flags, from.name(), &nameLen);
                assert(from.addressFamily() == _family);
                // if(!read) //connection closed
                return read;
        }


        /// ditto
        ptrdiff_t receiveFrom(void[] buf, out SJAddress from)
        {
                return receiveFrom(buf, SocketFlags.NONE, from);
        }


        //assumes you connect()ed
        /// ditto
        Select!(size_t.sizeof > 4, long, int)
    receiveFrom(void[] buf, SocketFlags flags)
        {
                if(!buf.length) //return 0 and don't think the connection closed
                        return 0;
                auto read = .recvfrom(sock, buf.ptr, buf.length, cast(int)flags, null, null);
                // if(!read) //connection closed
                return read;
        }


        //assumes you connect()ed
        /// ditto
        ptrdiff_t receiveFrom(void[] buf)
        {
                return receiveFrom(buf, SocketFlags.NONE);
        }


        /// Get a socket option. Returns the number of bytes written to result.
        //returns the length, in bytes, of the actual result - very different from getsockopt()
        int getOption(SocketOptionLevel level, SocketOption option, void[] result)
        {
                socklen_t len = cast(socklen_t) result.length;
                if(_SOCKET_ERROR == .getsockopt(sock, cast(int)level, cast(int)option, result.ptr, &len))
                        throw new SocketException("Unable to get socket option");
                return len;
        }


        /// Common case of getting integer and boolean options.
        int getOption(SocketOptionLevel level, SocketOption option, out int32_t result)
        {
                return getOption(level, option, (&result)[0 .. 1]);
        }


        /// Get the linger option.
        int getOption(SocketOptionLevel level, SocketOption option, out std.socket.linger result)
        {
                //return getOption(cast(SocketOptionLevel)SocketOptionLevel.SOCKET, SocketOption.LINGER, (&result)[0 .. 1]);
                return getOption(level, option, (&result)[0 .. 1]);
        }

        /// Get a timeout (duration) option.
        void getOption(SocketOptionLevel level, SocketOption option, out Duration result)
        {
                enforce(option == SocketOption.SNDTIMEO || option == SocketOption.RCVTIMEO,
                        new SocketException("Not a valid timeout option: " ~ to!string(option)));
                // WinSock returns the timeout values as a milliseconds DWORD,
                // while Linux and BSD return a timeval struct.
                version (Win32)
                {
                        int msecs;
                        getOption(level, option, (&msecs)[0 .. 1]);
                        if (option == SocketOption.RCVTIMEO) {
                                msecs += WINSOCK_TIMEOUT_SKEW;
                        }
                        result = dur!"msecs"(msecs);
                }
                else version (BsdSockets)
                {
                        timeval tv;
                        getOption(level, option, (&tv)[0..1]);
                        result = dur!"seconds"(tv.seconds) + dur!"usecs"(tv.microseconds);
                }
                else static assert(false);
        }

        // Set a socket option.
        void setOption(SocketOptionLevel level, SocketOption option, void[] value)
        {
                if(_SOCKET_ERROR == .setsockopt(sock, cast(int)level,
                        cast(int)option, value.ptr, cast(uint) value.length))
                        throw new SocketException("Unable to set socket option");
        }


        /// Common case for setting integer and boolean options.
        void setOption(SocketOptionLevel level, SocketOption option, int32_t value)
        {
                setOption(level, option, (&value)[0 .. 1]);
        }


        /// Set the linger option.
        void setOption(SocketOptionLevel level, SocketOption option, std.socket.linger value)
        {
                //setOption(cast(SocketOptionLevel)SocketOptionLevel.SOCKET, SocketOption.LINGER, (&value)[0 .. 1]);
                setOption(level, option, (&value)[0 .. 1]);
        }

        /**
         * Sets a timeout (duration) option, i.e. SocketOption.SNDTIMEO or
         * RCVTIMEO. Zero indicates no timeout.
         *
         * In a typical application, you might also want to consider using
         * a non-blocking socket instead of setting a timeout on a blocking one.
         *
         * Note: While the receive timeout setting is generally quite accurate
         * on *nix systems even for smaller durations, there are two issues to
         * be aware of on Windows: First, although undocumented, the effective
         * timeout duration seems to be the one set on the socket plus half
         * a second. setOption() tries to compensate for that, but still,
         * timeouts under 500ms are not possible on Windows. Second, be aware
         * that the actual amount of time spent until a blocking call returns
         * randomly varies on the order of 10ms.
         *
         * Params:
         *   value = The timeout duration to set. Must not be negative.
         *
         * Throws: SocketException if setting the options fails.
         *
         * Example:
         * ---
         * import std.datetime;
         * auto pair = socketPair();
         * scope(exit) foreach (s; pair) s.close();
         *
         * // Set a receive timeout, and then wait at one end of
         * // the socket pair, knowing that no data will arrive.
         * pair[0].setOption(SocketOptionLevel.SOCKET,
         *     SocketOption.RCVTIMEO, dur!"seconds"(1));
         *
         * auto sw = StopWatch(AutoStart.yes);
         * ubyte[1] buffer;
         * pair[0].receive(buffer);
         * writefln("Waited %s ms until the socket timed out.",
         *     sw.peek.msecs);
         * ---
         */
        void setOption(SocketOptionLevel level, SocketOption option, Duration value)
        {
                enforce(option == SocketOption.SNDTIMEO || option == SocketOption.RCVTIMEO,
                        new SocketException("Not a valid timeout option: " ~ to!string(option)));

                enforce(value >= dur!"hnsecs"(0), new SocketException(
                        "Timeout duration must not be negative."));

                version (Win32)
                {
                        auto msecs = cast(int)value.total!"msecs"();
                        if (msecs == 0 || option != SocketOption.RCVTIMEO)
                        {
                                setOption(level, option, msecs);
                        }
                        else
                        {
                                setOption(level, option, cast(int)
                                      max(1, msecs - WINSOCK_TIMEOUT_SKEW));
                        }
                }
                else version (BsdSockets)
                {
                        timeval tv = { seconds: cast(int)value.total!"seconds"(),
                                microseconds: value.fracSec.usecs };
                        setOption(level, option, (&tv)[0 .. 1]);
                }
                else static assert(false);
        }

        /**
         * Wait for a socket to change status. A wait timeout timeval or int microseconds may be specified; if a timeout is not specified or the timeval is null, the maximum timeout is used. The timeval timeout has an unspecified value when select returns. Returns the number of sockets with status changes, 0 on timeout, or -1 on interruption. If the return value is greater than 0, the SJSocketSets are updated to only contain the sockets having status changes. For a connecting socket, a write status change means the connection is established and it's able to send. For a listening socket, a read status change means there is an incoming connection request and it's able to accept.
         */
        //SJSocketSet's updated to include only those sockets which an event occured
        //returns the number of events, 0 on timeout, or -1 on interruption
        //for a connect()ing socket, writeability means connected
        //for a listen()ing socket, readability means listening
        //Winsock: possibly internally limited to 64 sockets per set
        static int select(SJSocketSet checkRead, SJSocketSet checkWrite, SJSocketSet checkError, timeval* tv)
        in
        {
                //make sure none of the SJSocketSet's are the same object
                if(checkRead)
                {
                        assert(checkRead !is checkWrite);
                        assert(checkRead !is checkError);
                }
                if(checkWrite)
                {
                        assert(checkWrite !is checkError);
                }
        }
        body
        {
                fd_set* fr, fw, fe;
                int n = 0;

                version(Win32)
                {
                        // Windows has a problem with empty fd_set`s that aren't null.
                        fr = (checkRead && checkRead.count()) ? checkRead.toFd_set() : null;
                        fw = (checkWrite && checkWrite.count()) ? checkWrite.toFd_set() : null;
                        fe = (checkError && checkError.count()) ? checkError.toFd_set() : null;
                }
                else
                {
                        if(checkRead)
                        {
                                fr = checkRead.toFd_set();
                                n = checkRead.selectn();
                        }
                        else
                        {
                                fr = null;
                        }

                        if(checkWrite)
                        {
                                fw = checkWrite.toFd_set();
                                int _n;
                                _n = checkWrite.selectn();
                                if(_n > n)
                                        n = _n;
                        }
                        else
                        {
                                fw = null;
                        }

                        if(checkError)
                        {
                                fe = checkError.toFd_set();
                                int _n;
                                _n = checkError.selectn();
                                if(_n > n)
                                        n = _n;
                        }
                        else
                        {
                                fe = null;
                        }
                }

                int result = .select(n, fr, fw, fe, cast(_ctimeval*)tv);

                version(Win32)
                {
                        if(_SOCKET_ERROR == result && WSAGetLastError() == WSAEINTR)
                                return -1;
                }
                else version(Posix)
                {
                        if(_SOCKET_ERROR == result && errno == EINTR)
                                return -1;
                }
                else
                {
                        static assert(0);
                }

                if(_SOCKET_ERROR == result)
                        throw new SocketException("Socket select error");

                return result;
        }


        /// ditto
        static int select(SJSocketSet checkRead, SJSocketSet checkWrite, SJSocketSet checkError, int microseconds)
        {
            timeval tv;
            tv.seconds = microseconds / 1_000_000;
            tv.microseconds = microseconds % 1_000_000;
            return select(checkRead, checkWrite, checkError, &tv);
        }


        /// ditto
        //maximum timeout
        static int select(SJSocketSet checkRead, SJSocketSet checkWrite, SJSocketSet checkError)
        {
                return select(checkRead, checkWrite, checkError, null);
        }


        /+
        bool poll(events)
        {
                int WSAEventSelect(socket_t s, WSAEVENT hEventObject, int lNetworkEvents); // Winsock 2 ?
                int poll(pollfd* fds, int nfds, int timeout); // Unix ?
        }
        +/
}


/// TcpSocket is a shortcut class for a TCP Socket.
/*class TcpSocket: SJSocket*/
//{
        ///// Constructs a blocking TCP Socket.
        //this(AddressFamily family)
        //{
                //super(family, SocketType.STREAM, ProtocolType.TCP);
        //}

        ///// Constructs a blocking TCP Socket.
        //this()
        //{
                //this(cast(AddressFamily)AddressFamily.INET);
        //}


        ////shortcut
        ///// Constructs a blocking TCP Socket and connects to an InternetAddress.
        //this(Address connectTo)
        //{
                //this(connectTo.addressFamily());
                //connect(connectTo);
        //}
//}


///// UdpSocket is a shortcut class for a UDP Socket.
//class UdpSocket: SJSocket
//{
        ///// Constructs a blocking UDP Socket.
        //this(AddressFamily family)
        //{
                //super(family, SocketType.DGRAM, ProtocolType.UDP);
        //}


        ///// Constructs a blocking UDP Socket.
        //this()
        //{
                //this(cast(AddressFamily)AddressFamily.INET);
        //}
//}

/**
 * Creates a pair of connected sockets.
 *
 * The two sockets are indistinguishable.
 *
 * Throws: SocketException if creation of the sockets fails.
 *
 * Example:
 * ---
 * immutable ubyte[] data = [1, 2, 3, 4];
 * auto pair = socketPair();
 * scope(exit) foreach (s; pair) s.close();
 *
 * pair[0].send(data);
 *
 * auto buf = new ubyte[data.length];
 * pair[1].receive(buf);
 * assert(buf == data);
 * ---
 */
//Socket[2] socketPair() {
    //version(BsdSockets) {
        //int[2] socks;
        //if (socketpair(AF_UNIX, SOCK_STREAM, 0, socks) == -1) {
            //throw new SocketException("Unable to create socket pair", _lasterr());
        //}

        //Socket toSocket(size_t id) {
            //auto s = new Socket;
            //s.setSock(cast(socket_t)socks[id]);
            //s._family = AddressFamily.UNIX;
            //return s;
        //}
        //return [toSocket(0), toSocket(1)];
    //} else version(Win32) {
        //// We do not have socketpair() on Windows, just manually create a
        //// pair of sockets connected over some localhost port.
        //Socket[2] result;

        //auto listener = new TcpSocket();
        //listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        //listener.bind(new InternetAddress(INADDR_LOOPBACK, InternetAddress.PORT_ANY));
        //auto addr = listener.localAddress();
        //listener.listen(1);

        //result[0] = new TcpSocket(addr);
        //result[1] = listener.accept();

        //listener.close();
        //return result;
    //} else static assert(false);
//}

//unittest {
    //immutable ubyte[] data = [1, 2, 3, 4];
    //auto pair = socketPair();
    //scope(exit) foreach (s; pair) s.close();

    //pair[0].send(data);

    //auto buf = new ubyte[data.length];
    //pair[1].receive(buf);
    //assert(buf == data);
/*}*/
