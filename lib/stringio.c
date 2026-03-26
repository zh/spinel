/*
 * stringio.c — StringIO C implementation for Spinel
 *
 * Provides sp_StringIO_* functions that the generated C code calls.
 * In-memory IO object with a growable string buffer.
 *
 * Usage: cc -O2 app.c lib/stringio.c -lm -o app
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdarg.h>

typedef struct {
  char *buf;        /* heap-allocated buffer */
  int64_t len;      /* current string length */
  int64_t cap;      /* buffer capacity */
  int64_t pos;      /* current read/write position */
  int64_t lineno;   /* line number counter (for gets) */
  int closed;       /* 1 if closed */
} sp_StringIO;

/* Internal: ensure buffer has room for `need` more bytes */
static void sio_grow(sp_StringIO *sio, int64_t need) {
  int64_t required = sio->pos + need;
  if (required <= sio->cap) return;
  int64_t new_cap = sio->cap ? sio->cap : 64;
  while (new_cap < required) new_cap *= 2;
  sio->buf = (char *)realloc(sio->buf, new_cap + 1);
  sio->cap = new_cap;
}

/* Internal: write bytes at current position, extending buffer as needed */
static int64_t sio_write(sp_StringIO *sio, const char *data, int64_t data_len) {
  sio_grow(sio, data_len);
  /* Fill gap with zeros if pos > len */
  if (sio->pos > sio->len) {
    memset(sio->buf + sio->len, 0, sio->pos - sio->len);
  }
  memcpy(sio->buf + sio->pos, data, data_len);
  sio->pos += data_len;
  if (sio->pos > sio->len) sio->len = sio->pos;
  sio->buf[sio->len] = '\0';
  return data_len;
}

/* Constructor: StringIO.new or StringIO.new("initial") */
sp_StringIO *sp_StringIO_new(void) {
  sp_StringIO *sio = (sp_StringIO *)calloc(1, sizeof(sp_StringIO));
  sio->buf = (char *)calloc(1, 64);
  sio->cap = 63;
  return sio;
}

sp_StringIO *sp_StringIO_new_s(const char *initial) {
  sp_StringIO *sio = (sp_StringIO *)calloc(1, sizeof(sp_StringIO));
  int64_t len = (int64_t)strlen(initial);
  int64_t cap = len < 63 ? 63 : len;
  sio->buf = (char *)malloc(cap + 1);
  memcpy(sio->buf, initial, len);
  sio->buf[len] = '\0';
  sio->len = len;
  sio->cap = cap;
  sio->pos = 0;
  return sio;
}

/* string — return the buffer contents as a C string */
const char *sp_StringIO_string(sp_StringIO *sio) {
  return sio->buf ? sio->buf : "";
}

/* pos / tell — current position */
int64_t sp_StringIO_pos(sp_StringIO *sio) {
  return sio->pos;
}

/* pos= — set position */
int64_t sp_StringIO_set_pos(sp_StringIO *sio, int64_t new_pos) {
  if (new_pos < 0) new_pos = 0;
  sio->pos = new_pos;
  return sio->pos;
}

/* lineno */
int64_t sp_StringIO_lineno(sp_StringIO *sio) {
  return sio->lineno;
}

/* size / length — string length */
int64_t sp_StringIO_size(sp_StringIO *sio) {
  return sio->len;
}

/* write(str) — write string at current position, return bytes written */
int64_t sp_StringIO_write(sp_StringIO *sio, const char *str) {
  return sio_write(sio, str, (int64_t)strlen(str));
}

/* puts(str) — write string + newline */
int64_t sp_StringIO_puts(sp_StringIO *sio, const char *str) {
  int64_t slen = (int64_t)strlen(str);
  sio_write(sio, str, slen);
  /* Add newline unless string already ends with one */
  if (slen == 0 || str[slen - 1] != '\n')
    sio_write(sio, "\n", 1);
  return 0;  /* Ruby puts returns nil */
}

/* puts() with no args — just a newline */
int64_t sp_StringIO_puts_empty(sp_StringIO *sio) {
  sio_write(sio, "\n", 1);
  return 0;
}

/* print(str) — write string without newline */
int64_t sp_StringIO_print(sp_StringIO *sio, const char *str) {
  return sio_write(sio, str, (int64_t)strlen(str));
}

/* putc(ch) — write a single character (integer or first char of string) */
int64_t sp_StringIO_putc(sp_StringIO *sio, int64_t ch) {
  char c = (char)(ch & 0xFF);
  sio_write(sio, &c, 1);
  return ch;
}

/* << operator — append, return self (for chaining) */
sp_StringIO *sp_StringIO_append(sp_StringIO *sio, const char *str) {
  sio_write(sio, str, (int64_t)strlen(str));
  return sio;
}

/* read() — read from pos to end */
const char *sp_StringIO_read(sp_StringIO *sio) {
  if (sio->pos >= sio->len) return "";
  const char *result = sio->buf + sio->pos;
  sio->pos = sio->len;
  return result;
}

