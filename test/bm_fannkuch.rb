# The Computer Language Benchmarks Game
# Fannkuch-Redux - adapted for Spinel

def fannkuch(n)
  p = Array.new(n + 1, 0)
  s = Array.new(n + 1, 0)
  q = Array.new(n + 1, 0)
  i = 0
  while i <= n
    p[i] = i
    s[i] = i
    q[i] = i
    i = i + 1
  end
  sign = 1
  sum = 0
  maxflips = 0
  while true
    q1 = p[1]
    if q1 != 1
      i = 0
      while i <= n
        q[i] = p[i]
        i = i + 1
      end
      flips = 1
      qq = q[q1]
      while qq != 1
        q[q1] = q1
        if q1 >= 4
          i = 2
          j = q1 - 1
          while i < j
            t = q[i]
            q[i] = q[j]
            q[j] = t
            i = i + 1
            j = j - 1
          end
        end
        q1 = qq
        flips = flips + 1
        qq = q[q1]
      end
      sum = sum + sign * flips
      if flips > maxflips
        maxflips = flips
      end
    end
    # Permute
    if sign == 1
      t = p[1]
      p[1] = p[2]
      p[2] = t
      sign = -1
    else
      t = p[2]
      p[2] = p[3]
      p[3] = t
      sign = 1
      i = 3
      while i <= n
        if s[i] != 1
          break
        end
        if i == n
          puts sum
          puts maxflips
          return
        end
        s[i] = i
        # Rotate 1<-...<-i+1
        t = p[1]
        j = 1
        while j < i + 1
          p[j] = p[j + 1]
          j = j + 1
        end
        p[i + 1] = t
        i = i + 1
      end
      s[i] = s[i] - 1
    end
  end
end

n = Integer(ARGV[0] || 7)
fannkuch(n)
