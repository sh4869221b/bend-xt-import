/* Test coordinator only: two real Bend processes contend on the same file. */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
int main(void) {
    int gate[2]; pid_t children[2];
    if (pipe(gate)) return 70;
    for (int i=0;i<2;i++) {
        children[i]=fork();
        if (children[i]<0) return 71;
        if (!children[i]) {
            char token;
            close(gate[1]);
            if (read(gate[0],&token,1)!=1) _exit(72);
            close(gate[0]);
            execl("/probes/exclusive_create","/probes/exclusive_create",
                  "+RTS","--threads","1","--gpu","off","-RTS",(char*)NULL);
            _exit(73);
        }
    }
    close(gate[0]);
    if (write(gate[1],"go",2)!=2) return 74;
    close(gate[1]);
    int wins=0,exists=0;
    for(int i=0;i<2;i++) {
        int status;
        if(waitpid(children[i],&status,0)!=children[i] || !WIFEXITED(status)) return 75;
        wins+=WEXITSTATUS(status)==0;
        exists+=WEXITSTATUS(status)==EEXIST;
    }
    if(wins!=1 || exists!=1) return 76;
    puts("one-created-one-EEXIST");
    return 0;
}
