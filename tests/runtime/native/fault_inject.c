/* Test-only Linux/glibc interposer. Never linked into a production tool.
 * Target selection is restricted to input.bin/output.bin in the probe scratch.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

extern void *__libc_malloc(size_t);
extern void *__libc_realloc(void *, size_t);
static const char *operation = "", *mode = "";
static int trace_fd = -1;
static _Atomic unsigned calls, armed, allocated;
static size_t split = 7;

static void trace(const char *event, unsigned call, size_t count) {
    char text[160];
    int length = snprintf(text, sizeof text, "%s %s call=%u bytes=%zu\n",
                          operation, event, call, count);
    if (trace_fd < 0 || length < 0 || (size_t)length >= sizeof text ||
        syscall(SYS_write, trace_fd, text, (size_t)length) != length)
        syscall(SYS_exit_group, 80);
}

__attribute__((constructor)) static void init_fault(void) {
    const char *op = getenv("BEND_PROBE_FAULT_OP");
    const char *how = getenv("BEND_PROBE_FAULT_MODE");
    const char *n = getenv("BEND_PROBE_FAULT_SPLIT");
    if (!op || !how) return;
    operation = op;
    mode = how;
    if (n) {
        unsigned long value = strtoul(n, NULL, 10);
        if (value == 0 || value > 4095) syscall(SYS_exit_group, 81);
        split = value;
    }
    trace_fd = syscall(SYS_openat, AT_FDCWD, "fault.trace",
                       O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    trace("armed", 0, split);
}

static int target_path(const char *path) {
    const char *tail = strrchr(path, '/');
    tail = tail ? tail + 1 : path;
    return !strcmp(tail, "input.bin") || !strcmp(tail, "output.bin");
}

static int target_fd(int fd) {
    char proc[64], path[1024];
    snprintf(proc, sizeof proc, "/proc/self/fd/%d", fd);
    ssize_t n = syscall(SYS_readlink, proc, path, sizeof path - 1);
    if (n < 0) return 0;
    path[n] = 0;
    return target_path(path);
}

static int opened(const char *path, int flags, mode_t perms) {
    int fd = syscall(SYS_openat, AT_FDCWD, path, flags, perms);
    if (fd >= 0 && target_path(path)) atomic_store(&armed, 1);
    return fd;
}

int open(const char *path, int flags, ...) {
    mode_t perms = 0;
    if (flags & O_CREAT) {
        va_list args; va_start(args, flags); perms = va_arg(args, int); va_end(args);
    }
    return opened(path, flags, perms);
}

int open64(const char *path, int flags, ...) {
    mode_t perms = 0;
    if (flags & O_CREAT) {
        va_list args; va_start(args, flags); perms = va_arg(args, int); va_end(args);
    }
    return opened(path, flags, perms);
}

/* Returns an artificial result, or -2 to request a real syscall. */
static ssize_t inject(const char *op, int fd, size_t *count) {
    if (strcmp(operation, op) || !target_fd(fd)) return -2;
    unsigned call = atomic_fetch_add(&calls, 1) + 1;
    if (!strcmp(mode, "stall") && call > 1) {
        trace("stall", call, *count);
        for (;;) pause();
    }
    if (!strcmp(mode, "eintr") && call == 1) {
        trace("EINTR", call, *count); errno = EINTR; return -1;
    }
    if (!strcmp(mode, "error") ||
        (!strcmp(mode, "partial-error") && call > 1) ||
        (!strcmp(mode, "transient-error") && call == 2)) {
        trace("EIO", call, *count); errno = EIO; return -1;
    }
    if (!strcmp(mode, "zero")) {
        trace("zero", call, *count); return 0;
    }
    if (!strcmp(mode, "enospc") && call > 1) {
        trace("ENOSPC", call, *count); errno = ENOSPC; return -1;
    }
    if (!strcmp(mode, "short") ||
        ((!strcmp(mode, "partial-error") || !strcmp(mode, "transient-error") ||
          !strcmp(mode, "enospc") || !strcmp(mode, "stall")) && call == 1)) {
        trace("request", call, *count);
        if (*count > split) {
            *count = split;
            trace("short", call, *count);
        } else {
            trace("unchanged", call, *count);
        }
    } else {
        trace("real", call, *count);
    }
    return -2;
}

ssize_t read(int fd, void *buffer, size_t count) {
    ssize_t r = inject("read", fd, &count);
    return r == -2 ? syscall(SYS_read, fd, buffer, count) : r;
}
ssize_t pread(int fd, void *buffer, size_t count, off_t offset) {
    ssize_t r = inject("pread", fd, &count);
    return r == -2 ? syscall(SYS_pread64, fd, buffer, count, offset) : r;
}
ssize_t pread64(int fd, void *buffer, size_t count, off64_t offset) {
    return pread(fd, buffer, count, offset);
}
ssize_t write(int fd, const void *buffer, size_t count) {
    ssize_t r = inject("write", fd, &count);
    return r == -2 ? syscall(SYS_write, fd, buffer, count) : r;
}
ssize_t pwrite(int fd, const void *buffer, size_t count, off_t offset) {
    ssize_t r = inject("pwrite", fd, &count);
    return r == -2 ? syscall(SYS_pwrite64, fd, buffer, count, offset) : r;
}
ssize_t pwrite64(int fd, const void *buffer, size_t count, off64_t offset) {
    return pwrite(fd, buffer, count, offset);
}
int close(int fd) {
    int selected = !strcmp(operation, "close") && target_fd(fd);
    int r = syscall(SYS_close, fd);
    if (selected && r == 0) {
        trace("EIO-after-close", 1, 0); errno = EIO; return -1;
    }
    return r;
}
void *malloc(size_t count) {
    if (!strcmp(operation, "malloc") && atomic_load(&armed) && count == 8193 &&
        !atomic_exchange(&allocated, 1)) {
        trace("ENOMEM", 1, count); errno = ENOMEM; return NULL;
    }
    return __libc_malloc(count);
}
void *realloc(void *pointer, size_t count) {
    if (!strcmp(operation, "realloc") && atomic_load(&armed) && count == 128 &&
        !atomic_exchange(&allocated, 1)) {
        trace("ENOMEM", 1, count); errno = ENOMEM; return NULL;
    }
    return __libc_realloc(pointer, count);
}
