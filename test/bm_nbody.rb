# N-Body with object array
SOLAR_MASS = 39.47841760435743
DAYS_PER_YEAR = 365.24

class Planet
  attr_accessor :x, :y, :z, :vx, :vy, :vz, :mass
  def initialize(x, y, z, vx, vy, vz, mass)
    @x = x
    @y = y
    @z = z
    @vx = vx
    @vy = vy
    @vz = vz
    @mass = mass
  end
end

bodies = []
bodies.push(Planet.new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, SOLAR_MASS))
bodies.push(Planet.new(
  4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
  1.66007664274403694e-03 * DAYS_PER_YEAR, 7.69901118419740425e-03 * DAYS_PER_YEAR,
  -6.90460016972063023e-05 * DAYS_PER_YEAR, 9.54791938424326609e-04 * SOLAR_MASS))
bodies.push(Planet.new(
  8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
  -2.76742510726862411e-03 * DAYS_PER_YEAR, 4.99852801234917238e-03 * DAYS_PER_YEAR,
  2.30417297573763929e-05 * DAYS_PER_YEAR, 2.85885980666130812e-04 * SOLAR_MASS))
bodies.push(Planet.new(
  1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
  2.96460137564761618e-03 * DAYS_PER_YEAR, 2.37847173959480950e-03 * DAYS_PER_YEAR,
  -2.96589568540237556e-05 * DAYS_PER_YEAR, 4.36624404335156298e-05 * SOLAR_MASS))
bodies.push(Planet.new(
  1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01,
  2.68067772490389322e-03 * DAYS_PER_YEAR, 1.62824170038242295e-03 * DAYS_PER_YEAR,
  -9.51592254519715870e-05 * DAYS_PER_YEAR, 5.15138902046611451e-05 * SOLAR_MASS))

nbodies = bodies.length

# offset momentum
px = 0.0
py = 0.0
pz = 0.0
i = 0
while i < nbodies
  b = bodies[i]
  px = px + b.vx * b.mass
  py = py + b.vy * b.mass
  pz = pz + b.vz * b.mass
  i = i + 1
end
b0 = bodies[0]
b0.vx = 0.0 - px / SOLAR_MASS
b0.vy = 0.0 - py / SOLAR_MASS
b0.vz = 0.0 - pz / SOLAR_MASS

def energy(bodies, nbodies)
  e = 0.0
  i = 0
  while i < nbodies
    b = bodies[i]
    e = e + 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy + b.vz * b.vz)
    j = i + 1
    while j < nbodies
      b2 = bodies[j]
      dx = b.x - b2.x
      dy = b.y - b2.y
      dz = b.z - b2.z
      dist = Math.sqrt(dx * dx + dy * dy + dz * dz)
      e = e - (b.mass * b2.mass) / dist
      j = j + 1
    end
    i = i + 1
  end
  e
end

def advance(bodies, nbodies, dt)
  i = 0
  while i < nbodies
    b = bodies[i]
    j = i + 1
    while j < nbodies
      b2 = bodies[j]
      dx = b.x - b2.x
      dy = b.y - b2.y
      dz = b.z - b2.z
      dsq = dx * dx + dy * dy + dz * dz
      dist = Math.sqrt(dsq)
      mag = dt / (dsq * dist)
      b.vx = b.vx - dx * b2.mass * mag
      b.vy = b.vy - dy * b2.mass * mag
      b.vz = b.vz - dz * b2.mass * mag
      b2.vx = b2.vx + dx * b.mass * mag
      b2.vy = b2.vy + dy * b.mass * mag
      b2.vz = b2.vz + dz * b.mass * mag
      j = j + 1
    end
    b.x = b.x + dt * b.vx
    b.y = b.y + dt * b.vy
    b.z = b.z + dt * b.vz
    i = i + 1
  end
end

n = Integer(ARGV[0] || 1000)

puts (energy(bodies, nbodies) * 1000000000).to_i

i = 0
while i < n
  advance(bodies, nbodies, 0.01)
  i = i + 1
end

puts (energy(bodies, nbodies) * 1000000000).to_i
