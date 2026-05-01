# Multi-arg numbered block params (`_1`, `_2`, ...) should destructure
# the yielded sub-array. Pre-fix: `_1` binds to the whole element
# (the sp_IntArray pointer) and `_2` is uninitialized -> "<ptr>=0".
# CRuby ref: arity-N blocks over a single Array argument auto-destructure.

# Plain int-tuple sub-arrays - max=2 destructure
[[1, 10], [2, 20], [3, 30]].each { puts "#{_1}=#{_2}" }

# Three-element sub-arrays exercise _3
[[1, 2, 3], [10, 20, 30]].each { puts "#{_1}-#{_2}-#{_3}" }

# Sum of paired elements via destructured slots in `.each`
total = 0
[[1, 100], [2, 200], [3, 300]].each { total = total + _1 + _2 }
puts total

# Two-stage: outer each with _1+_2, inner reuse outside the block
running = 0
[[10, 1], [20, 2], [30, 3]].each { running = running + _1 - _2 }
puts running

# Short sub-array regression — pre-fix the destructure read past the
# sub-array's data buffer (OOB) when the yielded element was shorter
# than the block's max numbered param. The fix bounds-checks each slot
# read and pads with 0 (typed-nil analogue). This test computes the
# sum of `_1 + _2` only when `_2` is not nil (so CRuby gets the same
# numbers as Spinel — Spinel's typed-zero already passes the .nil?
# false branch). `_2` is mentioned in the block so destruct_n >= 2.
short_total = 0
[[1], [2, 20], [3, 30]].each { short_total = short_total + _1 + (_2.nil? ? 0 : _2) }
puts short_total
