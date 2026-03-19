# Test megamorphic dispatch (3+ types)

class Dog
  def speak; "Woof!"; end
  def name; "Dog"; end
end

class Cat
  def speak; "Meow!"; end
  def name; "Cat"; end
end

class Bird
  def speak; "Tweet!"; end
  def name; "Bird"; end
end

def make_noise(animal)
  puts animal.speak
end

make_noise(Dog.new)   # Woof!
make_noise(Cat.new)   # Meow!
make_noise(Bird.new)  # Tweet!

# Also test with name method
def identify(animal)
  puts animal.name
end

identify(Dog.new)   # Dog
identify(Cat.new)   # Cat
identify(Bird.new)  # Bird

puts "done"
