/*
 * main.c - Spinel AOT compiler entry point
 *
 * Usage: spinel --source=app.rb --output=app_aot.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <prism.h>
#include "codegen.h"

static void usage(const char *prog) {
    fprintf(stderr, "Usage: %s --source=FILE --output=FILE\n", prog);
    fprintf(stderr, "\nOptions:\n");
    fprintf(stderr, "  --source=FILE   Ruby source file to compile\n");
    fprintf(stderr, "  --output=FILE   Output C file (default: stdout)\n");
}

static char *read_file(const char *path, size_t *length) {
    FILE *f = fopen(path, "rb");
    if (!f) {
        fprintf(stderr, "Error: cannot open '%s'\n", path);
        return NULL;
    }
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);

    char *buf = malloc(len + 1);
    if (!buf) {
        fclose(f);
        return NULL;
    }
    fread(buf, 1, len, f);
    buf[len] = '\0';
    fclose(f);

    if (length) *length = (size_t)len;
    return buf;
}

int main(int argc, char **argv) {
    const char *source_path = NULL;
    const char *output_path = NULL;

    for (int i = 1; i < argc; i++) {
        if (strncmp(argv[i], "--source=", 9) == 0) {
            source_path = argv[i] + 9;
        } else if (strncmp(argv[i], "--output=", 9) == 0) {
            output_path = argv[i] + 9;
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage(argv[0]);
            return 0;
        } else {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            usage(argv[0]);
            return 1;
        }
    }

    if (!source_path) {
        fprintf(stderr, "Error: --source is required\n");
        usage(argv[0]);
        return 1;
    }

    /* Read source file */
    size_t source_len;
    char *source = read_file(source_path, &source_len);
    if (!source) return 1;

    /* Parse with Prism */
    pm_parser_t parser;
    pm_parser_init(&parser, (const uint8_t *)source, source_len, NULL);
    pm_node_t *root = pm_parse(&parser);

    /* Check for parse errors */
    if (parser.error_list.size > 0) {
        fprintf(stderr, "Parse errors in '%s':\n", source_path);
        pm_diagnostic_t *diag;
        for (diag = (pm_diagnostic_t *)parser.error_list.head;
             diag != NULL;
             diag = (pm_diagnostic_t *)diag->node.next) {
            ptrdiff_t offset = diag->location.start - parser.start;
            fprintf(stderr, "  offset %td: %s\n", offset, diag->message);
        }
        pm_node_destroy(&parser, root);
        pm_parser_free(&parser);
        free(source);
        return 1;
    }

    /* Open output file */
    FILE *out = stdout;
    if (output_path) {
        out = fopen(output_path, "w");
        if (!out) {
            fprintf(stderr, "Error: cannot open '%s' for writing\n", output_path);
            pm_node_destroy(&parser, root);
            pm_parser_free(&parser);
            free(source);
            return 1;
        }
    }

    /* Generate C code */
    codegen_ctx_t *ctx = (codegen_ctx_t *)calloc(1, sizeof(codegen_ctx_t));
    codegen_init(ctx, &parser, out);
    codegen_program(ctx, root);
    free(ctx);

    /* Cleanup */
    if (out != stdout) fclose(out);
    pm_node_destroy(&parser, root);
    pm_parser_free(&parser);
    free(source);

    if (output_path)
        fprintf(stderr, "Wrote %s\n", output_path);

    return 0;
}
