# Test: ivar naming remains safe for C keywords and iv_ prefix collisions.

class KeywordIvar
  def initialize
    @if = 40
    @iv_if = 1
  end

  def value
    @if + @iv_if + 1
  end
end

puts KeywordIvar.new.value
