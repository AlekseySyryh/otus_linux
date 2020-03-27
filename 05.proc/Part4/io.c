#define _GNU_SOURCE 
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h> 
#include <malloc.h>

void main() {
	srand(time(0)); 
	char *c;
	size_t length = 512;
	size_t alignment = 512;
	int f = open("file", O_DIRECT|O_RDONLY);
    	c = memalign(alignment * 2, length + alignment);
    	c += alignment;
	long size = lseek(f, 0, SEEK_END)/512;
	for (int i = 0; i < 1000; ++i) {
		lseek(f, rand()%size*512, SEEK_SET);
		read(f, c, length);
    	}
}
