# Method called only inside string interpolation should still anchor its
# parameter type. Pre-fix: scan_features didn't visit EmbeddedStatementsNode
# bodies, so `cap(name)` inside `"#{...}"` was the only call site for `cap`,
# its `s` param defaulted to int, and codegen produced a C compile error.

def cap(s)
  s + "_cap"
end

name = "frob"
puts "lv_#{cap(name)}"

# Same shape with two args, one of which is also a method call
def join_with(a, b)
  a + "_" + b
end

x = "hello"
y = "world"
puts "wrapped(#{join_with(x, y)})"

# Nested interpolation containing a method call whose param widens to int
def inc(n)
  n + 1
end

puts "next=#{inc(10)}"

# Method whose param widens to bool via interpolated boolean call
def bang(p)
  if p
    "YES"
  else
    "no"
  end
end

flag = true
puts "answer: #{bang(flag)}"
