#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <string.h>
#include <errno.h>
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

moonbit_bytes_t svgo_read_stdin(void) {
  size_t cap = 65536, len = 0;
  char *buf = malloc(cap);
  if (buf == NULL) return moonbit_make_bytes(0, 0);
  for (;;) {
    if (len == cap) {
      cap *= 2;
      char *nb = realloc(buf, cap);
      if (nb == NULL) { free(buf); return moonbit_make_bytes(0, 0); }
      buf = nb;
    }
    size_t got = fread(buf + len, 1, cap - len, stdin);
    len += got;
    if (got == 0) break;
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) memcpy(out, buf, len);
  free(buf);
  return out;
}

int32_t svgo_stdin_is_tty(void) {
  return isatty(0) ? 1 : 0;
}

void svgo_exit(int32_t code) {
  exit(code);
}

void svgo_eprint(moonbit_bytes_t s) {
  int32_t len = Moonbit_array_length(s);
  fwrite(s, 1, (size_t)len, stderr);
}

int32_t svgo_is_dir(moonbit_bytes_t path) {
  struct stat st;
  if (stat((const char *)path, &st) != 0) return 0;
  return S_ISDIR(st.st_mode) ? 1 : 0;
}

moonbit_bytes_t svgo_list_dir(moonbit_bytes_t path) {
  DIR *d = opendir((const char *)path);
  if (d == NULL) return moonbit_make_bytes(0, 0);
  size_t cap = 1024, len = 0;
  char *buf = malloc(cap);
  if (buf == NULL) { closedir(d); return moonbit_make_bytes(0, 0); }
  struct dirent *e;
  while ((e = readdir(d)) != NULL) {
    if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
    size_t nlen = strlen(e->d_name);
    if (len + nlen + 2 > cap) {
      while (len + nlen + 2 > cap) cap *= 2;
      char *nb = realloc(buf, cap);
      if (nb == NULL) { free(buf); closedir(d); return moonbit_make_bytes(0, 0); }
      buf = nb;
    }
    memcpy(buf + len, e->d_name, nlen);
    len += nlen;
    buf[len++] = '\n';
  }
  closedir(d);
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) memcpy(out, buf, len);
  free(buf);
  return out;
}

int32_t svgo_mkdir_p(moonbit_bytes_t path) {
  const char *p = (const char *)path;
  char *tmp = strdup(p);
  if (tmp == NULL) return -1;
  size_t len = strlen(tmp);
  for (size_t i = 1; i < len; i++) {
    if (tmp[i] == '/') {
      tmp[i] = '\0';
      if (mkdir(tmp, 0755) != 0 && errno != EEXIST) { free(tmp); return -1; }
      tmp[i] = '/';
    }
  }
  if (mkdir(tmp, 0755) != 0 && errno != EEXIST) { free(tmp); return -1; }
  free(tmp);
  return 0;
}
