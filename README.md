# Spinel — AOT Compiler for Ruby

Spinel compiles Ruby source code to C via [Prism](https://github.com/ruby/prism)
parsing and type inference, then links against [mruby](https://github.com/mruby/mruby)
for the runtime. For proven types (Integer, Float, Boolean), it generates direct
C operations with no dynamic dispatch.

## Quick Start

```bash
# 1. Fetch and build the Prism parser library
make deps

# 2. Build the spinel compiler
make

# 3. Compile a Ruby program to C
./spinel --source=app.rb --output=app_aot.c

# 4. Build the final binary (adjust mruby path as needed)
cc -O2 app_aot.c \
  $(~/work/mruby/build/host/bin/mruby-config --cflags) \
  $(~/work/mruby/build/host/bin/mruby-config --ldflags --libs) \
  -o app
```

## Benchmark

First target: `bm_so_mandelbrot.rb` (Mandelbrot set, 600x600 PBM output).

```bash
make test   # compile, run, and verify output matches CRuby
```

| Runtime | Time | Speedup |
|---------|------|---------|
| CRuby 3.2 | 1.14s | 1x |
| mruby interpreter | 3.18s | 0.36x |
| **Spinel AOT** | **0.06s** | **19x** |

Output is bit-identical to CRuby.

## How It Works

```
Ruby Source
    |
    v
Prism (libprism)          -- parse to AST
    |
    v
Type Inference (Pass 1)   -- infer Integer/Float/Boolean/String per variable
    |
    v
C Code Generation (Pass 2)
    |  - Proven numeric types -> direct C arithmetic
    |  - String operations -> mruby API calls
    |  - I/O (puts/print) -> stdio or mruby
    v
Generated C file
    |
    v
cc + libmruby -> executable
```

For `bm_so_mandelbrot.rb`, the inner loop compiles to pure C float/int
arithmetic with zero mruby dispatch. Only the PBM header string interpolation
uses the mruby runtime.

## Supported Language Features

Currently handles the subset needed for mandelbrot:

- Local variables (assignment, read, operator-assignment like `+=`, `<<=`)
- `while` loops, `for..in` with Range
- `if` / `elsif` / `else`, ternary operator
- Integer, Float, Boolean, String, nil literals
- Binary integer literals (`0b0`, `0b1`)
- Arithmetic (`+`, `-`, `*`, `/`, `%`)
- Comparison (`>`, `<`, `>=`, `<=`, `==`, `!=`)
- Bitwise (`<<`, `>>`, `|`, `&`, `^`)
- String interpolation (`"hello #{name}"`)
- `puts`, `print`
- `Integer#chr`
- `break`
- Parallel assignment (`a, b = c, d`)

## Project Structure

```
spinel/
├── src/
│   ├── main.c        # CLI, file reading, Prism parsing
│   ├── codegen.h     # Type definitions, codegen API
│   └── codegen.c     # Type inference + C code generation
├── prototype/
│   └── tools/        # Step 0 prototype (RBS extraction, LumiTrace, etc.)
├── bm_so_mandelbrot.rb   # First compilation target
├── Makefile
├── PLAN.md               # Implementation roadmap
└── ruby_aot_compiler_design.md  # Detailed design document
```

## Dependencies

- **Build time**: [Prism](https://github.com/ruby/prism) (fetched automatically by `make deps`)
- **Link time**: [mruby](https://github.com/mruby/mruby) (set `MRUBY_DIR` if not at `~/work/mruby`)

## License

Spinel is released under the [MIT License](LICENSE).

### Note on License

mruby has chosen a MIT License due to its permissive license allowing
developers to target various environments such as embedded systems.
However, the license requires the display of the copyright notice and license
information in manuals for instance. Doing so for big projects can be
complicated or troublesome. This is why mruby has decided to display "mruby
developers" as the copyright name to make it simple conventionally.
In the future, mruby might ask you to distribute your new code
(that you will commit,) under the MIT License as a member of
"mruby developers" but contributors will keep their copyright.
(We did not intend for contributors to transfer or waive their copyrights,
actual copyright holder name (contributors) will be listed in the [AUTHORS](AUTHORS)
file.)

Please ask us if you want to distribute your code under another license.
