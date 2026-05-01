# Symbol#upcase and Symbol#downcase return symbols by upper/lower-casing
# the symbol's name string and re-interning. Mirrors the existing
# String#upcase / #downcase plumbing — the only delta is `sp_sym_to_s`
# in front of the case helper and `sp_sym_intern` wrapping the result.

# Symbol#upcase
puts :hello.upcase
puts :HELLO.upcase
puts :MixedCase.upcase
puts :a.upcase
puts :_.upcase

# Symbol#downcase
puts :HELLO.downcase
puts :hello.downcase
puts :MixedCase.downcase
puts :Z.downcase

# Round trip — sym -> upper -> lower returns to original lower form
puts :foo.upcase.downcase
puts :BAR.downcase.upcase

# Re-intern stability — equal pre/post-case symbols stay equal
puts :Hello.upcase == :HELLO
puts :Hello.downcase == :hello
puts :a.upcase != :A.downcase
