#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <syslog.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <netinet/in.h>
#include <errno.h>
#include <arpa/inet.h>
#include <signal.h>

volatile sig_atomic_t signalReceived = 0;

void signal_handler(int signum) 
{
    if (signum == SIGINT || signum == SIGTERM) {
        signalReceived = 1;
    }
}

int main(int argc, char *argv[])
{
    int isDeamon = 0;
    if (argc > 1 && strcmp(argv[1], "-d") == 0) {
        isDeamon = 1;
    }
    /* Opens a stream socket bound to port 9000, failing and returning -1 if any of the socket connection steps fail. 
    On success, a file descriptor for the new socket is returned.  On
       error, -1 is returned, and errno is set to indicate the error.
*/

    openlog("aesdsocket", LOG_PID | LOG_CONS, LOG_USER);
    syslog(LOG_INFO, "Starting socket server assignment 5-1");

    struct sigaction sigAction = { .sa_handler = signal_handler };
    sigaction(SIGINT, &sigAction, NULL);
    sigaction(SIGTERM, &sigAction, NULL);

    int fd = socket(PF_INET, SOCK_STREAM, 0);
    if (fd == -1) return -1;
    syslog(LOG_INFO, "Socket created successfully");
    /*Opens a stream socket bound to port 9000, failing and returning -1 if any of the socket connection steps fail.
      int bind(int sockfd, const struct sockaddr *addr,                socklen_t addrlen);
      On success, zero is returned.  On error, -1 is returned, and errno
       is set to indicate the error.
      */

    /* int getaddrinfo(const char *restrict node,
                       const char *restrict service,
                       const struct addrinfo *restrict hints,
                       struct addrinfo **restrict res);*/

    
    struct addrinfo hints; /*https://man7.org/linux/man-pages/man3/getaddrinfo.3.html*/
    struct addrinfo *result;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;    /* Allow IPv4 or IPv6 */
    hints.ai_socktype = SOCK_STREAM; /* Datagram socket */
    hints.ai_flags = AI_PASSIVE;    /* For wildcard IP address */
    hints.ai_protocol = 0;          /* Any protocol */
    hints.ai_canonname = NULL;
    hints.ai_addr = NULL;
    hints.ai_next = NULL;
    int addrInfoRet = getaddrinfo(NULL, "9000", &hints, &result);
    if (addrInfoRet != 0) 
    {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(addrInfoRet));
        return -1;
    }
    printf("Before calling bind\n");

    if (bind(fd, result->ai_addr, result->ai_addrlen) != 0)
    {
        printf("Bind failed: %d\n", errno);
        close(fd);
        return -1;
    }   

    if (isDeamon && fork() != 0) {
        freeaddrinfo(result);
        close(fd);
        exit(EXIT_SUCCESS);
    }

    syslog(LOG_INFO, "Before freeing addrinfo result");
    freeaddrinfo(result);   
    
    listen(fd, 5); /*   int listen(int sockfd, int backlog); On success, zero is returned.  On error, -1 is returned, */
    syslog(LOG_INFO, "Listening on port 9000");

    /*      int accept(int sockfd, struct sockaddr *_Nullable restrict addr,    socklen_t *_Nullable restrict addrlen);*/
    /*On success, these system calls return a file descriptor for the
       accepted socket (a nonnegative integer).  On error, -1 */
    int acceptFd;
    struct sockaddr_storage client_addr;
    while (!signalReceived) 
    {
        socklen_t client_addr_len = sizeof(client_addr);
        acceptFd = accept(fd, (struct sockaddr*)&client_addr, &client_addr_len);
        syslog(LOG_INFO, "Accept returned %d", acceptFd);
        if (acceptFd == -1) 
        {
            if (errno == EINTR) 
            {
                continue;
            }
            break;
        }

        char clientIP[INET_ADDRSTRLEN];
        struct sockaddr_in *s = (struct sockaddr_in *)&client_addr;
        inet_ntop(AF_INET, &s->sin_addr, clientIP, sizeof(clientIP));
        syslog(LOG_INFO, "Accepted connection from %s", clientIP);

        FILE *fp = fopen("/var/tmp/aesdsocketdata", "a"); /*append because the sender can send more than one line*/

        char buffer[1024];
        ssize_t recvd;
        do 
        {
            for (int i = 0; i < 1024;++i) /* set buffer to 0 not 100% sure it is required but better safe than sorry*/
            {
                buffer[i] = 0;
            }
            recvd = recv(acceptFd, buffer, 1024, 0); /*read up to 1024 bytes*/
            if (recvd > 0) 
            {
                printf("Received: %d, %s", recvd, buffer);
                fwrite(buffer, 1, recvd, fp); /* write buffer to file*/
                if (memchr(buffer, '\n', recvd)) /* receiving ends with newline */
                { 
                    break;
                }
            }
        } while (recvd > 0);

        fclose(fp); /*close to reopen immediately read-only*/


        fp = fopen("/var/tmp/aesdsocketdata", "r");

        for (int i = 0; i < 1024;++i)
        {
            buffer[i] = 0;
        }
        while ((recvd = fread(buffer, 1, 1024, fp)) > 0) /*read from temp file*/
        {
            printf("Sending %d, %s", recvd, buffer);
            send(acceptFd, buffer, recvd, 0); /*send back*/
        }
        printf("Done...sleeping now 1s\n");
        sleep(1);
    }

    printf("Shutting down\n");
    syslog(LOG_INFO, "Shutting down");
    close(fd);
    unlink("/var/tmp/aesdsocketdata"); /*delete temp file*/
    closelog();
    
}