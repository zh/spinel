# Issue #61 stage 4: a regex literal stored in a local variable must
# dispatch through the engine just like a constant. Before this stage,
# `find_regexp_index` only resolved direct literals and constants, so
# `re = /pat/; re.match?(s)` and `s =~ re` fell through to the `0` /
# `(-1)` fallbacks.

re = /[₀₁₂₃₄₅₆₇₈₉]+/
puts re.match?("₁₂")
puts re.match?("abc")

# `=~` with the local on the right.
if "abc₁def" =~ re
  puts "lhs match"
else
  puts "lhs miss"
end

# `=~` with the local on the left.
if re =~ "abc₁def"
  puts "rhs match"
else
  puts "rhs miss"
end

# Inside a method body — fresh scope, fresh local.
def find(s)
  rx = /[a-z]+/
  rx.match?(s)
end
puts find("hello")
puts find("123")

# Multi-write disqualifies dispatch (the second write is non-regex,
# so the local can't be statically resolved). The fall-through still
# compiles cleanly; we just verify the program runs.
re2 = /a/
re2 = "not a regex"
puts re2
