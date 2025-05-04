#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <errno.h>
#include <string.h>

int main(int argc, char *argv[])
{
    openlog("writer", LOG_PID | LOG_PERROR, LOG_USER);
    if (argc != 3)
    {
        syslog(LOG_ERR, "Usage: %s <writefile> <writestr>", argv[0]);
        closelog();
        return 1;
    }
    
    const char * writefile = argv[1];
    const char * writestr = argv[2];
    
    FILE * file = fopen(writefile, "w");
    if (file == NULL) 
    {
        syslog(LOG_ERR, "Error opening file %s: %s", writefile, strerror(errno));
        closelog();
        return 1;
    }
    
    if (fprintf(file, "%s", writestr) < 0) 
    {
        syslog(LOG_ERR, "Error writing to file %s: %s", writefile, strerror(errno));
        fclose(file);
        closelog();
        return 1;
    }

    fclose(file);

    syslog(LOG_INFO, "Successfully wrote to %s", writefile);

    closelog();

    return 0;
    

    syslog(LOG_DEBUG, "Writing \"%s\" to %s", writestr, writefile);

    
    return 0;
}