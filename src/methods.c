/*
 * methods.c - Built-in method tables for Spinel AOT compiler
 *
 * Single source of truth for:
 *   - Method existence (respond_to?)
 *   - Return type inference
 *   - Argument count validation
 *
 * Code generation (expr.c) remains separate since handlers
 * are too varied for a uniform function pointer interface.
 */

#include <string.h>
#include "codegen.h"

/* Shorthand for table entries */
#define M(name, ret, min, max) {name, ret, min, max, false}
#define MB(name, ret, min, max) {name, ret, min, max, true}
#define END {NULL, 0, 0, 0, false}

/* ------------------------------------------------------------------ */
/* Universal methods (available on all types)                          */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t universal_methods[] = {
  M("nil?",        SPINEL_TYPE_BOOLEAN, 0, 0),
  M("is_a?",       SPINEL_TYPE_BOOLEAN, 1, 1),
  M("respond_to?", SPINEL_TYPE_BOOLEAN, 1, 1),
  M("class",       SPINEL_TYPE_STRING,  0, 0),
  M("to_s",        SPINEL_TYPE_STRING,  0, 0),
  M("freeze",      SPINEL_TYPE_UNKNOWN, 0, 0), /* returns self */
  M("frozen?",     SPINEL_TYPE_BOOLEAN, 0, 0),
  M("dup",         SPINEL_TYPE_UNKNOWN, 0, 0), /* returns self-type */
  M("==",          SPINEL_TYPE_BOOLEAN, 1, 1),
  M("!=",          SPINEL_TYPE_BOOLEAN, 1, 1),
  M("equal?",      SPINEL_TYPE_BOOLEAN, 1, 1),
  M("hash",        SPINEL_TYPE_INTEGER, 0, 0),
  M("itself",      SPINEL_TYPE_UNKNOWN, 0, 0),
  END
};

/* ------------------------------------------------------------------ */
/* Integer methods                                                     */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t integer_methods[] = {
  /* Arithmetic */
  M("+",  SPINEL_TYPE_INTEGER, 1, 1),
  M("-",  SPINEL_TYPE_INTEGER, 1, 1),
  M("*",  SPINEL_TYPE_INTEGER, 1, 1),
  M("/",  SPINEL_TYPE_INTEGER, 1, 1),
  M("%",  SPINEL_TYPE_INTEGER, 1, 1),
  M("**", SPINEL_TYPE_INTEGER, 1, 1),
  M("-@", SPINEL_TYPE_INTEGER, 0, 0),
  /* Comparison */
  M("<",  SPINEL_TYPE_BOOLEAN, 1, 1),
  M(">",  SPINEL_TYPE_BOOLEAN, 1, 1),
  M("<=", SPINEL_TYPE_BOOLEAN, 1, 1),
  M(">=", SPINEL_TYPE_BOOLEAN, 1, 1),
  M("<=>", SPINEL_TYPE_INTEGER, 1, 1),
  /* Bitwise */
  M("&",  SPINEL_TYPE_INTEGER, 1, 1),
  M("|",  SPINEL_TYPE_INTEGER, 1, 1),
  M("^",  SPINEL_TYPE_INTEGER, 1, 1),
  M("<<", SPINEL_TYPE_INTEGER, 1, 1),
  M(">>", SPINEL_TYPE_INTEGER, 1, 1),
  M("~",  SPINEL_TYPE_INTEGER, 0, 0),
  /* Query */
  M("abs",        SPINEL_TYPE_INTEGER, 0, 0),
  M("even?",      SPINEL_TYPE_BOOLEAN, 0, 0),
  M("odd?",       SPINEL_TYPE_BOOLEAN, 0, 0),
  M("zero?",      SPINEL_TYPE_BOOLEAN, 0, 0),
  M("positive?",  SPINEL_TYPE_BOOLEAN, 0, 0),
  M("negative?",  SPINEL_TYPE_BOOLEAN, 0, 0),
  M("nonzero?",   SPINEL_TYPE_INTEGER, 0, 0),
  /* Conversion */
  M("to_i",   SPINEL_TYPE_INTEGER, 0, 0),
  M("to_int", SPINEL_TYPE_INTEGER, 0, 0),
  M("to_f",   SPINEL_TYPE_FLOAT,   0, 0),
  M("to_s",   SPINEL_TYPE_STRING,  0, 0),
  M("chr",    SPINEL_TYPE_STRING,  0, 0),
  M("ord",    SPINEL_TYPE_INTEGER, 0, 0),
  /* Math */
  M("succ",       SPINEL_TYPE_INTEGER, 0, 0),
  M("next",       SPINEL_TYPE_INTEGER, 0, 0),
  M("pred",       SPINEL_TYPE_INTEGER, 0, 0),
  M("floor",      SPINEL_TYPE_INTEGER, 0, 0),
  M("ceil",       SPINEL_TYPE_INTEGER, 0, 0),
  M("round",      SPINEL_TYPE_INTEGER, 0, 0),
  M("truncate",   SPINEL_TYPE_INTEGER, 0, 0),
  M("clamp",      SPINEL_TYPE_INTEGER, 2, 2),
  M("gcd",        SPINEL_TYPE_INTEGER, 1, 1),
  M("lcm",        SPINEL_TYPE_INTEGER, 1, 1),
  M("pow",        SPINEL_TYPE_INTEGER, 1, 2),
  M("bit_length", SPINEL_TYPE_INTEGER, 0, 0),
  M("[]",         SPINEL_TYPE_INTEGER, 1, 1),
  M("divmod",     SPINEL_TYPE_ARRAY,   1, 1),
  M("digits",     SPINEL_TYPE_ARRAY,   0, 1),
  /* Iteration */
  MB("times",  SPINEL_TYPE_INTEGER, 0, 0),
  MB("upto",   SPINEL_TYPE_INTEGER, 1, 1),
  MB("downto", SPINEL_TYPE_INTEGER, 1, 1),
  END
};

