# Benchmark: method inlining effect
# Small methods called in tight loops

class Vec2
  attr_reader :x, :y
  def initialize(x, y)
    @x = x
    @y = y
  end
  def length_sq
    @x * @x + @y * @y
  end
  def dot(other)
    @x * other.x + @y * other.y
  end
end

# Use enough ivars to force pointer type (avoid value type pass-by-copy issue)
class Counter
  attr_reader :value, :step, :name, :flag
  def initialize
    @value = 0
    @step = 1
    @name = "counter"
    @flag = 0
  end
  def increment
    @value = @value + @step
  end
  def double_value
    @value * 2
  end
end

n = 10000000

# Benchmark 1: length_sq in loop (single-expression method, no args)
sum = 0
v = Vec2.new(3, 4)
i = 0
while i < n
  sum = sum + v.length_sq
  i = i + 1
end
puts sum  # 25 * 10000000 = 250000000

# Benchmark 2: dot product (single-expression, one arg)
sum2 = 0
v1 = Vec2.new(1, 2)
v2 = Vec2.new(3, 4)
i = 0
while i < n
  sum2 = sum2 + v1.dot(v2)
  i = i + 1
end
puts sum2  # 11 * 10000000 = 110000000

# Benchmark 3: counter increment + getter
c = Counter.new
i = 0
while i < n
  c.increment
  i = i + 1
end
puts c.value        # 10000000
puts c.double_value # 20000000

puts "done"
