# Test attr_accessor, attr_reader, attr_writer, class methods, for..in, loop

class Point
  attr_accessor :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def self.origin
    Point.new(0, 0)
  end

  def distance_to(other)
    dx = @x - other.x
    dy = @y - other.y
    Math.sqrt(dx * dx + dy * dy)
  end

  def to_s
    "(" + @x.to_s + ", " + @y.to_s + ")"
  end
end

p1 = Point.new(3, 4)
puts p1.x        # 3
puts p1.y        # 4
p1.x = 10
puts p1.x        # 10

p2 = Point.origin
puts p2.x        # 0

# for..in with range
total = 0
for i in 1..10
  total += i
end
puts total        # 55

# loop with break
count = 0
loop do
  count += 1
  break if count >= 5
end
puts count        # 5

# Array#each with index (using each)
arr = (1..5).to_a
sum = 0
arr.each do |x|
  sum += x
end
puts sum          # 15

# String#to_s on object
puts p1.to_s      # (10, 4)

# attr_accessor path should keep ivar/local namespaces distinct.
class IvarCollision
  attr_accessor :x, :iv_x

  def initialize
    @x = 1
    @iv_x = 2
  end

  def sum
    x = 10
    iv_x = 20
    @x + @iv_x + self.x + self.iv_x + x + iv_x
  end
end

puts IvarCollision.new.sum   # 36