/* ------------------------------------------------------------------ */
/* Float methods                                                       */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t float_methods[] = {
  /* Arithmetic */
  M("+",  SPINEL_TYPE_FLOAT, 1, 1),
  M("-",  SPINEL_TYPE_FLOAT, 1, 1),
  M("*",  SPINEL_TYPE_FLOAT, 1, 1),
  M("/",  SPINEL_TYPE_FLOAT, 1, 1),
  M("%",  SPINEL_TYPE_FLOAT, 1, 1),
  M("**", SPINEL_TYPE_FLOAT, 1, 1),
  M("-@", SPINEL_TYPE_FLOAT, 0, 0),
  /* Comparison */
  M("<",   SPINEL_TYPE_BOOLEAN, 1, 1),
  M(">",   SPINEL_TYPE_BOOLEAN, 1, 1),
  M("<=",  SPINEL_TYPE_BOOLEAN, 1, 1),
  M(">=",  SPINEL_TYPE_BOOLEAN, 1, 1),
  M("<=>", SPINEL_TYPE_INTEGER, 1, 1),
  /* Query */
  M("abs",       SPINEL_TYPE_FLOAT,   0, 0),
  M("zero?",     SPINEL_TYPE_BOOLEAN, 0, 0),
  M("positive?", SPINEL_TYPE_BOOLEAN, 0, 0),
  M("negative?", SPINEL_TYPE_BOOLEAN, 0, 0),
  M("infinite?", SPINEL_TYPE_BOOLEAN, 0, 0),
  M("nan?",      SPINEL_TYPE_BOOLEAN, 0, 0),
  M("finite?",   SPINEL_TYPE_BOOLEAN, 0, 0),
  M("nonzero?",  SPINEL_TYPE_FLOAT,   0, 0),
  /* Conversion */
  M("to_i",     SPINEL_TYPE_INTEGER, 0, 0),
  M("to_f",     SPINEL_TYPE_FLOAT,   0, 0),
  M("to_s",     SPINEL_TYPE_STRING,  0, 0),
  M("ceil",     SPINEL_TYPE_INTEGER, 0, 0),
  M("floor",    SPINEL_TYPE_INTEGER, 0, 0),
  M("round",    SPINEL_TYPE_INTEGER, 0, 0),
  M("truncate", SPINEL_TYPE_INTEGER, 0, 0),
  M("clamp",    SPINEL_TYPE_FLOAT,   2, 2),
  END
};

