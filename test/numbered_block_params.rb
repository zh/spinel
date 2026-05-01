# Numbered block params (`_1`) and Ruby 3.4 implicit `it`.
#
# `_1` was already supported via Prism's NumberedParametersNode + a
# regular LocalVariableReadNode at the use site. Implicit `it` (Ruby
# 3.4) was emitted as PM_IT_PARAMETERS_NODE / PM_IT_LOCAL_VARIABLE_READ_NODE
# which the codegen had no handler for. spinel_parse now lowers both
# to their `_1` equivalents so the codegen reuses the existing path.

# 1. `_1` over an int array — each.
[1, 2, 3].each { puts _1 }
# 1
# 2
# 3

# 2. `_1` over a map+each chain.
[10, 20].map { _1 * 2 }.each { puts _1 }
# 20
# 40

# 3. `it` over an int array — each with arithmetic.
[1, 2, 3].each { puts it * 2 }
# 2
# 4
# 6

# 4. `it` over a map+each chain.
[10, 20, 30].map { it * 2 }.each { puts it }
# 20
# 40
# 60

# 5. `it` mixed with arithmetic and comparison.
[1, 2, 3, 4].select { it > 2 }.each { puts it }
# 3
# 4

# 6. `it` over a string array.
["alice", "bob"].each { puts it }
# alice
# bob
