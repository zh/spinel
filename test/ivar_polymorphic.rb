# Issue #130: instance variable assigned different definite-typed values
# across methods used to either fail to compile (-Wint-conversion under
# -Werror), silently coerce (Integer→Float when slot won inference as Float),
# or segfault. Fix is in scan_ivars: when both writes are definite-literal
# and types disagree, widen the slot to poly. Write sites then box every
# concrete-typed RHS to sp_RbVal; read sites already use sp_poly_puts and
# friends.
#
# Variant 3 of the issue (ternary RHS with mixed types in a single-write
# slot) is a different root — the slot widens to "int" because IfNode
# isn't a definite-literal — and is filed separately.

# 1. String + Integer — variant 1 from the issue. Original symptom:
#    -Wint-conversion warning, indeterminate runtime output.
class C1
  def set_int; @x = 42; end
  def set_str; @x = "hello"; end
  def show; puts @x; end
end

c1 = C1.new
c1.set_int; c1.show                  # 42
c1.set_str; c1.show                  # hello

# 2. Integer + Float — variant 2. Original symptom: silent coercion;
#    `42` printed as `42.0` because the slot won inference as Float.
class C2
  def set_int; @x = 42; end
  def set_float; @x = 3.14; end
  def show; puts @x; end
end

c2 = C2.new
c2.set_int; c2.show                  # 42
c2.set_float; c2.show                # 3.14

# 3. String + Symbol — already widened to poly in pre-#130 inference but
#    didn't compile because write sites weren't boxed. Pins the boxing fix.
class C3
  def set_str; @x = "hello"; end
  def set_sym; @x = :world; end
  def show; puts @x; end
end

c3 = C3.new
c3.set_str; c3.show                  # hello
c3.set_sym; c3.show                  # world

# 4. Three concrete types in different methods — slot stays poly across
#    each disagreement.
class C4
  def set_int; @x = 100; end
  def set_str; @x = "txt"; end
  def set_float; @x = 2.5; end
  def show; puts @x; end
end

c4 = C4.new
c4.set_int; c4.show                  # 100
c4.set_str; c4.show                  # txt
c4.set_float; c4.show                # 2.5

# 5. Single-type ivar — regression guard. The pre-#130 happy path stays
#    happy. No widening, slot stays mrb_int.
class C5
  def set; @x = 42; end
  def show; puts @x; end
end

c5 = C5.new
c5.set; c5.show                      # 42

# 6. Initialize sets one type, another method sets another. Constructor
#    body has its own ivar-write emit path (separate from the general
#    InstanceVariableWriteNode case); this pins both paths box correctly.
class C6
  def initialize
    @x = 42
  end
  def set_str; @x = "hello"; end
  def show; puts @x; end
end

c6 = C6.new
c6.show                              # 42
c6.set_str
c6.show                              # hello