/* ------------------------------------------------------------------ */
/* String methods                                                      */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t string_methods[] = {
  /* Query */
  M("length",      SPINEL_TYPE_INTEGER, 0, 0),
  M("size",        SPINEL_TYPE_INTEGER, 0, 0),
  M("bytesize",    SPINEL_TYPE_INTEGER, 0, 0),
  M("empty?",      SPINEL_TYPE_BOOLEAN, 0, 0),
  M("include?",    SPINEL_TYPE_BOOLEAN, 1, 1),
  M("start_with?", SPINEL_TYPE_BOOLEAN, 1, -1),
  M("end_with?",   SPINEL_TYPE_BOOLEAN, 1, -1),
  M("match?",      SPINEL_TYPE_BOOLEAN, 1, 1),
  M("ascii_only?", SPINEL_TYPE_BOOLEAN, 0, 0),
  M("count",       SPINEL_TYPE_INTEGER, 1, 1),
  M("index",       SPINEL_TYPE_INTEGER, 1, 2),
  M("rindex",      SPINEL_TYPE_INTEGER, 1, 2),
  M("=~",          SPINEL_TYPE_INTEGER, 1, 1),
  M("ord",         SPINEL_TYPE_INTEGER, 0, 0),
  M("getbyte",     SPINEL_TYPE_INTEGER, 1, 1),
  /* Access */
  M("[]",    SPINEL_TYPE_STRING, 1, 2),
  M("slice", SPINEL_TYPE_STRING, 1, 2),
  /* Transform */
  M("+",          SPINEL_TYPE_STRING, 1, 1),
  M("*",          SPINEL_TYPE_STRING, 1, 1),
  M("<<",         SPINEL_TYPE_STRING, 1, 1),
  M("concat",     SPINEL_TYPE_STRING, 1, -1),
  M("upcase",     SPINEL_TYPE_STRING, 0, 0),
  M("downcase",   SPINEL_TYPE_STRING, 0, 0),
  M("capitalize", SPINEL_TYPE_STRING, 0, 0),
  M("swapcase",   SPINEL_TYPE_STRING, 0, 0),
  M("reverse",    SPINEL_TYPE_STRING, 0, 0),
  M("strip",      SPINEL_TYPE_STRING, 0, 0),
  M("lstrip",     SPINEL_TYPE_STRING, 0, 0),
  M("rstrip",     SPINEL_TYPE_STRING, 0, 0),
  M("chomp",      SPINEL_TYPE_STRING, 0, 1),
  M("chop",       SPINEL_TYPE_STRING, 0, 0),
  M("gsub",       SPINEL_TYPE_STRING, 2, 2),
  M("sub",        SPINEL_TYPE_STRING, 2, 2),
  M("tr",         SPINEL_TYPE_STRING, 2, 2),
  M("delete",     SPINEL_TYPE_STRING, 1, -1),
  M("squeeze",    SPINEL_TYPE_STRING, 0, 1),
  M("ljust",      SPINEL_TYPE_STRING, 1, 2),
  M("rjust",      SPINEL_TYPE_STRING, 1, 2),
  M("center",     SPINEL_TYPE_STRING, 1, 2),
  M("replace",    SPINEL_TYPE_STRING, 1, 1),
  M("insert",     SPINEL_TYPE_STRING, 2, 2),
  /* Conversion */
  M("to_i",   SPINEL_TYPE_INTEGER, 0, 1),
  M("to_f",   SPINEL_TYPE_FLOAT,   0, 0),
  M("to_s",   SPINEL_TYPE_STRING,  0, 0),
  M("to_str", SPINEL_TYPE_STRING,  0, 0),
  M("to_sym", SPINEL_TYPE_STRING,  0, 0),
  M("intern", SPINEL_TYPE_STRING,  0, 0),
  M("hex",    SPINEL_TYPE_INTEGER, 0, 0),
  M("oct",    SPINEL_TYPE_INTEGER, 0, 0),
  M("encode", SPINEL_TYPE_STRING,  0, 2),
  M("b",      SPINEL_TYPE_STRING,  0, 0),
  /* Split/iterate */
  M("split",     SPINEL_TYPE_STR_ARRAY, 0, 2),
  M("chars",     SPINEL_TYPE_STR_ARRAY, 0, 0),
  M("bytes",     SPINEL_TYPE_ARRAY,     0, 0),
  M("each_line", SPINEL_TYPE_STR_ARRAY, 0, 1),
  MB("each_char", SPINEL_TYPE_STRING, 0, 0),
  /* Mutable copy */
  M("dup",       SPINEL_TYPE_SP_STRING, 0, 0),
  M("setbyte",   SPINEL_TYPE_INTEGER,   2, 2),
  M("freeze",    SPINEL_TYPE_STRING,    0, 0),
  M("frozen?",   SPINEL_TYPE_BOOLEAN,   0, 0),
  END
};

