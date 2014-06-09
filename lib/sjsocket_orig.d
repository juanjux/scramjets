module lib.sjsocket;

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
 * Authors: Christopher E. Miller
 * Macros:
 *      WIKI=Phobos/StdSocket
 */


import std.socket;
import core.stdc.stdint, std.string, std.c.string, std.c.stdlib, std.conv,
    std.traits;

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

}
else version(BsdSockets)
{
    version(Posix)
    {
        version(linux)
            import std.c.linux.socket : AF_IPX, AF_APPLETALK, SOCK_RDM,
                IPPROTO_IGMP, IPPROTO_GGP, IPPROTO_PUP, IPPROTO_IDP,
                protoent, servent, hostent, SD_RECEIVE, SD_SEND, SD_BOTH,
                MSG_NOSIGNAL, INADDR_NONE, getprotobyname, getprotobynumber,
                getservbyname, getservbyport, gethostbyname, gethostbyaddr;
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

        /// Reset the SocketSet so that there are 0 Sockets in the collection.
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
 * Address is an abstract class for representing a network addresses.
 */
abstract class SJAddress
{
        protected sockaddr* name();
        protected int nameLen();
        AddressFamily addressFamily();  /// Family of this address.
        override string toString();             /// Human readable string representing this address.
}

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
        const uint ADDR_ANY = INADDR_ANY;       /// Any IPv4 address number.
        const uint ADDR_NONE = INADDR_NONE;     /// An invalid IPv4 address number.
        const ushort PORT_ANY = 0;              /// Any IPv4 port number.

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
                sock = cast(socket_t)socket(af, type, protocol);
                if(sock == socket_t.init)
                        throw new SocketException("Unable to create socket", _lasterr());
                _family = af;
        }

        // XXX Este es mi constructor a partir de un fd existente. Lo hace con el dup() de unistd.h
        this(socket_t fd, AddressFamily af, SocketType type, ProtocolType protocol)
        {
                socket_t tmpsock = cast(socket_t) dup(cast(int)fd);
                if (tmpsock < 0)
                        throw new SocketException("Unable to create socket from existing handler", _lasterr());
            
                sock = tmpsock;
                if(sock == socket_t.init)
                        throw new SocketException("Unable to create socket", _lasterr());
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
                        throw new SocketException("Unable to find the protocol", _lasterr());
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
                throw new SocketException("Unable to set socket blocking", _lasterr());
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
                        throw new SocketException("Unable to bind socket", _lasterr());
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
                        throw new SocketException("Unable to connect socket", err);
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
                        throw new SocketException("Unable to listen on socket", _lasterr());
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
                socket_t newsock;
                //newsock = cast(socket_t).accept(sock, null, null); // DMD 0.101 error: found '(' when expecting ';' following 'statement
                alias .accept topaccept;
                newsock = cast(socket_t)topaccept(sock, null, null);
                if(socket_t.init == newsock)
                        throw new SocketAcceptException("Unable to accept socket connection", _lasterr());

                SJSocket newSocket;
                try
                {
                        newSocket = accepting();
                        assert(newSocket.sock == socket_t.init);

                        newSocket.sock = newsock;
                        version(Win32)
                                newSocket._blocking = _blocking; //inherits blocking mode
                        newSocket._family = _family; //same family
                }
                catch(Object o)
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
                        throw new SocketException("Unable to obtain host name", _lasterr());
                return to!string(cast(char*)result).idup;
        }

        /// Remote endpoint Address.
        SJAddress remoteAddress()
        {
                SJAddress addr = newFamilyObject();
                socklen_t nameLen = cast(socklen_t) addr.nameLen();
                if(_SOCKET_ERROR == .getpeername(sock, addr.name(), &nameLen))
                        throw new SocketException("Unable to obtain remote socket address", _lasterr());
                assert(addr.addressFamily() == _family);
                return addr;
        }

        /// Local endpoint Address.
        SJAddress localAddress()
        {
                SJAddress addr = newFamilyObject();
                socklen_t nameLen = cast(socklen_t) addr.nameLen();
                if(_SOCKET_ERROR == .getsockname(sock, addr.name(), &nameLen))
                        throw new SocketException("Unable to obtain local socket address", _lasterr());
                assert(addr.addressFamily() == _family);
                return addr;
        }

        /// Send or receive error code.
        const int ERROR = _SOCKET_ERROR;

        /**
         * Send data on the connection. Returns the number of bytes actually
         * sent, or ERROR on failure. If the socket is blocking and there is no
         * buffer space left, send waits.
         */
        //returns number of bytes actually sent, or -1 on error
        Select!(size_t.sizeof > 4, long, int)
    send(const(void)[] buf, SocketFlags flags)
        {
        flags |= SocketFlags.NOSIGNAL;
        auto sent = .send(sock, buf.ptr, buf.length, cast(int)flags);
                return sent;
        }

        /// ditto
        Select!(size_t.sizeof > 4, long, int) send(const(void)[] buf)
        {
                return send(buf, SocketFlags.NOSIGNAL);
        }

        /**
         * Send data to a specific destination Address. If the destination address is not specified, a connection must have been made and that address is used. If the socket is blocking and there is no buffer space left, sendTo waits.
         */
        Select!(size_t.sizeof > 4, long, int)
    sendTo(const(void)[] buf, SocketFlags flags, SJAddress to)
        {
        flags |= SocketFlags.NOSIGNAL;
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
        flags |= SocketFlags.NOSIGNAL;
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


        /// ditto
        ptrdiff_t receive(void[] buf)
        {
                return receive(buf, SocketFlags.NONE);
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
                        throw new SocketException("Unable to get socket option", _lasterr());
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

        // Set a socket option.
        void setOption(SocketOptionLevel level, SocketOption option, void[] value)
        {
                if(_SOCKET_ERROR == .setsockopt(sock, cast(int)level,
                        cast(int)option, value.ptr, cast(uint) value.length))
                        throw new SocketException("Unable to set socket option", _lasterr());
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
         * Wait for a socket to change status. A wait timeout timeval or int microseconds may be specified; if a timeout is not specified or the timeval is null, the maximum timeout is used. The timeval timeout has an unspecified value when select returns. Returns the number of sockets with status changes, 0 on timeout, or -1 on interruption. If the return value is greater than 0, the SJSocketSets are updated to only contain the sockets having status changes. For a connecting socket, a write status change means the connection is established and it's able to send. For a listening socket, a read status change means there is an incoming connection request and it's able to accept.
         */
        //SJSocketSet's updated to include only those sockets which an event occured
        //returns the number of events, 0 on timeout, or -1 on interruption
        //for a connect()ing socket, writeability means connected
        //for a listen()ing socket, readability means listening
        //Winsock: possibly internally limited to 64 sockets per set
        static int select(SJSocketSet checkRead, SJSocketSet checkWrite, SJSocketSet checkError, std.socket.timeval* tv)
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
                        throw new SocketException("Socket select error", _lasterr());

                return result;
        }


        /// ditto
        static int select(SJSocketSet checkRead, SJSocketSet checkWrite, SJSocketSet checkError, int microseconds)
        {
            std.socket.timeval tv;
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


