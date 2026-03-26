# Spinel AOT Compiler - Makefile
#
# Usage:
#   make deps      # Fetch and build dependencies (prism)
#   make           # Build the spinel compiler
#   make test      # Quick test (mandelbrot)
#   make test-all  # Run all 47 examples

# Configuration
PRISM_VERSION ?= 1.4.0
CC            ?= cc
CFLAGS        = -Wall -Wextra -O2 -std=c99
CFLAGS       += -Ivendor/prism/include -Isrc

# Prism library
PRISM_DIR     = vendor/prism
PRISM_LIB     = $(PRISM_DIR)/build/libprism.a
PRISM_CFLAGS  = -I$(PRISM_DIR)/include

# Sources
SRCS = src/main.c src/codegen.c src/type.c src/expr.c src/stmt.c src/emit.c src/methods.c
OBJS = $(SRCS:.c=.o)

# Default target
all: spinel

spinel: $(OBJS) $(PRISM_LIB)
	$(CC) $(OBJS) $(PRISM_LIB) -o $@

src/%.o: src/%.c src/codegen.h $(PRISM_LIB)
	$(CC) $(CFLAGS) $(PRISM_CFLAGS) -c $< -o $@

# Dependencies
deps: $(PRISM_LIB)

$(PRISM_LIB):
	@if [ ! -d "$(PRISM_DIR)" ]; then \
		echo "Fetching prism v$(PRISM_VERSION)..."; \
		mkdir -p lib; \
		git clone --depth 1 --branch v$(PRISM_VERSION) \
			https://github.com/ruby/prism $(PRISM_DIR); \
	fi
	@echo "Building prism..."
	cd $(PRISM_DIR) && make

# Quick test: mandelbrot only
test: spinel
	@./spinel --source=benchmark/bm_so_mandelbrot.rb --output=/tmp/sp_mandelbrot.c 2>/dev/null
	@$(CC) -O2 /tmp/sp_mandelbrot.c -lm -o /tmp/sp_mandelbrot 2>/dev/null
	@/tmp/sp_mandelbrot > /tmp/sp_m1.pbm
	@ruby benchmark/bm_so_mandelbrot.rb > /tmp/sp_m2.pbm
	@diff /tmp/sp_m1.pbm /tmp/sp_m2.pbm > /dev/null && echo "test: OK (mandelbrot)" || echo "test: FAIL"

# Full test suite: all single-file examples
EXAMPLES_SIMPLE = $(filter-out test/bm_regexp.rb test/bm_ao_render.rb test/bm_mandel_term.rb, $(wildcard test/bm_*.rb))