/* ------------------------------------------------------------------ */
/* Array methods (IntArray)                                            */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t array_methods[] = {
  /* Access */
  M("[]",     SPINEL_TYPE_INTEGER, 1, 1),
  M("[]=",    SPINEL_TYPE_INTEGER, 2, 2),
  M("first",  SPINEL_TYPE_INTEGER, 0, 0),
  M("last",   SPINEL_TYPE_INTEGER, 0, 0),
  M("sample", SPINEL_TYPE_INTEGER, 0, 0),
  /* Query */
  M("length",   SPINEL_TYPE_INTEGER, 0, 0),
  M("size",     SPINEL_TYPE_INTEGER, 0, 0),
  M("empty?",   SPINEL_TYPE_BOOLEAN, 0, 0),
  M("include?", SPINEL_TYPE_BOOLEAN, 1, 1),
  /* Modify */
  M("push",      SPINEL_TYPE_ARRAY, 1, -1),
  M("<<",        SPINEL_TYPE_ARRAY, 1, 1),
  M("pop",       SPINEL_TYPE_INTEGER, 0, 0),
  M("shift",     SPINEL_TYPE_INTEGER, 0, 0),
  M("unshift",   SPINEL_TYPE_INTEGER, 1, 1),
  M("insert",    SPINEL_TYPE_ARRAY,   2, 2),
  M("delete",    SPINEL_TYPE_INTEGER, 1, 1),
  M("delete_at", SPINEL_TYPE_INTEGER, 1, 1),
  /* Transform */
  M("sort",      SPINEL_TYPE_ARRAY, 0, 0),
  M("sort!",     SPINEL_TYPE_ARRAY, 0, 0),
  M("reverse",   SPINEL_TYPE_ARRAY, 0, 0),
  M("reverse!",  SPINEL_TYPE_ARRAY, 0, 0),
  M("uniq",      SPINEL_TYPE_ARRAY, 0, 0),
  M("uniq!",     SPINEL_TYPE_ARRAY, 0, 0),
  M("compact",   SPINEL_TYPE_ARRAY, 0, 0),
  M("flatten",   SPINEL_TYPE_ARRAY, 0, 1),
  M("flatten!",  SPINEL_TYPE_ARRAY, 0, 1),
  M("dup",       SPINEL_TYPE_ARRAY, 0, 0),
  M("+",         SPINEL_TYPE_ARRAY, 1, 1),
  M("-",         SPINEL_TYPE_ARRAY, 1, 1),
  M("&",         SPINEL_TYPE_ARRAY, 1, 1),
  M("|",         SPINEL_TYPE_ARRAY, 1, 1),
  M("take",      SPINEL_TYPE_ARRAY, 1, 1),
  M("drop",      SPINEL_TYPE_ARRAY, 1, 1),
  /* Aggregation */
  M("min",  SPINEL_TYPE_INTEGER, 0, 0),
  M("max",  SPINEL_TYPE_INTEGER, 0, 0),
  M("sum",  SPINEL_TYPE_INTEGER, 0, 0),
  M("join", SPINEL_TYPE_STRING,  0, 1),
  /* Block methods */
  MB("each",            SPINEL_TYPE_ARRAY,   0, 0),
  MB("each_with_index", SPINEL_TYPE_ARRAY,   0, 0),
  MB("map",             SPINEL_TYPE_ARRAY,   0, 0),
  MB("map!",            SPINEL_TYPE_ARRAY,   0, 0),
  MB("collect",         SPINEL_TYPE_ARRAY,   0, 0),
  MB("select",          SPINEL_TYPE_ARRAY,   0, 0),
  MB("filter",          SPINEL_TYPE_ARRAY,   0, 0),
  MB("reject",          SPINEL_TYPE_ARRAY,   0, 0),
  MB("find",            SPINEL_TYPE_INTEGER, 0, 0),
  MB("detect",          SPINEL_TYPE_INTEGER, 0, 0),
  MB("any?",            SPINEL_TYPE_BOOLEAN, 0, 0),
  MB("all?",            SPINEL_TYPE_BOOLEAN, 0, 0),
  MB("none?",           SPINEL_TYPE_BOOLEAN, 0, 0),
  MB("count",           SPINEL_TYPE_INTEGER, 0, 0),
  MB("reduce",          SPINEL_TYPE_INTEGER, 0, 1),
  MB("inject",          SPINEL_TYPE_INTEGER, 0, 1),
  MB("sort_by",         SPINEL_TYPE_ARRAY,   0, 0),
  MB("sort_by!",        SPINEL_TYPE_ARRAY,   0, 0),
  MB("min_by",          SPINEL_TYPE_INTEGER, 0, 0),
  MB("max_by",          SPINEL_TYPE_INTEGER, 0, 0),
  MB("filter_map",      SPINEL_TYPE_ARRAY,   0, 0),
  MB("flat_map",        SPINEL_TYPE_ARRAY,   0, 0),
  M("index",      SPINEL_TYPE_INTEGER, 1, 1),
  M("find_index",  SPINEL_TYPE_INTEGER, 1, 1),
  M("zip",         SPINEL_TYPE_RB_ARRAY, 1, 1),
  END
};

