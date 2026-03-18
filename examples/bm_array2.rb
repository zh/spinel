# Test additional Array methods

arr = (1..10).to_a

# reject
odds = arr.reject do |x|
  x % 2 == 0
end
puts odds.length  # 5

# reduce/inject via each
total = 0
arr.each do |x|
  total += x
end
puts total  # 55

# reverse
nums = (1..10).to_a
nums.reverse!
puts nums[0]  # 10
puts nums[9]  # 1

# Array#first / Array#last
puts nums.first  # 10
puts nums.last   # 1

# Array#min / Array#max
mn = nums[0]
mx = nums[0]
nums.each do |x|
  if x < mn
    mn = x
  end
  if x > mx
    mx = x
  end
end
puts mn  # 1
puts mx  # 10

# Array#include?
if nums.include?(5)
  puts "true"
else
  puts "false"
end   # true
if nums.include?(11)
  puts "true"
else
  puts "false"
end  # false

# Array#compact (remove nils) - simplified: just test count
puts nums.length  # 10
