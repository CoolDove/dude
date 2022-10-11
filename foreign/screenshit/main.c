#include <stdlib.h>

// impl screenshot here

int test_add(int a, int b) {
    return a + b;
}

extern void* alloc_mem(int count) {
    int* ptr = (void*)malloc(sizeof(int) * count);
    for (int i = 0; i < count; i++) {
        ptr[i] = i;
    }
    return ptr;
}

extern void release_mem(int* ptr) {
    free(ptr);
}
