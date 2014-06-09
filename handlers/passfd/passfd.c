#ifndef __OpenBSD__
#ifndef _XOPEN_SOURCE
#define _XOPEN_SOURCE 500
#endif
#ifndef _XOPEN_SOURCE_EXTENDED
#define _XOPEN_SOURCE_EXTENDED 1 /* Solaris <= 2.7 needs this too */
#endif
#endif /* __OpenBSD__ */

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/uio.h>
#include <stddef.h>

/* for platforms that don't provide CMSG_*  macros */
#ifndef ALIGNBYTES
#define ALIGNBYTES (sizeof(int) - 1)
#endif

#ifndef ALIGN
#define ALIGN(p) (((unsigned int)(p) + ALIGNBYTES) & ~ ALIGNBYTES)
#endif

#ifndef CMSG_LEN
#define CMSG_LEN(len) (ALIGN(sizeof(struct cmsghdr)) + ALIGN(len))
#endif

#ifndef CMSG_SPACE
#define CMSG_SPACE(len) (ALIGN(sizeof(struct cmsghdr)) + ALIGN(len))
#endif

typedef int socket_t;

int recv_fd(int sockfd)
{
	ssize_t rv;
	char tmp[CMSG_SPACE(sizeof(int))];
	struct cmsghdr *cmsg;
	struct iovec iov;
	struct msghdr msg;
	char ch = '\0';

	memset(&msg, 0, sizeof(msg));
	iov.iov_base = &ch;
	iov.iov_len = 1;
	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;
	msg.msg_control = tmp;
	msg.msg_controllen = sizeof(tmp);

	rv = recvmsg(sockfd, &msg, 0);
	if (rv <= 0) {
		return -1;
	}
	cmsg = CMSG_FIRSTHDR(&msg);
	return *(int *) CMSG_DATA(cmsg);
}

int send_fd (int sockfd, int fd)
{
	ssize_t rv;
	char tmp[CMSG_SPACE(sizeof(int))];
	struct cmsghdr *cmsg;
	struct iovec iov;
	struct msghdr msg;
	char ch = '\0';

	memset(&msg, 0, sizeof(msg));
	msg.msg_control = (char*) tmp;
	msg.msg_controllen = CMSG_LEN(sizeof(int));
	cmsg = CMSG_FIRSTHDR(&msg);
	cmsg->cmsg_len = CMSG_LEN(sizeof(int));
	cmsg->cmsg_level = SOL_SOCKET;
	cmsg->cmsg_type = SCM_RIGHTS;
	*(int *)CMSG_DATA(cmsg) = fd;
	iov.iov_base = &ch;
	iov.iov_len = 1;
	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;

	rv = sendmsg(sockfd, &msg, 0);
	if (rv != 1)
		return -1;

	return 0;
}

