# Hash shorthand `{ x:, y: }` (Ruby 3.1+): an AssocNode whose value is
# implicit. Prism wraps the implicit value in a PM_IMPLICIT_NODE that
# carries the actual LocalVariableReadNode (or MethodCallNode for an
# undeclared name) as its `value` child. spinel_parse unwraps the
# ImplicitNode at the AST boundary so the codegen never sees the
# wrapper, which means the shorthand reuses the existing
# AssocNode + LocalVariableReadNode compile path with zero codegen
# change.

# 1. Two-key shorthand from int-valued locals.
x = 10
y = 20
nums = {x:, y:}
puts nums[:x]
# 10
puts nums[:y]
# 20

# 2. Single-key shorthand returned from a method body.
def make_pair(weight)
  {weight:}
end

h = make_pair(42)
puts h[:weight]
# 42

# 3. Mixing shorthand and explicit pair (same value type — int).
n = 7
m = 11
total = {n:, m:, sum: 18}
puts total[:n]
# 7
puts total[:m]
# 11
puts total[:sum]
# 18