/* read(length) — read up to length bytes */
const char *sp_StringIO_read_n(sp_StringIO *sio, int64_t length) {
  if (sio->pos >= sio->len) return NULL;
  int64_t remaining = sio->len - sio->pos;
  if (length > remaining) length = remaining;
  /* Return a temporary substring — caller should copy if needed */
  static char read_buf[65536];
  if (length >= (int64_t)sizeof(read_buf)) length = sizeof(read_buf) - 1;
  memcpy(read_buf, sio->buf + sio->pos, length);
  read_buf[length] = '\0';
  sio->pos += length;
  return read_buf;
}

/* gets — read one line (up to and including \n), return NULL at EOF */
const char *sp_StringIO_gets(sp_StringIO *sio) {
  if (sio->pos >= sio->len) return NULL;
  const char *start = sio->buf + sio->pos;
  const char *nl = memchr(start, '\n', sio->len - sio->pos);
  int64_t line_len;
  if (nl) {
    line_len = (nl - start) + 1;
  }
  else {
    line_len = sio->len - sio->pos;
  }
  /* Return a temporary buffer */
  static char gets_buf[65536];
  if (line_len >= (int64_t)sizeof(gets_buf)) line_len = sizeof(gets_buf) - 1;
  memcpy(gets_buf, start, line_len);
  gets_buf[line_len] = '\0';
  sio->pos += line_len;
  sio->lineno++;
  return gets_buf;
}

/* getc — read one character, return NULL at EOF */
const char *sp_StringIO_getc(sp_StringIO *sio) {
  if (sio->pos >= sio->len) return NULL;
  static char getc_buf[2];
  getc_buf[0] = sio->buf[sio->pos++];
  getc_buf[1] = '\0';
  return getc_buf;
}

/* getbyte — read one byte as integer, return -1 at EOF */
int64_t sp_StringIO_getbyte(sp_StringIO *sio) {
  if (sio->pos >= sio->len) return -1;
  return (int64_t)(unsigned char)sio->buf[sio->pos++];
}

/* rewind — reset position and lineno to 0 */
int64_t sp_StringIO_rewind(sp_StringIO *sio) {
  sio->pos = 0;
  sio->lineno = 0;
  return 0;
}

/* seek(offset, whence) — set position, whence: 0=SET, 1=CUR, 2=END */
int64_t sp_StringIO_seek(sp_StringIO *sio, int64_t offset, int64_t whence) {
  int64_t new_pos;
  switch (whence) {
  case 1: new_pos = sio->pos + offset; break;   /* SEEK_CUR */
  case 2: new_pos = sio->len + offset; break;    /* SEEK_END */
  default: new_pos = offset; break;               /* SEEK_SET */
  }
  if (new_pos < 0) new_pos = 0;
  sio->pos = new_pos;
  return 0;
}

/* eof? — true if at or past end */
int sp_StringIO_eof_p(sp_StringIO *sio) {
  return sio->pos >= sio->len;
}

/* truncate(length) — truncate buffer to given length */
int64_t sp_StringIO_truncate(sp_StringIO *sio, int64_t length) {
  if (length < 0) length = 0;
  if (length < sio->len) {
    sio->len = length;
    sio->buf[length] = '\0';
  }
  return 0;
}

/* close — mark as closed */
int64_t sp_StringIO_close(sp_StringIO *sio) {
  sio->closed = 1;
  return 0;
}

/* closed? */
int sp_StringIO_closed_p(sp_StringIO *sio) {
  return sio->closed;
}

/* flush — no-op for StringIO, return self */
sp_StringIO *sp_StringIO_flush(sp_StringIO *sio) {
  return sio;
}

/* sync — always true */
int sp_StringIO_sync(sp_StringIO *sio) {
  (void)sio;
  return 1;
}

/* isatty / tty? — always false */
int sp_StringIO_isatty(sp_StringIO *sio) {
  (void)sio;
  return 0;
}

/* fileno — nil (returns -1 for C) */
int64_t sp_StringIO_fileno(sp_StringIO *sio) {
  (void)sio;
  return -1;
}

/* printf(fmt, ...) — formatted print to buffer */
int64_t sp_StringIO_printf(sp_StringIO *sio, const char *fmt, ...) {
  char tmp[8192];
  va_list ap;
  va_start(ap, fmt);
  int n = vsnprintf(tmp, sizeof(tmp), fmt, ap);
  va_end(ap);
  if (n > 0) sio_write(sio, tmp, n);
  return n;
}

/* string= — replace buffer contents */
void sp_StringIO_set_string(sp_StringIO *sio, const char *str) {
  int64_t len = (int64_t)strlen(str);
  if (len > sio->cap) {
    sio->cap = len;
    sio->buf = (char *)realloc(sio->buf, sio->cap + 1);
  }
  memcpy(sio->buf, str, len);
  sio->buf[len] = '\0';
  sio->len = len;
  sio->pos = 0;
}
