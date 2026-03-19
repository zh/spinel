# Test arithmetic on polymorphic values

def calc(a, b)
  a + b
end

puts calc(10, 20)         # 30
puts calc(1.5, 2.5)       # 4.0
puts calc("hello", " world")  # hello world

# Mixed numeric
def double(x)
  x * 2
end

puts double(5)     # 10
puts double(3.14)  # 6.28

# Comparison
def bigger?(a, b)
  a > b
end

puts bigger?(10, 5)     # true
puts bigger?(1.0, 2.0)  # false

# to_s on poly
def show(x)
  puts x.to_s
end
show(42)
show("hi")

puts "done"
