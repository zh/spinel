# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
# Contributed by Sokolov Yura
# Modified by Chris Houhoulis
# Adapted for Spinel benchmark

n = Integer(ARGV[0] || 100)

u = Array.new(n, 1.0)
v = Array.new(n, 0.0)

def eval_a(i, j)
  1.0 / ((i + j) * (i + j + 1) / 2 + i + 1)
end

def vector_times_array(n, vector)
  arr = Array.new(n, 0.0)
  i = 0
  while i < n
    sum = 0.0
    j = 0
    while j < n
      sum = sum + eval_a(i, j) * vector[j]
      j = j + 1
    end
    arr[i] = sum
    i = i + 1
  end
  arr
end

def vector_times_array_transposed(n, vector)
  arr = Array.new(n, 0.0)
  i = 0
  while i < n
    sum = 0.0
    j = 0
    while j < n
      sum = sum + eval_a(j, i) * vector[j]
      j = j + 1
    end
    arr[i] = sum
    i = i + 1
  end
  arr
end

def multiply(n, u)
  v = vector_times_array(n, u)
  vector_times_array_transposed(n, v)
end

k = 0
while k < 10
  v = multiply(n, u)
  u = multiply(n, v)
  k = k + 1
end

vbv = 0.0
vv = 0.0
i = 0
while i < n
  vbv = vbv + u[i] * v[i]
  vv = vv + v[i] * v[i]
  i = i + 1
end

result = Math.sqrt(vbv / vv)
# Print as integer to avoid float formatting differences
puts (result * 1000000000).to_i
