#include <math.h>
#include <sys/sysinfo.h>
#include <unistd.h>
#include <pthread.h>

void * threadFun()
{
    double d = 986198729833;
    for (int i = 0; i < 2000000000; ++i) {
        d = 1/sqrt(d)+i;
    }
    return NULL;
}

int main() {
    int nprocs = get_nprocs();
    pthread_t threads[nprocs];

    for (int i = 0; i < nprocs; ++i) {
        pthread_create(&threads[i], NULL, threadFun, NULL);
    }
    for (int i = 0; i < nprocs; ++i) {
        pthread_join(threads[i], NULL);
    }

    return 0;
}
