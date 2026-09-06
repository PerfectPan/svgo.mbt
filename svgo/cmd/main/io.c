#include <stdio.h>
#include <stdlib.h>
#include "moonbit.h"

moonbit_bytes_t svgo_read_file(moonbit_bytes_t path) {
  FILE *f = fopen((const char *)path, "rb");
  if (f == NULL) return moonbit_make_bytes(0, 0);
  if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return moonbit_make_bytes(0, 0); }
  long n = ftell(f);
  if (n < 0) { fclose(f); return moonbit_make_bytes(0, 0); }
  fseek(f, 0, SEEK_SET);
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)n, 0);
  size_t got = fread(out, 1, (size_t)n, f);
  (void)got;
  fclose(f);
  return out;
}

int32_t svgo_write_file(moonbit_bytes_t path, moonbit_bytes_t data) {
  FILE *f = fopen((const char *)path, "wb");
  if (f == NULL) return -1;
  int32_t len = Moonbit_array_length(data);
  size_t wrote = fwrite(data, 1, (size_t)len, f);
  fclose(f);
  return wrote == (size_t)len ? 0 : -1;
}