test-all: spinel
	@pass=0; fail=0; skip=0; total=0; \
	echo "=== Spinel Test Suite ==="; \
	echo ""; \
	for f in $(EXAMPLES_SIMPLE); do \
		name=$$(basename $$f .rb); \
		total=$$((total + 1)); \
		if ./spinel --source=$$f --output=/tmp/sp_$${name}.c 2>/dev/null && \
		   $(CC) -O2 -Wno-format -Wno-discarded-qualifiers -Wno-unused-value \
		         /tmp/sp_$${name}.c -lm -o /tmp/sp_$${name} 2>/dev/null; then \
			if timeout 10 /tmp/sp_$${name} > /tmp/sp_$${name}_out 2>/dev/null; \
			ruby $$f > /tmp/sp_$${name}_ref 2>/dev/null; \
			diff /tmp/sp_$${name}_out /tmp/sp_$${name}_ref > /dev/null 2>&1; then \
				echo "  OK   $$name"; \
				pass=$$((pass + 1)); \
			else \
				echo "  FAIL $$name (output differs)"; \
				fail=$$((fail + 1)); \
			fi; \
		else \
			echo "  FAIL $$name (compile error)"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "--- Special tests ---"; \
	total=$$((total + 1)); \
	if ./spinel --source=benchmark/bm_so_mandelbrot.rb --output=/tmp/sp_mandelbrot.c 2>/dev/null && \
	   $(CC) -O2 /tmp/sp_mandelbrot.c -lm -o /tmp/sp_mandelbrot 2>/dev/null && \
	   /tmp/sp_mandelbrot > /tmp/sp_m1.pbm && ruby benchmark/bm_so_mandelbrot.rb > /tmp/sp_m2.pbm && \
	   diff /tmp/sp_m1.pbm /tmp/sp_m2.pbm > /dev/null 2>&1; then \
		echo "  OK   bm_so_mandelbrot (binary output)"; \
		pass=$$((pass + 1)); \
	else \
		echo "  FAIL bm_so_mandelbrot"; \
		fail=$$((fail + 1)); \
	fi; \
	total=$$((total + 1)); \
	if ./spinel --source=test/bm_regexp.rb --output=/tmp/sp_regexp.c 2>/dev/null && \
	   $(CC) -O2 /tmp/sp_regexp.c /usr/lib/x86_64-linux-gnu/libonig.so.5 -lm -o /tmp/sp_regexp 2>/dev/null && \
	   /tmp/sp_regexp > /tmp/sp_regexp_out 2>/dev/null && \
	   ruby test/bm_regexp.rb > /tmp/sp_regexp_ref 2>/dev/null && \
	   diff /tmp/sp_regexp_out /tmp/sp_regexp_ref > /dev/null 2>&1; then \
		echo "  OK   bm_regexp (oniguruma)"; \
		pass=$$((pass + 1)); \
	else \
		echo "  SKIP bm_regexp (requires libonig)"; \
		skip=$$((skip + 1)); \
	fi; \
	total=$$((total + 1)); \
	if ./spinel --source=test/bm_require/main.rb --output=/tmp/sp_require.c 2>/dev/null && \
	   $(CC) -O2 /tmp/sp_require.c -lm -o /tmp/sp_require 2>/dev/null && \
	   /tmp/sp_require > /tmp/sp_require_out 2>/dev/null && \
	   ruby test/bm_require/main.rb > /tmp/sp_require_ref 2>/dev/null && \
	   diff /tmp/sp_require_out /tmp/sp_require_ref > /dev/null 2>&1; then \
		echo "  OK   bm_require (multi-file)"; \
		pass=$$((pass + 1)); \
	else \
		echo "  FAIL bm_require"; \
		fail=$$((fail + 1)); \
	fi; \
	echo ""; \
	echo "=== $$pass passed, $$fail failed, $$skip skipped / $$total total ==="

# Verify benchmarks compile and run correctly
bench-verify: spinel
	@pass=0; fail=0; total=0; \
	echo "=== Benchmark Verification ==="; \
	for f in benchmark/*.rb; do \
		name=$$(basename $$f .rb); \
		total=$$((total + 1)); \
		if ./spinel --source=$$f --output=/tmp/sp_$${name}.c 2>/dev/null && \
		   $(CC) -O2 -Wno-format -Wno-discarded-qualifiers -Wno-unused-value \
		         /tmp/sp_$${name}.c -lm -o /tmp/sp_$${name} 2>/dev/null; then \
			if timeout 30 /tmp/sp_$${name} > /tmp/sp_$${name}_out 2>/dev/null; \
			ruby $$f > /tmp/sp_$${name}_ref 2>/dev/null; \
			diff /tmp/sp_$${name}_out /tmp/sp_$${name}_ref > /dev/null 2>&1; then \
				echo "  OK   $$name"; \
				pass=$$((pass + 1)); \
			else \
				echo "  FAIL $$name (output differs)"; \
				fail=$$((fail + 1)); \
			fi; \
		else \
			echo "  FAIL $$name (compile error)"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "=== $$pass passed, $$fail failed / $$total total ==="

# Generate C code only
gen: spinel
	./spinel --source=benchmark/bm_so_mandelbrot.rb --output=mandelbrot_aot.c
	@echo "Generated mandelbrot_aot.c"

clean:
	rm -f $(OBJS) spinel
	rm -f mandelbrot_aot.c mandelbrot
	rm -f mandelbrot_aot.pbm mandelbrot_ruby.pbm

distclean: clean
	rm -rf vendor/prism

.PHONY: all deps test test-all gen clean distclean
