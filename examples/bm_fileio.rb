# Test basic File I/O

# Write a file
File.write("/tmp/spinel_test.txt", "Hello from Spinel!\nLine 2\n")

# Read the file
content = File.read("/tmp/spinel_test.txt")
puts content

# File.exist?
puts File.exist?("/tmp/spinel_test.txt")  # true
puts File.exist?("/tmp/nonexistent.txt")  # false

# Clean up
File.delete("/tmp/spinel_test.txt")
puts File.exist?("/tmp/spinel_test.txt")  # false

puts "done"
