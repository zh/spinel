# Spinel AOT Compiler - Makefile
#
# Usage:
#   make deps      # Fetch and build dependencies (prism)
#   make           # Build the spinel compiler
#   make test      # Compile examples/bm_so_mandelbrot.rb and verify output

# Configuration
PRISM_VERSION ?= 1.4.0
MRUBY_DIR     ?= $(HOME)/work/mruby
CC            ?= cc
CFLAGS        = -Wall -Wextra -O2 -std=c99
CFLAGS       += -Ilib/prism/include -Isrc

# Prism library
PRISM_DIR     = lib/prism
PRISM_LIB     = $(PRISM_DIR)/build/libprism.a
PRISM_CFLAGS  = -I$(PRISM_DIR)/include
PRISM_LDFLAGS = -L$(PRISM_DIR)/build -lprism

# Sources
SRCS = src/main.c src/codegen.c
OBJS = $(SRCS:.c=.o)

# Default target
all: spinel

spinel: $(OBJS) $(PRISM_LIB)
	$(CC) $(OBJS) $(PRISM_LIB) -o $@

src/%.o: src/%.c $(PRISM_LIB)
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

# Test: compile examples/bm_so_mandelbrot.rb and verify output
test: spinel
	@echo "=== Compiling examples/bm_so_mandelbrot.rb ==="
	./spinel --source=examples/bm_so_mandelbrot.rb --output=mandelbrot_aot.c
	@echo "=== Compiling generated C code ==="
	$(CC) -O2 -ffunction-sections -Wl,--gc-sections \
		mandelbrot_aot.c \
		$$($(MRUBY_DIR)/build/host/bin/mruby-config --cflags) \
		$$($(MRUBY_DIR)/build/host/bin/mruby-config --ldflags --libs) \
		-o mandelbrot
	@echo "=== Running AOT binary ==="
	./mandelbrot > mandelbrot_aot.pbm
	@echo "=== Running CRuby reference ==="
	ruby examples/bm_so_mandelbrot.rb > mandelbrot_ruby.pbm
	@echo "=== Comparing output ==="
	@if diff mandelbrot_aot.pbm mandelbrot_ruby.pbm > /dev/null 2>&1; then \
		echo "SUCCESS: Output matches!"; \
	else \
		echo "FAIL: Output differs"; \
		exit 1; \
	fi

# Generate C code only (no mruby compilation)
gen: spinel
	./spinel --source=examples/bm_so_mandelbrot.rb --output=mandelbrot_aot.c
	@echo "Generated mandelbrot_aot.c"

clean:
	rm -f $(OBJS) spinel
	rm -f mandelbrot_aot.c mandelbrot
	rm -f mandelbrot_aot.pbm mandelbrot_ruby.pbm

distclean: clean
	rm -rf lib/prism

.PHONY: all deps test gen clean distclean
