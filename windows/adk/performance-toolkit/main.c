#include <stdio.h>
#include <stdlib.h>
#include <windows.h>

char* func1() {
    return (char*)malloc(sizeof(char) * 4096);
}

char* func2() {
    return (char*)malloc(sizeof(char) * 1024);
}

char* func3() {
    return (char*)VirtualAlloc(NULL, sizeof(char) * 3072, MEM_COMMIT, PAGE_NOACCESS);
}

int main() {
    char *buffer[150] = {};

    for (;;) {
        for (int i = 0; i < 150; i+=3) {
            buffer[i] = func1();
            buffer[i + 1] = func2();
            buffer[i + 2] = func3();
        }

        Sleep(100);

        for (int i = 0; i < 100; i+=3) {
            free(buffer[i]);
            free(buffer[i+1]);
            VirtualFree(buffer[i+2], 0, MEM_RELEASE);
        }

        Sleep(100);
    }

    return 0;
}