/* ------------------------------------------------------------------ */
/* FloatArray methods                                                  */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t float_array_methods[] = {
  M("[]",     SPINEL_TYPE_FLOAT,       1, 1),
  M("[]=",    SPINEL_TYPE_FLOAT,       2, 2),
  M("length", SPINEL_TYPE_INTEGER,     0, 0),
  M("size",   SPINEL_TYPE_INTEGER,     0, 0),
  M("push",   SPINEL_TYPE_FLOAT_ARRAY, 1, 1),
  M("dup",    SPINEL_TYPE_FLOAT_ARRAY, 0, 0),
  M("empty?", SPINEL_TYPE_BOOLEAN,     0, 0),
  END
};

/* ------------------------------------------------------------------ */
/* Hash methods (StrIntHash)                                           */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t hash_methods[] = {
  M("[]",      SPINEL_TYPE_INTEGER, 1, 1),
  M("[]=",     SPINEL_TYPE_INTEGER, 2, 2),
  M("store",   SPINEL_TYPE_INTEGER, 2, 2),
  M("fetch",   SPINEL_TYPE_INTEGER, 1, 2),
  M("delete",  SPINEL_TYPE_INTEGER, 1, 1),
  M("length",  SPINEL_TYPE_INTEGER, 0, 0),
  M("size",    SPINEL_TYPE_INTEGER, 0, 0),
  M("count",   SPINEL_TYPE_INTEGER, 0, 0),
  M("empty?",  SPINEL_TYPE_BOOLEAN, 0, 0),
  M("has_key?", SPINEL_TYPE_BOOLEAN, 1, 1),
  M("key?",     SPINEL_TYPE_BOOLEAN, 1, 1),
  M("include?", SPINEL_TYPE_BOOLEAN, 1, 1),
  M("member?",  SPINEL_TYPE_BOOLEAN, 1, 1),
  M("keys",    SPINEL_TYPE_ARRAY, 0, 0),
  M("values",  SPINEL_TYPE_ARRAY, 0, 0),
  M("merge",   SPINEL_TYPE_HASH,  1, 1),
  M("clear",   SPINEL_TYPE_HASH,  0, 0),
  MB("each",             SPINEL_TYPE_HASH, 0, 0),
  MB("transform_values", SPINEL_TYPE_HASH, 0, 0),
  END
};

/* ------------------------------------------------------------------ */
/* RbHash methods (heterogeneous)                                      */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t rb_hash_methods[] = {
  M("[]",       SPINEL_TYPE_POLY,    1, 1),
  M("[]=",      SPINEL_TYPE_POLY,    2, 2),
  M("fetch",    SPINEL_TYPE_POLY,    1, 2),
  M("length",   SPINEL_TYPE_INTEGER, 0, 0),
  M("size",     SPINEL_TYPE_INTEGER, 0, 0),
  M("count",    SPINEL_TYPE_INTEGER, 0, 0),
  M("empty?",   SPINEL_TYPE_BOOLEAN, 0, 0),
  M("has_key?", SPINEL_TYPE_BOOLEAN, 1, 1),
  M("key?",     SPINEL_TYPE_BOOLEAN, 1, 1),
  M("include?", SPINEL_TYPE_BOOLEAN, 1, 1),
  M("member?",  SPINEL_TYPE_BOOLEAN, 1, 1),
  M("merge",    SPINEL_TYPE_RB_HASH, 1, 1),
  MB("each",             SPINEL_TYPE_RB_HASH, 0, 0),
  MB("transform_values", SPINEL_TYPE_RB_HASH, 0, 0),
  END
};

