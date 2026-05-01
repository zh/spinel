class TokenSink
  def initialize
    @value = ""
  end

  def set_token(value)
    @value = value.to_s
  end

  def run
    set_token(1)
    set_token("done")
    puts @value
  end
end

TokenSink.new.run
