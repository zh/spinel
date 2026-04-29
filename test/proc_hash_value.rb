# Issue #65: an ivar initialized as `{}` and later assigned `&block`
# captured procs lowered the slot to str_int_hash, then fed
# `sp_Proc *` into `sp_StrIntHash_set` (which expects mrb_int).
#
# Two fixes:
#   - Issue #64's empty-hash promotion now resolves the slot to
#     `str_poly_hash` when the value type is `proc`.
#   - `box_expr_to_poly` / `box_value_to_poly` learned a `proc`
#     branch so the `[]=` site emits `sp_box_proc(...)` instead of
#     falling through to `sp_box_int`.
#   - The empty-hash inline-init paths (compile_stmt and
#     emit_constructor) now route to `sp_StrPolyHash_new()` /
#     `sp_SymPolyHash_new()` for poly-valued promotions.

class Registry
  def initialize
    @builtins = {}
  end

  def define_builtin(name, &block)
    @builtins[name] = block
  end
end

r = Registry.new
r.define_builtin("x") { 1 }
puts "ok"
