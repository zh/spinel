class Point < Struct.new(:x, :y, keyword_init: true)
  def distance
    (x * x + y * y)
  end

  def to_s
    "(#{x}, #{y})"
  end
end

p1 = Point.new(x: 3, y: 4)
puts p1.x         # 3
puts p1.y         # 4
puts p1.distance  # 25
p1.x = 10
puts p1.x         # 10

class Entry < Struct.new(:name, :value, keyword_init: true)
  def display
    "#{name}=#{value}"
  end
end

e = Entry.new(name: "foo", value: 42)
puts e.name    # foo
puts e.value   # 42

puts "done"
