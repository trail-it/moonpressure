/* MIT. Bounded command transport for the example; no scheduling or process control. */
#include "moonbit.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

static moonbit_bytes_t frame(int status, const char *data, int n) {
  moonbit_bytes_t out = moonbit_make_bytes_raw(n + 4);
  for (int i = 0; i < 4; i++) out[i] = ((uint32_t)status >> (i * 8)) & 255;
  if (n) memcpy(out + 4, data, n);
  return out;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t mp_example_line(void) {
  char data[65536];
  int n = 0, ch;
  for (;;) {
    ch = getchar();
    if (ch == EOF) {
      if (ferror(stdin)) return frame(EIO, NULL, 0);
      return n ? frame(0, data, n) : frame(-1, NULL, 0);
    }
    if (ch == '\n') return frame(0, data, n);
    if (n == (int)sizeof(data)) {
      while (ch != EOF && ch != '\n') ch = getchar();
      return frame(EFBIG, NULL, 0);
    }
    data[n++] = (char)ch;
  }
}

MOONBIT_FFI_EXPORT int32_t mp_example_flush(void) {
  return fflush(stdout) == 0 ? 0 : EIO;
}
