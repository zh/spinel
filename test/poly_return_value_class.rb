# Issue #118: a method that returns instances of two or more value-
# type-eligible classes per branch used to crash the C compile. Both
# A and B detected as value-type (no attr_writer / no mutator) →
# `sp_A_new(...)` / `sp_B_new(...)` returned the struct by value →
# `sp_box_obj(struct, ci)` tried to put a struct into `sp_RbVal.v.p`
# (`void *`), and the unboxing dispatch passed `void *` to a method
# taking its receiver by value.
#
# Fix: detect_poly_returned_types collects every class constructed
# inside a poly-returning method and excludes those classes from the
# value-type optimization, so they stay heap-allocated and the
# existing poly-return / sp_RbVal plumbing handles them as pointers.

class A
  def initialize(v); @v = v; end
  def label; "A:" + @v; end
end

class B
  def initialize(v); @v = v; end
  def label; "B:" + @v; end
end

def pick(flag)
  if flag
    A.new("yes")
  else
    B.new("no")
  end
end

puts pick(true).label    # A:yes
puts pick(false).label   # B:no

# A `case`/`when` poly return — same shape, different control flow.
def by_kind(k)
  case k
  when 0 then A.new("zero")
  when 1 then B.new("one")
  else        A.new("many")
  end
end

puts by_kind(0).label    # A:zero
puts by_kind(1).label    # B:one
puts by_kind(9).label    # A:many

# Method invocation that returns a different type per class — the
# poly receiver dispatches through the cls_id table generated for
# explicit `def`-defined methods on each class.
class P
  def initialize(n); @n = n; end
  def double; @n * 2; end
end

class Q
  def initialize(n); @n = n; end
  def double; @n + 100; end
end

def numeric(flag)
  flag ? P.new(7) : Q.new(7)
end

puts numeric(true).double    # 14
puts numeric(false).double   # 107
