# Splat operator at the call site.
# Covers pure splat, splat into a method with required + rest params,
# and mixed prefix/splat/suffix into a rest-collecting method.

def collect(*nums)
  total = 0
  nums.each { |n| total += n }
  puts nums.length
  puts total
end

# Pure splat into rest-only method
args = [1, 2, 3]
collect(*args)        # length 3, total 6

# Empty splat
empty = []
collect(*empty)       # length 0, total 0

# Splat with a method that has fixed prefix + rest
def mix(a, b, *rest)
  puts a
  puts b
  puts rest.length
  rest.each { |x| puts x }
end

# Pure splat fills both fixed slots and the rest
quad = [10, 20, 30, 40]
mix(*quad)            # a=10, b=20, rest=[30,40]

# Prefix + splat fills the rest
tail = [3, 4, 5]
mix(1, 2, *tail)      # a=1, b=2, rest=[3,4,5]

# Prefix + splat + suffix all bundle into rest
mid = [3, 4]
mix(1, 2, *mid, 5, 6) # a=1, b=2, rest=[3,4,5,6]

# Bare call leaves rest empty (regression check for the empty-rest fix)
mix(100, 200)         # a=100, b=200, rest=[]

# Prefix overflows into rest when method has *only* a rest param
collect(7, *args)     # length 4, total 13
collect(7, 8, *args, 9) # length 6, total 36

# Mixed-type splat sources: poly_array source, mixed prefix/suffix.
# Spinel's *rest is always int_array so element values are mrb_int bits
# for non-int elements — but the length is correct and the bundle
# round-trips intact for downstream splatting.
def count(*xs)
  puts xs.length
end
count(1, "x", 2.0)            # 3
mix = [1, "two", :three, 4.0]
count(*mix)                   # 4
count(0, *mix, "tail", 99.5)  # 7

# Two splats in one call (multi-splat fallback path).
left = [1, 2]
right = [3, 4, 5]
count(*left, *right)          # 5

# Splat into a method with str fixed prefix + rest — exercises the
# splat-aware param-type inference (without it, "first" would default to
# mrb_int and we'd print garbage instead of "alpha").
def head_str(first, *tail)
  puts first
  puts tail.length
end
strs = ["alpha", "beta", "gamma"]
head_str(*strs)               # alpha / 2
