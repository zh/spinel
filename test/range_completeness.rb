# Range completeness — cover?, min, max, count for numeric ranges.
# Bundle of four sibling Range methods.

# cover? mirrors include? for numeric ranges
puts (1..10).cover?(5)
puts (1..10).cover?(1)
puts (1..10).cover?(10)
puts (1..10).cover?(0)
puts (1..10).cover?(11)
puts (-5..5).cover?(0)
puts (-5..5).cover?(-5)
puts (-5..5).cover?(6)

# min / max via struct fields
puts (1..10).min
puts (1..10).max
puts (-5..5).min
puts (-5..5).max
puts (100..200).min
puts (100..200).max

# count over inclusive ranges = last - first + 1
puts (1..10).count
puts (1..1).count
puts (-5..5).count
puts (100..200).count

# count over exclusive literal range = last - first
puts (1...10).count
puts (1...1).count
puts (-5...5).count
