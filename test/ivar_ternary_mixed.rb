# Issue #131: a single-write ivar whose RHS is a ternary (or if-as-
# expression) with branches of different concrete types used to type
# the slot from `infer_ivar_init_type`'s default fallback ("int") and
# emit a raw `(cond ? then : else)` C ternary into a typed slot —
# pointer/integer mismatch warning, segfault at runtime.
#
# Fix: `infer_ivar_init_type` recurses into IfNode branches with strict
# unification (no "int is default" escape hatch); `box_expr_to_poly`
# always per-branch boxes IfNode in poly contexts. Slot widens to poly
# for mixed-type branches; same-type branches infer as that type and
# the existing path applies.

# 1. Ternary mixing String and Integer — variant 3 from #130.
#    Was: -Wconditional-type-mismatch and segfault.
class C1
  def init(use_str)
    @x = use_str ? "hello" : 42
  end
  def show; puts @x; end
end

c1 = C1.new
c1.init(false); c1.show              # 42
c1.init(true);  c1.show              # hello

# 2. Same shape with Integer/Float — silent-coerce in pre-fix codegen.
class C2
  def init(use_int)
    @x = use_int ? 100 : 1.5
  end
  def show; puts @x; end
end

c2 = C2.new
c2.init(true);  c2.show              # 100
c2.init(false); c2.show              # 1.5

# 3. Mixed-type ternary combined with later concrete write — must
#    interact with #130's multi-write widening: poly + concrete = stay poly.
class C3
  def init(use_str)
    @x = use_str ? "hello" : 42
  end
  def overwrite_sym
    @x = :sym
  end
  def show; puts @x; end
end

c3 = C3.new
c3.init(true);  c3.show              # hello
c3.overwrite_sym; c3.show            # sym
c3.init(false); c3.show              # 42

# 4. Same-type ternary — regression guard. Both branches int, slot
#    stays mrb_int, no boxing overhead.
class C4
  def init(big)
    @x = big ? 1000 : 1
  end
  def show; puts @x; end
end

c4 = C4.new
c4.init(true);  c4.show              # 1000
c4.init(false); c4.show              # 1

# 5. Same-type-string ternary — regression guard. Slot stays string.
class C5
  def init(loud)
    @x = loud ? "HEY" : "hi"
  end
  def show; puts @x; end
end

c5 = C5.new
c5.init(true);  c5.show              # HEY
c5.init(false); c5.show              # hi

# 6. if-as-expression form (statement-style) with mixed types.
#    Same AST shape (IfNode) as ternary, just multi-line surface syntax.
class C6
  def init(use_str)
    @x = if use_str
           "world"
         else
           99
         end
  end
  def show; puts @x; end
end

c6 = C6.new
c6.init(true);  c6.show              # world
c6.init(false); c6.show              # 99

# 7. Ternary with nil branch — should widen to nullable string,
#    not poly. Let the existing nullable widening flow through.
class C7
  def init(have)
    @x = have ? "yes" : nil
  end
  def show; puts @x.nil? ? "nope" : @x; end
end

c7 = C7.new
c7.init(true);  c7.show              # yes
c7.init(false); c7.show              # nope