/* ------------------------------------------------------------------ */
/* Range methods                                                       */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t range_methods[] = {
  M("first",    SPINEL_TYPE_INTEGER, 0, 0),
  M("last",     SPINEL_TYPE_INTEGER, 0, 0),
  M("begin",    SPINEL_TYPE_INTEGER, 0, 0),
  M("end",      SPINEL_TYPE_INTEGER, 0, 0),
  M("min",      SPINEL_TYPE_INTEGER, 0, 0),
  M("max",      SPINEL_TYPE_INTEGER, 0, 0),
  M("size",     SPINEL_TYPE_INTEGER, 0, 0),
  M("count",    SPINEL_TYPE_INTEGER, 0, 0),
  M("include?", SPINEL_TYPE_BOOLEAN, 1, 1),
  M("to_a",     SPINEL_TYPE_ARRAY,   0, 0),
  M("sum",      SPINEL_TYPE_INTEGER, 0, 0),
  MB("each", SPINEL_TYPE_RANGE, 0, 0),
  MB("map",  SPINEL_TYPE_ARRAY, 0, 0),
  END
};

/* ------------------------------------------------------------------ */
/* Time methods                                                        */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t time_methods[] = {
  M("to_i", SPINEL_TYPE_INTEGER, 0, 0),
  M("-",    SPINEL_TYPE_INTEGER, 1, 1),
  END
};

/* ------------------------------------------------------------------ */
/* StringIO methods                                                    */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t stringio_methods[] = {
  M("string",  SPINEL_TYPE_STRING,   0, 0),
  M("read",    SPINEL_TYPE_STRING,   0, 1),
  M("gets",    SPINEL_TYPE_STRING,   0, 0),
  M("getc",    SPINEL_TYPE_STRING,   0, 0),
  M("write",   SPINEL_TYPE_INTEGER,  1, 1),
  M("puts",    SPINEL_TYPE_INTEGER,  0, 1),
  M("print",   SPINEL_TYPE_INTEGER,  1, 1),
  M("putc",    SPINEL_TYPE_INTEGER,  1, 1),
  M("pos",     SPINEL_TYPE_INTEGER,  0, 0),
  M("tell",    SPINEL_TYPE_INTEGER,  0, 0),
  M("size",    SPINEL_TYPE_INTEGER,  0, 0),
  M("length",  SPINEL_TYPE_INTEGER,  0, 0),
  M("lineno",  SPINEL_TYPE_INTEGER,  0, 0),
  M("rewind",  SPINEL_TYPE_INTEGER,  0, 0),
  M("seek",    SPINEL_TYPE_INTEGER,  1, 2),
  M("truncate", SPINEL_TYPE_INTEGER, 1, 1),
  M("close",   SPINEL_TYPE_INTEGER,  0, 0),
  M("getbyte", SPINEL_TYPE_INTEGER,  0, 0),
  M("fileno",  SPINEL_TYPE_INTEGER,  0, 0),
  M("eof?",    SPINEL_TYPE_BOOLEAN,  0, 0),
  M("closed?", SPINEL_TYPE_BOOLEAN,  0, 0),
  M("sync",    SPINEL_TYPE_BOOLEAN,  0, 0),
  M("isatty",  SPINEL_TYPE_BOOLEAN,  0, 0),
  M("tty?",    SPINEL_TYPE_BOOLEAN,  0, 0),
  M("flush",   SPINEL_TYPE_STRINGIO, 0, 0),
  END
};

