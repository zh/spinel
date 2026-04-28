# A class with no attr_writers / no mutating methods is normally
# compiled as a value type — `sp_Foo_new(x)` returns the struct by
# value. But when its instances are stored in an array literal, the
# inferred container is `obj_Foo_ptr_array` (`sp_PtrArray *`), whose
# `_push` takes `void *`. The push call ended up emitting
# `sp_PtrArray_push(arr, sp_Foo_new(1))`, which doesn't compile.

class Foo
  def initialize(x); @x = x; end
  attr_reader :x
end

arr = [Foo.new(1), Foo.new(2), Foo.new(3)]
puts arr.length
arr.each {|f| puts f.x }
