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
  count = 0
  iy = -1
  while iy <= 1
    ix = -1
    while ix <= 1
      if cell_get(cells, x + ix, y + iy) == 1
        count = count + 1
      end
      ix = ix + 1
    end
    iy = iy + 1
  end
  count
end

def next_gen(cells)
  new_cells = Array.new
  y = 0
  while y < H
    x = 0
    while x < W
      n = neighbors(cells, x, y)
      alive = cells[y * W + x]
      if n == 3
        new_cells.push(1)
      elsif n == 4 && alive == 1
        new_cells.push(1)
      else
        new_cells.push(0)
      end
      x = x + 1
    end
    y = y + 1
  end
  new_cells
end

# Initialize with a deterministic pattern (glider + blinker)
cells = Array.new
i = 0
while i < SIZE
  cells.push(0)
  i = i + 1
end

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
live = 0
while gen < GENERATIONS
  cells = next_gen(cells)
  gen = gen + 1
end

# Count final live cells
i = 0
while i < SIZE
  if cells[i] == 1
    live = live + 1
  end
  i = i + 1
end

puts live
puts "done"