/* ------------------------------------------------------------------ */
/* StrArray methods                                                    */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t str_array_methods[] = {
  M("[]",      SPINEL_TYPE_STRING,    1, 1),
  M("first",   SPINEL_TYPE_STRING,    0, 0),
  M("last",    SPINEL_TYPE_STRING,    0, 0),
  M("length",  SPINEL_TYPE_INTEGER,   0, 0),
  M("size",    SPINEL_TYPE_INTEGER,   0, 0),
  M("empty?",  SPINEL_TYPE_BOOLEAN,   0, 0),
  M("join",    SPINEL_TYPE_STRING,    0, 1),
  MB("any?",        SPINEL_TYPE_BOOLEAN,   0, 0),
  MB("find",        SPINEL_TYPE_STRING,    0, 0),
  MB("max_by",      SPINEL_TYPE_STRING,    0, 0),
  MB("filter_map",  SPINEL_TYPE_STR_ARRAY, 0, 0),
  MB("count",       SPINEL_TYPE_INTEGER,   0, 0),
  MB("each",        SPINEL_TYPE_STR_ARRAY, 0, 0),
  MB("each_with_index", SPINEL_TYPE_STR_ARRAY, 0, 0),
  END
};

/* ------------------------------------------------------------------ */
/* File class methods                                                  */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t file_methods[] = {
  M("puts",      SPINEL_TYPE_NIL,     1, 1),
  M("write",     SPINEL_TYPE_NIL,     1, 1),
  M("readline",  SPINEL_TYPE_STRING,  0, 0),
  M("read",      SPINEL_TYPE_STRING,  0, 0),
  M("close",     SPINEL_TYPE_NIL,     0, 0),
  M("flock",     SPINEL_TYPE_INTEGER, 1, 1),
  M("seek",      SPINEL_TYPE_INTEGER, 1, 2),
  END
};

/* ------------------------------------------------------------------ */
/* sp_String (mutable) methods                                         */
/* ------------------------------------------------------------------ */
static const builtin_method_def_t sp_string_methods[] = {
  /* Mutation */
  M("<<",      SPINEL_TYPE_SP_STRING, 1, 1),
  M("replace", SPINEL_TYPE_SP_STRING, 1, 1),
  M("clear",   SPINEL_TYPE_SP_STRING, 0, 0),
  M("dup",     SPINEL_TYPE_SP_STRING, 0, 0),
  /* Query */
  M("length",      SPINEL_TYPE_INTEGER, 0, 0),
  M("size",        SPINEL_TYPE_INTEGER, 0, 0),
  M("bytesize",    SPINEL_TYPE_INTEGER, 0, 0),
  M("empty?",      SPINEL_TYPE_BOOLEAN, 0, 0),
  M("include?",    SPINEL_TYPE_BOOLEAN, 1, 1),
  M("start_with?", SPINEL_TYPE_BOOLEAN, 1, -1),
  M("end_with?",   SPINEL_TYPE_BOOLEAN, 1, -1),
  M("match?",      SPINEL_TYPE_BOOLEAN, 1, 1),
  M("ascii_only?", SPINEL_TYPE_BOOLEAN, 0, 0),
  M("frozen?",     SPINEL_TYPE_BOOLEAN, 0, 0),
  M("count",       SPINEL_TYPE_INTEGER, 1, 1),
  M("index",       SPINEL_TYPE_INTEGER, 1, 2),
  M("rindex",      SPINEL_TYPE_INTEGER, 1, 2),
  M("ord",         SPINEL_TYPE_INTEGER, 0, 0),
  M("getbyte",     SPINEL_TYPE_INTEGER, 1, 1),
  M("setbyte",     SPINEL_TYPE_INTEGER, 2, 2),
  /* Access */
  M("[]",    SPINEL_TYPE_STRING, 1, 2),
  M("slice", SPINEL_TYPE_STRING, 1, 2),
  /* Transform (delegated to cstr → immutable) */
  M("+",          SPINEL_TYPE_STRING, 1, 1),
  M("to_s",       SPINEL_TYPE_STRING, 0, 0),
  M("upcase",     SPINEL_TYPE_STRING, 0, 0),
  M("downcase",   SPINEL_TYPE_STRING, 0, 0),
  M("capitalize", SPINEL_TYPE_STRING, 0, 0),
  M("swapcase",   SPINEL_TYPE_STRING, 0, 0),
  M("reverse",    SPINEL_TYPE_STRING, 0, 0),
  M("strip",      SPINEL_TYPE_STRING, 0, 0),
  M("lstrip",     SPINEL_TYPE_STRING, 0, 0),
  M("rstrip",     SPINEL_TYPE_STRING, 0, 0),
  M("chomp",      SPINEL_TYPE_STRING, 0, 1),
  M("chop",       SPINEL_TYPE_STRING, 0, 0),
  M("gsub",       SPINEL_TYPE_STRING, 2, 2),
  M("sub",        SPINEL_TYPE_STRING, 2, 2),
  M("tr",         SPINEL_TYPE_STRING, 2, 2),
  M("delete",     SPINEL_TYPE_STRING, 1, -1),
  M("squeeze",    SPINEL_TYPE_STRING, 0, 1),
  M("ljust",      SPINEL_TYPE_STRING, 1, 2),
  M("rjust",      SPINEL_TYPE_STRING, 1, 2),
  M("center",     SPINEL_TYPE_STRING, 1, 2),
  M("concat",     SPINEL_TYPE_STRING, 1, -1),
  M("encode",     SPINEL_TYPE_STRING, 0, 2),
  M("b",          SPINEL_TYPE_STRING, 0, 0),
  M("intern",     SPINEL_TYPE_STRING, 0, 0),
  M("to_sym",     SPINEL_TYPE_STRING, 0, 0),
  M("freeze",     SPINEL_TYPE_STRING, 0, 0),
  /* Conversion */
  M("to_i",   SPINEL_TYPE_INTEGER,   0, 1),
  M("to_f",   SPINEL_TYPE_FLOAT,     0, 0),
  M("hex",    SPINEL_TYPE_INTEGER,   0, 0),
  M("oct",    SPINEL_TYPE_INTEGER,   0, 0),
  /* Split */
  M("split",      SPINEL_TYPE_STR_ARRAY, 0, 2),
  M("chars",      SPINEL_TYPE_STR_ARRAY, 0, 0),
  M("bytes",      SPINEL_TYPE_ARRAY,     0, 0),
  M("each_line",  SPINEL_TYPE_STR_ARRAY, 0, 1),
  END
};

