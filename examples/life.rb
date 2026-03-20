# Conway's Game of Life
#
# Rules:
#   Birth:    dead cell with exactly 3 live neighbors → alive
#   Survive:  live cell with 2 or 3 live neighbors → alive
#   Death:    otherwise → dead
#
# Uses 1D array (H*W) to represent the grid.

H = 40
W = 80
SIZE = H * W
GENERATIONS = 200

def cell_get(cells, x, y)
  cells[(y % H) * W + (x % W)]
end

def neighbors(cells, x, y)
  (-1..1).sum { |iy|
    (-1..1).count { |ix| cell_get(cells, x + ix, y + iy) == 1 }
  }
end

def next_gen(cells)
  SIZE.times.map { |i|
    y = i / W
    x = i % W
    n = neighbors(cells, x, y)
    if n == 3
      1
    elsif n == 4 && cells[i] == 1
      1
    else
      0
    end
  }
end

# Initialize with a deterministic pattern (glider + blinker)
cells = SIZE.times.map { 0 }

# Glider at (1,1)
cells[1 * W + 2] = 1
cells[2 * W + 3] = 1
cells[3 * W + 1] = 1
cells[3 * W + 2] = 1
cells[3 * W + 3] = 1

# Blinker at (10,10)
cells[10 * W + 10] = 1
cells[10 * W + 11] = 1
cells[10 * W + 12] = 1

# Run
gen = 0
while gen < GENERATIONS
  cells = next_gen(cells)
  gen = gen + 1
end

# Count final live cells
puts cells.count { _1 == 1 }
puts "done"
