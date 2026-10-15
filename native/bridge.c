/* MIT. File I/O, directory identity and time only; no diagnostics or policy. */
#define _POSIX_C_SOURCE 200809L
#include "moonbit.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#ifdef __linux__
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#endif

static moonbit_bytes_t result(int status, const void *data, int n) {
  moonbit_bytes_t out = moonbit_make_bytes_raw(n + 4);
  for (int i = 0; i < 4; i++) out[i] = ((uint32_t)status >> (i * 8)) & 255;
  if (n) memcpy(out + 4, data, n);
  return out;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t mp_read(moonbit_bytes_t path) {
#ifdef __linux__
  int fd = open((const char *)path, O_RDONLY | O_CLOEXEC);
  if (fd < 0) return result(errno, NULL, 0);
  char buffer[65537];
  int used = 0, error = 0;
  while (used < (int)sizeof(buffer)) {
    ssize_t n = read(fd, buffer + used, sizeof(buffer) - used);
    if (n < 0 && errno == EINTR) continue;
    if (n < 0) { error = errno; break; }
    if (!n) break;
    used += (int)n;
  }
  if (used > 65536) error = EFBIG;
  close(fd);
  return result(error, error ? NULL : buffer, error ? 0 : used);
#else
  (void)path;
  return result(95, NULL, 0);
#endif
}

MOONBIT_FFI_EXPORT moonbit_bytes_t mp_identity(moonbit_bytes_t path) {
#ifdef __linux__
  struct stat info;
  if (stat((const char *)path, &info) < 0) return result(errno, NULL, 0);
  if (!S_ISDIR(info.st_mode)) return result(ENOTDIR, NULL, 0);
  char buffer[96];
  int n = snprintf(buffer, sizeof(buffer), "%llu:%llu",
    (unsigned long long)info.st_dev, (unsigned long long)info.st_ino);
  return result(0, buffer, n);
#else
  (void)path;
  return result(95, NULL, 0);
#endif
}

MOONBIT_FFI_EXPORT int64_t mp_clock(void) {
#ifdef __linux__
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts)) return -1;
  return (int64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
#else
  return -1;
#endif
}

MOONBIT_FFI_EXPORT int32_t mp_sleep(int32_t ms) {
#ifdef __linux__
  if (ms < 1 || ms > 60000) return 22;
  struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
  while (nanosleep(&ts, &ts)) { if (errno != EINTR) return errno; }
  return 0;
#else
  (void)ms;
  return 95;
#endif
}