#undef M
#undef MB
#undef END

/* ------------------------------------------------------------------ */
/* Lookup functions                                                    */
/* ------------------------------------------------------------------ */

static const builtin_method_def_t *find_in_table(const builtin_method_def_t *table,
                                                  const char *name) {
  for (const builtin_method_def_t *m = table; m->name; m++)
    if (strcmp(m->name, name) == 0) return m;
  return NULL;
}

static const builtin_method_def_t *table_for_type(spinel_type_t kind) {
  switch (kind) {
  case SPINEL_TYPE_INTEGER:    return integer_methods;
  case SPINEL_TYPE_FLOAT:      return float_methods;
  case SPINEL_TYPE_STRING:     return string_methods;
  case SPINEL_TYPE_ARRAY:      return array_methods;
  case SPINEL_TYPE_FLOAT_ARRAY: return float_array_methods;
  case SPINEL_TYPE_HASH:       return hash_methods;
  case SPINEL_TYPE_RB_HASH:    return rb_hash_methods;
  case SPINEL_TYPE_RANGE:      return range_methods;
  case SPINEL_TYPE_TIME:       return time_methods;
  case SPINEL_TYPE_STRINGIO:   return stringio_methods;
  case SPINEL_TYPE_STR_ARRAY:  return str_array_methods;
  case SPINEL_TYPE_FILE:       return file_methods;
  case SPINEL_TYPE_SP_STRING:  return sp_string_methods;
  default: return NULL;
  }
}

const builtin_method_def_t *builtin_find_method(spinel_type_t kind, const char *name) {
  /* Check type-specific table first */
  const builtin_method_def_t *table = table_for_type(kind);
  if (table) {
    const builtin_method_def_t *m = find_in_table(table, name);
    if (m) return m;
  }
  /* Fall back to universal methods */
  return find_in_table(universal_methods, name);
}

bool builtin_has_method(spinel_type_t kind, const char *name) {
  return builtin_find_method(kind, name) != NULL;
}

spinel_type_t builtin_return_type(spinel_type_t recv_kind, const char *name) {
  const builtin_method_def_t *m = builtin_find_method(recv_kind, name);
  if (m) return m->return_type;
  return SPINEL_TYPE_UNKNOWN;
}
