pico-8 cartridge // http://www.pico-8.com
version 8
__lua__

-- entities

xwing = {}
settings = {
 yaxis = 1
}

-- math

scene_cam = {0, 0, -2.5, 64}

function reset_scene_cam()
 scene_cam[1] = 0
 scene_cam[2] = 0
end

function rotate_y(x, y, z, angle)
 local co, si = cos(angle), sin(angle)
 return {
  z*si + x*co,
  y,
  z*co - x*si
 }
end

function rotate_z(x, y, z, angle)
 local co, si = cos(angle), sin(angle)
 return {
  x*co - y*si,
  x*si + y*co,
  z
 }
end

function addv(v1, v2)
 return {v1[1]+v2[1], v1[2]+v2[2], v1[3]+v2[3]}
end

function subv(v1, v2)
 return {v1[1]-v2[1], v1[2]-v2[2], v1[3]-v2[3]}
end

function normv(v)
 local s = 1/sqrt(sqr(v[1])+sqr(v[2])+sqr(v[3]))
 return {v[1]*s, v[2]*s, v[3]*s}
end

function projectv(v)
 return project(v[1], v[2], v[3])
end

function distv(v1, v2)
 return sqrt(sqr(v1[1]-v2[1])+sqr(v1[2]-v2[2])+sqr(v1[3]-v2[3]))
end

function project(x, y, z)
 local mult = scene_cam[4]
 local d = z - scene_cam[3]
 local px = 64 + (x - scene_cam[1]) * mult / d
 local py = 64 - (y - scene_cam[2]) * mult / d
 return {x=px, y=py}
end

function sqr(x)
 return x*x
end

function rndsign(x)
 if rnd(10) < 5 then
  return x
 else
  return -x
 end
end

-- particle engine

particles_pool = {}
particles_pool_index = 0
particles_pool_size  = 256

function particle_explosion(x, y, n)
 for i=1,n do
  particles_add(particle_new(x, y, rnd(30), rnd(64)/64, 1+rnd(5), 8+rnd(3)))
 end
end

function particle_shockwave(x, y, energy, speed, col)
 particles_add({
  pos_x  = x,
  pos_y  = y,
  vel    = speed,
  radius = 0,
  nrg    = energy,
  dcy    = 1/energy,
  col    = col,
  shock  = true
 })
end


function particle_new(x, y, energy, angle, speed, col)
 return {
  pos_x = x,
  pos_y = y,
  vel_x = speed * cos(angle),
  vel_y = -speed * sin(angle),
  nrg   = energy,
  dcy   = 1/energy,
  col   = col
 }
end

function particles_add(particle)
 local i = 0
 while i < particles_pool_size do
  if particles_pool[particles_pool_index] == nil or particles_pool[particles_pool_index].nrg <= 0 then
   particles_pool[particles_pool_index] = particle
   return
  else
   particles_pool_index += 1
   particles_pool_index %= particles_pool_size
   i += 1
  end
 end
end

function update_particles(frame)
 for i=1,#particles_pool do
  particle = particles_pool[i]
  particle.nrg -= 1
  if particle.nrg > 0 then
   if particle.shock then
    particle.radius += particle.vel
   else
    particle.pos_x += particle.vel_x
    particle.pos_y += particle.vel_y
    particle.col = particle_color(particle.nrg * particle.dcy, particle.col)
   end
  end
 end
end

function particle_color(life, col)
 if life > 0.5 then
  return col
 elseif life > 0.3 then
  return 6
 elseif life > 0.2 then
  return 5
 elseif life > 0.1 then
  return 1
 else
  return 0
 end
end

function draw_particles()
 for particle in all(particles_pool) do
  if particle.nrg > 0 then
   if particle.shock then
    circ(particle.pos_x, particle.pos_y, particle.radius, particle.col)
   else
    pset(particle.pos_x, particle.pos_y, particle.col)
   end
  end
 end
end

-- lasers

lasers_pool = {}
lasers_pool_index = 0
lasers_pool_size  = 256

function init_lasers()
 lasers_pool = {}
end

function fire_laser()
 local x, y

 xwing.cannon = (xwing.cannon + 1) % 4
 xwing.cannon_hot = 10

 if xwing.cannon == 0 or xwing.cannon == 3 then
  x = -1
 else
  x = 1
 end

 if xwing.cannon < 2 then
  y = 1
 else
  y = -1
 end

 local laser = {
  pos=rotate_z(scene_cam[1]-x*4, scene_cam[2]-y-2, 0, xwing.roll),
  nearcol=9,
  farcol=4,
  blast_radius=1.5
 }

 local cannon_aim = {scene_cam[1], scene_cam[2], 20}

 laser.vel = normv(subv(cannon_aim, laser.pos))

 add_laser(laser)

 xwing.lasers_level = max(0, xwing.lasers_level - 0.05)
end

function fire_torpedo()
 local left_torpedo  = new_torpedo(rotate_z(scene_cam[1]-0.5, scene_cam[2]-2, 0, xwing.roll))
 local right_torpedo = new_torpedo(rotate_z(scene_cam[1]+0.5, scene_cam[2]-2, 0, xwing.roll))

 add_laser(left_torpedo)
 add_laser(right_torpedo)
end

function new_torpedo(pos)
 return {
  pos=pos,
  vel={0,0,0.25},
  nearcol=12,
  farcol=13,
  blast_radius=2,
  torpedo=true
 }
end

function tie_fire_laser(tie)
 local left_laser = new_tie_laser(tie.pos, -0.1, tie.roll)
 local right_laser = new_tie_laser(tie.pos, 0.1, tie.roll)

 add_laser(left_laser)
 add_laser(right_laser)
end

function new_tie_laser(pos, xoffset, roll)
 return {
  pos=rotate_z(pos[1]+xoffset, pos[2]-0.75, pos[3]-1, roll),
  vel={0,0,-0.75},
  nearcol=11,
  farcol=11, -- 3
  blast_radius=1,
  tie=true
 }
end

function add_laser(laser)
 local i = 0
 while i < lasers_pool_size do
  if lasers_pool[lasers_pool_index] == nil or lasers_pool[lasers_pool_index].dead then
   lasers_pool[lasers_pool_index] = laser
   return
  else
   lasers_pool_index += 1
   lasers_pool_index %= lasers_pool_size
   i += 1
  end
 end
end

function update_lasers()
 for laser in all(lasers_pool) do
  if not laser.dead then
   laser.pos = addv(laser.pos, laser.vel)
   -- clip
   local z = laser.pos[3]
   if (not laser.tie and z > 20) or z < 0 then
    laser.dead = true
   end
   -- collision
   if laser.tie then
    detect_xwing_collision(laser)
   else
    detect_tie_collision(laser)
    detect_mine_collision(laser)
   end
  end
 end
end

function detect_xwing_collision(laser)
 if not xwing.destroyed and distv(laser.pos, {scene_cam[1], scene_cam[2], 0}) < laser.blast_radius then
  take_hit(0.1)
  laser.dead = true
 end
end

function detect_tie_collision(laser)
 for tie in all(ties) do
  if not tie.destroyed and distv(laser.pos, tie.pos) <= (laser.blast_radius*2) then
   sfx(4+rnd(3))
   tie.destroyed = true
   tie.destseed = frame
   tie.respawn = 30*(2+rnd(3))
   laser.dead = true
   xwing.score += 1
   if xwing.score % 10 == 0 then
    xwing.level += 1
    xwing.torpedoes = min(xwing.torpedoes + 1, 5)
    if #ties < 7 then
     add(ties, random_tie(50))
    end
   end
   local pos = projectv(tie.pos)
   if laser.torpedo then
    particle_shockwave(pos.x, pos.y, 16, 1, 12)
    particle_shockwave(pos.x, pos.y, 32, 2, 13)
    particle_explosion(pos.x, pos.y, 10)
   else
    particle_explosion(pos.x, pos.y, 20+rnd(20))
   end
   break
  end
 end
end

function detect_mine_collision(laser)
 for mine in all(mines) do
  if not mine.destroyed and distv(laser.pos, mine.pos) <= (laser.blast_radius*3) then
   sfx(4+rnd(3))
   mine.destroyed = true
   laser.dead = true
   local pos = projectv(mine.pos)
   particle_explosion(pos.x, pos.y, 20+rnd(20))
   break
  end
 end
end

function draw_lasers()
 for laser in all(lasers_pool) do
  if not laser.dead then
   local z  = laser.pos[3]
   local p1 = project(laser.pos[1], laser.pos[2], z)
   local p2 = project(laser.pos[1], laser.pos[2], z+2)
   local col = laser.nearcol
   if z > 10 then
    col = laser.farcol
   end
   line(p1.x, p1.y, p2.x, p2.y, col)
  end
 end
end

-- damage

function new_cracks()

 local cracks  = { {}, {}, {} }
 local phase   = rnd(100)*0.01
 local ncracks = 3+rnd(2)

 local x1 = 64 + 50-rnd(100)
 local y1 = 20+rnd(50)
 if y1 > 50 then -- don't show crack in the middle
  y1 += 40
 end

 for i=1,ncracks do
  local angle1 = (phase+i/ncracks) + rnd(10)*0.01
  local len = 3+rnd(4)
  local x2 = x1 + cos(angle1)*len
  local y2 = y1 + sin(angle1)*len
  add(cracks[1], {x1, y1, x2, y2})

  for j=1,1+rnd(2) do
   local angle2 = angle1+rndsign(rnd(10)*0.0175)
   local len = 8+rnd(6)
   local x3 = x2 + cos(angle2)*len
   local y3 = y2 + sin(angle2)*len
   add(cracks[2], {x2, y2, x3, y3})

   for k=1,1+rnd(2) do
    local angle3 = angle2+rndsign(rnd(10)*0.02)
    local len = 10+rnd(4)
    local x4 = x3 + cos(angle3)*len
    local y4 = y3 + sin(angle3)*len

    add(cracks[3], {x3, y3, x4, y4})
   end
  end
 end

 return cracks

end

function draw_cracks(damage)
 local palette
 if damage.counter < 20 then
  palette = {1}
 elseif damage.counter < 60 then
  palette = {12, 1}
 else
  palette = {7, 12, 1}
 end
 for idx, segments in pairs(damage.cracks) do
  local col = palette[idx]
  if col then
   for seg in all(segments) do
    line(seg[1], seg[2], seg[3], seg[4], col)
   end
  end
 end
end

-- tie

ties = {}

function init_ties()
 ties = {}
 for i=1,2 do
  add(ties, random_tie(40+i*20))
 end
end

function random_tie(depth)
 local r = rnd(10)

 local spread = 10
 if xwing.level > 1 then
  spread = 20
 end

 local pos  = {rndsign(rnd(spread)), rndsign(rnd(spread)), depth}
 local aggr = 20+rnd(max(50-10*xwing.level, 10))
 local vel  = 0.25+rnd(10)*0.01

 local roll    = 0
 local angvel = 0
 if r < 3 then
  -- spinner
  roll   = rnd(100)/100
  angvel = rndsign(rnd(10)/1000)
 end

 return {pos=pos, vel=vel, roll=roll, angvel=angvel, aggr=aggr, destseq=60, destseed=nil}
end


function draw_tie(tie, roll)
 local radius       = 1
 local axle         = 1
 local col_hull     = 5
 local col_wing     = 6
 local col_viewport = 13 --6

 local la1 = addv(rotate_z(-radius, 0, 0, roll), tie.pos)
 local la2 = addv(rotate_z(-radius-axle, 0, 0, roll), tie.pos)
 local ra1 = addv(rotate_z(radius, 0, 0, roll), tie.pos)
 local ra2 = addv(rotate_z(radius+axle, 0, 0, roll), tie.pos)

 local pla1 = projectv(la1)
 local pla2 = projectv(la2)
 local pra1 = projectv(ra1)
 local pra2 = projectv(ra2)

 if tie.destroyed then
  -- destruction sequence
  local progress = (60-tie.destseq)/60
  local blast = {(12+tie.destseed%19)*progress, 0, 0}

  local langvel = 2+(tie.destseed%97)*0.025
  local rangvel = 2+(bnot(tie.destseed)%97)*0.025
  local lspin = roll-progress*langvel
  local rspin = roll+progress*rangvel

  if progress > 0.9 then
   col_wing = 1
   col_hull = 0
  elseif progress > 0.8 then
   col_hull = 1
   col_wing = 5
  end

  draw_tie_wing(subv(la2, blast), lspin, col_hull, col_wing)
  draw_tie_wing(addv(ra2, blast), rspin, col_hull, col_wing)

 else
  -- cockpit
  local cockpit_pos = projectv(tie.pos)
  local cockpit_rad = sqrt(sqr(pla1.x-cockpit_pos.x) + sqr(pla1.y-cockpit_pos.y))
  circ(cockpit_pos.x, cockpit_pos.y, cockpit_rad, col_hull)
  draw_tie_viewport(cockpit_pos.x, cockpit_pos.y, cockpit_rad*0.6, roll, col_viewport)

  -- axles
  line(pla1.x, pla1.y, pla2.x, pla2.y, col_hull)
  line(pra1.x, pra1.y, pra2.x, pra2.y, col_hull)

  -- wings
  draw_tie_wing(la2, roll, col_hull, col_wing)
  draw_tie_wing(ra2, roll, col_hull, col_wing)
 end
end

function draw_tie_viewport(cx, cy, outer_radius, roll, col)
 if outer_radius < 1 then
  return
 end

 local angle = -roll
 local inner_radius = outer_radius*0.5
 local ox1 = cx + outer_radius*cos(angle)
 local oy1 = cy + outer_radius*sin(angle)
 local ix1 = cx + inner_radius*cos(angle)
 local iy1 = cy + inner_radius*sin(angle)
 for i=1,8 do
  angle += 0.125
  local ox2 = cx + outer_radius*cos(angle)
  local oy2 = cy + outer_radius*sin(angle)
  local ix2 = cx + inner_radius*cos(angle)
  local iy2 = cy + inner_radius*sin(angle)
  line(ox1, oy1, ox2, oy2, col)
  line(ix1, iy1, ix2, iy2, col)
  line(ox1, oy1, ix1, iy1, col)
  ox1, oy1 = ox2, oy2
  ix1, iy1 = ix2, iy2
 end
end

function draw_tie_wing(pos, roll, col_hull, col_wing)
 local wing_vertices = {
  {0, 0, 0},
  {0, 2, 1},
  {0, 2, -1},
  {0, 0, -2},
  {0, -2, -1},
  {0, -2, 1},
  {0, 0, 2},
 }

 local points = {}
 for v in all(wing_vertices) do
  add(points, projectv(addv(rotate_z(v[1], v[2]*1.2, v[3], roll), pos)))
 end

 for i=2,7 do
  local x, y = points[i].x, points[i].y
  line(points[1].x, points[1].y, x, y, col_wing)
 end

 line(points[2].x, points[2].y, points[3].x, points[3].y, col_hull)
 line(points[3].x, points[3].y, points[4].x, points[4].y, col_hull)
 line(points[4].x, points[4].y, points[5].x, points[5].y, col_hull)
 line(points[5].x, points[5].y, points[6].x, points[6].y, col_hull)
 line(points[6].x, points[6].y, points[7].x, points[7].y, col_hull)
 line(points[7].x, points[7].y, points[2].x, points[2].y, col_hull)

end

function update_ties()
 for idx, tie in pairs(ties) do
  if tie.destroyed then
   if tie.destseq > 0 then
    tie.destseq -= 1
   else
    tie.respawn -= 1
    if tie.respawn <= 0 then
     ties[idx] = random_tie(60)
    end
   end
  else
   tie.pos[3] -= tie.vel
   tie.roll += tie.angvel

   local dx = scene_cam[1]-tie.pos[1]
   local dy = scene_cam[2]-tie.pos[2]

   if tie.aggr < 30 then
    -- aggressive ties zero-in on the player
    if abs(dx) > 5 or abs(dy) > 5 then
     local dir = normv({dx, dy, 0})
     tie.pos[1] += tie.vel*dir[1]
     tie.pos[2] += tie.vel*dir[2]
    end
   end

   if tie.pos[3] < 0 then
    -- fly by player
    if abs(dx) < 2 and abs(dy) < 2 and not xwing.destroyed then
     -- colision with tie
     take_hit(0.2)
    end
    -- spawn new tie
    ties[idx] = random_tie(50)
   else
    -- enemy fire
    if flr(frame % tie.aggr) == 0 then
     if not xwing.destroyed then
      sfx(3)
     end
     tie_fire_laser(tie)
    end
   end
  end
 end

end

function draw_ties()
 for tie in all(ties) do
  if tie.destseq > 0 then
   draw_tie(tie, xwing.roll+tie.roll)
  end
 end
end

-- mines

mines = {}
minefield = {}

function init_mines()
 mines = {}
 minefield = {
  countdown = 30*10+rnd(8),
  generation = 0
 }
end

function deploy_mine_field(width, height, hspacing, vspacing)
 for y=0,height-1 do
  local my = (y-height*0.5) * vspacing
  for x=0,width-1 do
   local mx = (x-width*0.5) * hspacing
   add_mine(new_mine(mx, my))
  end
 end
end

function deploy_circular_minefield(num, radius)
 local mul = 1/num
 for idx=0,num do
  local x = radius * cos(idx * mul)
  local y = radius * sin(idx * mul)
  add_mine(new_mine(x, y))
 end
end

function new_mine(x, y)
 return {
  pos = {x, y, 40},
  roll = rnd(100)*0.01,
  angvel = rndsign(rnd(100)*0.0001),
  proximity_radius = 30,
  proximity = 0
 }
end

function add_mine(mine)
 local idx = 1
 while idx < #mines do
  idx += 1
  if mines[idx].destroyed then
   mines[idx] = mine
  end
 end
 add(mines, mine)
end

function update_mines()

 minefield.countdown = max(0, minefield.countdown - 1)

 if minefield.countdown == 0 then
  -- deploy new minefield
  if (minefield.generation % 2) == 0 then
   local size = mid(1, minefield.generation, 4)
   deploy_mine_field(size, size, 70, 70)
  else
   deploy_circular_minefield(3+rnd(min(minefield.generation, 7)), 40)
  end
  minefield.generation += 1
  minefield.countdown = 30*27
 end

 if (frame % 1337) == 0 then
  add_mine(new_mine(20-rnd(40), 20-rnd(40)))
 end

 for mine in all(mines) do
  if not mine.destroyed then
   mine.pos[3] -= 0.1
   mine.roll += mine.angvel

   if mine.pos[3] < 0 then
    mine.destroyed = true
   else
    local dist = distv(mine.pos, scene_cam)

    if dist <= mine.proximity_radius then
     mine.proximity = 1-(dist/mine.proximity_radius)
    else
     mine.proximity = 0
    end

    if not xwing.destroyed then
     if not mine.warned and mine.proximity > 0.7 then
      sfx(8)
      mine.warned = true
     end
     if mine.proximity > 0.8 then
      sfx(7)
      mine.destroyed = true
      local p = projectv(mine.pos)
      particle_shockwave(p.x, p.y, 64, 3, 8)
      particle_explosion(p.x, p.y, 30)
      take_hit(0.3)
     end
    end

   end
  end
 end
end

function draw_mines()
 for mine in all(mines) do
  if not mine.destroyed then
   draw_mine(mine, xwing.roll)
  end
 end
end

function draw_mine(mine, roll)
 local vertices = {
  -- outline
  {-0.5, 2},
  {0.5, 2},
  {2.5, -1},
  {1.5, -2},
  {-1.5, -2},
  {-2.5, -1},
  -- top light
  {0, 1.5},
  {0, 0.5},
  -- right light
  {1.5, -1},
  {0.5, -1+0.525},
  -- left light
  {-1.5, -1},
  {-0.5, -1+0.525}
 }
 local lines = {
  {1, 2},
  {2, 3},
  {3, 4},
  {4, 5},
  {5, 6},
  {6, 1}
 }
 local lights = {
  {7, 8},
  {9, 10},
  {11, 12}
 }
 local scale = 0.65

 local pos = mine.pos
 local shape_col = 5
 local light_pulse = {1, 2, 8, 8, 8, 2}
 local light_col = light_pulse[1+flr((frame*0.05*mine.proximity)%5)]

 for v in all(vertices) do
  local rotv =  addv(pos, rotate_z(v[1]*scale, v[2]*scale, pos[3], mine.roll))
  v.prj = projectv(rotate_z(rotv[1], rotv[2], rotv[3], roll))
 end

 for l in all(lines) do
  local p1 = vertices[l[1]].prj
  local p2 = vertices[l[2]].prj
  line(p1.x, p1.y, p2.x, p2.y, shape_col)
 end

 for l in all(lights) do
  local p1 = vertices[l[1]].prj
  local p2 = vertices[l[2]].prj
  line(p1.x, p1.y, p2.x, p2.y, light_col)
 end

end

-- starfield

stars = {}

function init_starfield()
 stars = {}
 for i=1,10 do
  add(stars, {20-rnd(40), 20-rnd(40), rnd(20)})
 end
 for i=1,30 do
  add(stars, {40-rnd(80), 40-rnd(80), rnd(30)})
 end
end

function update_starfield()
 for star in all(stars) do
  star[3] -= 0.2
  if star[3] < 0 then
   star[3] = 30
  end
 end
end

function draw_starfield()
 for star in all(stars) do
  local z = star[3]
  local p = projectv(rotate_z(star[1], star[2], z, xwing.roll))
  if z > 15 then
   pset(p.x, p.y, 1)
  elseif z > 10 then
   pset(p.x, p.y, 5)
  elseif z > 5 then
   pset(p.x, p.y, 6)
  else
   pset(p.x, p.y, 7)
  end
 end
end

function draw_background_sprites()
 -- todo add sprite rotation...

 -- deathstar
 local pos = projectv({40, 40, 80})
 spr(5, pos.x,   pos.y)
 spr(6, pos.x+8, pos.y)
 spr(5, pos.x,   pos.y+8, 1, 1, false, true)
 spr(5, pos.x+8, pos.y+8, 1, 1, true,  true)

 -- star destroyer
 local pos = projectv({-50, 30, 80})
 spr(7, pos.x, pos.y)
 spr(7, pos.x+8, pos.y, 1, 1, true)
end

-- comlink

comlink = {
 message = nil,
 silence = 30*5,
 counter = 0,
 authors = {
  {
   "pico leader",
   "pico two",
   "pico three",
   "pico five",
  },
  {
   "zeta one",
   "delta two",
   "beta six",
   "tau seven",
  }
 },
 messages = {
  {
   "stay on target, pico eight!",
   "use the force, pico eight!",
   "i can't shake'em",
   "there are too many of them!",
   "loosen up!",
   "tie squadron, incoming!",
   "stabilize your rear deflectors",
   "watch for enemy fighters",
   "my r2 unit has a bad motivator!",
   "it's no good, i can't maneuver!",
   "lock s-foils in attack position",
   "may the force be with you!",
   "accelerate to attack speed",
   "standing by",
   "all wings report in",
   "hold tight",
   "switch your deflectors on",
   "double front!",
   "cut the chatter!",
   "this is it, boys!",
   "draw their fire",
   "heavy fire boss, twenty degrees!",
   "are you all right?",
   "watch yourself!",
   "enemy fighters coming our way",
   "we have picked up new signals",
   "my scope is negative",
   "keep up your visual scanning",
   "i can't see it, where is he?",
   "tie fighters, coming in!",
   "i'm hit but not bad",
   "heavy fire zone ahead",
   "hold on",
   "stay in attack formation",
   "keep your eyes open!",
   "there's too much interference",
   "coming in point three five!",
   "i see them!",
   "don't get cocky, kid!",
   "i'm on it!",
   "good shot, pico eight!",
   "that was too close...",
   "pico eight, pull in!",
   "minefield ahead",
   "watch for those proximity mines!",
   "sweep those proximity mines!"
  },
  {
   "die, rebel scum!",
   "you are no match for the empire!",
   "this silly rebelion ends today!",
   "wipe them out, all of them!",
   "tk1138, do you copy?"
  }
 }
}

function update_comlink()
 if comlink.counter == 0 and comlink.silence > 0 then
  comlink.silence -= 1
 else
  if comlink.counter > 0 then
   comlink.counter -= 1
  else
   comlink.silence = 30*(3+rnd(3))
   comlink.counter = 30*3
   comlink.message = new_comlink_message()
  end
 end
end

function new_comlink_message()
 local rebel = rnd(100) < 90
 if rebel then
  return {
   col1=11,
   col2=3,
   author=rnditem(comlink.authors[1]),
   text=rnditem(comlink.messages[1])
  }
 else
  return {
   col1=9,
   col2=8,
   author=rnditem(comlink.authors[2]),
   text=rnditem(comlink.messages[2])
  }
 end
end

function rnditem(t)
 return t[1+flr(rnd(#t))]
end

function draw_comlink()
 if comlink.counter > 0 then
  printc(comlink.message.author..":", 101, comlink.message.col1)
  printc(comlink.message.text, 108, comlink.message.col2)
 end
end

function printc(str, y, col)
 print(str, 64-#str*2, y, col)
end

-- hud

function draw_hud()
 draw_crosshair()
 draw_meters()
 draw_warnings()
end

function draw_crosshair()
 local x, y, space, sprnum = 67, 59, 4, 1
 if xwing.crosshair_lock and band(frame, 4) > 0 then
  sprnum = 17
 end
 spr(sprnum, x-space-8, y-space, 1, 1, false, false)
 spr(sprnum, x+space, y-space, 1, 1, true, false)
 spr(sprnum, x-space-8, y+space+8, 1, 1, false, true)
 spr(sprnum, x+space, y+space+8, 1, 1, true, true)
end

function draw_meters()
 print("s", 0, 1, 7)
 draw_meter(5, xwing.shields_level, 3, 11)

 local str = ""..xwing.score
 while #str < 6 do
  str = "0"..str
 end
 print(str, 64 - 6*2, 1, 7)

 draw_meter(91, xwing.lasers_level, 9, 10)
 print("l", 124, 1, 7)

 local x = 64 - xwing.torpedoes*2
 for i=1,xwing.torpedoes do
  spr(16, x, 8)
  x += 4
 end
end

function draw_meter(x, level, col, peakcol)
 local width = 30
 rect(x, 0, x+width, 6, 7)
 if level <= 0 then
  return
 elseif level < 0.2 then
  local x2 = x+2+level*(width-4)
  rectfill(x+2, 2,x2 , 4, 8)
 else
  local x2 = x+2+level*(width-4)
  rectfill(x+2, 2, x2-1, 4, col)
  pset(x2, 2, peakcol)
  pset(x2, 3, peakcol)
  pset(x2, 4, peakcol)
 end
end

function draw_warnings()
 if xwing.shields_level < 0.2 then
  blink("> shields low <", 30, 8)
 end
 if xwing.lasers_level < 0.2 then
  blink("> weapons low <", 90, 9)
 end
end

function blink(msg, y, col)
 local visible = band(frame, 8) > 0
 if visible then
  print(msg, 64 - (#msg * 2), y, col)
 end
end

function draw_xwing()
 -- nose
 spr(4, xwing.shake_x+56, xwing.shake_y+120, 1, 1, false)
 spr(4, xwing.shake_x+64, xwing.shake_y+120, 1, 1, true)
 -- cannons
 spr(cannon_spr(0), xwing.shake_x+120, xwing.shake_y+120, 1, 1, true)
 spr(cannon_spr(1), xwing.shake_x+0,   xwing.shake_y+120, 1, 1, false)
 spr(cannon_spr(2), xwing.shake_x+0,   xwing.shake_y+80,  1, 1, false)
 spr(cannon_spr(3), xwing.shake_x+120, xwing.shake_y+80,  1, 1, true)
end

function cannon_spr(n)
 if xwing.cannon_hot > 0 and xwing.cannon == n then
  return 19
 else
  return 3
 end
end

function draw_damages()
 for damage in all(xwing.damages) do
  if damage.counter > 0 then
   draw_cracks(damage)
  end
 end
end


-- xwing

function init_xwing()
 xwing = {
  cannon = 0,
  cannon_hot = 0,
  torpedoes = 3,
  shake_x = 0,
  shake_y = 0,
  vel_x = 0,
  vel_y = 0,
  acc_x = 0,
  acc_y = 0,
  roll = 0,
  lasers_level = 1,
  shields_level = 1,
  score = 0,
  level = 0,
  damage_index = 0,
  damages = {},
  destroyed = false,
  crosshair_lock = false,
  flash = false
 }
end

function update_xwing()
 if xwing.destroyed then
  scene_cam[1] = 10*cos(frame * 0.001)
  scene_cam[2] = 10*sin(frame * 0.0015)
  xwing.roll = sin(frame * 0.0025)
  xwing.gameover_delay = max(xwing.gameover_delay - 1, 0)
 else
  -- motion
  xwing.vel_x = min(xwing.vel_x+xwing.acc_x, 2) * 0.95
  xwing.vel_y = min(xwing.vel_y+xwing.acc_y, 2) * 0.95
  scene_cam[1] += xwing.vel_x
  scene_cam[2] += xwing.vel_y
  local bounds = 40
  if abs(scene_cam[1]) > bounds then scene_cam[1] = bounds*sgn(scene_cam[1]) end
  if abs(scene_cam[2]) > bounds then scene_cam[2] = bounds*sgn(scene_cam[2]) end
  -- autorepair
  local laser_repair = 0.005
  if xwing.lasers_level < 0.1 then
   laser_repair = 0.001
  end
  xwing.lasers_level  = min(1, xwing.lasers_level + laser_repair)
  xwing.shields_level = min(1, xwing.shields_level + 0.001)
  -- cannon sprite
  xwing.cannon_hot = max(0, xwing.cannon_hot - 1)
  -- crosshair
  xwing.crosshair_lock = false
  for tie in all(ties) do
   if not tie.destroyed
      and (abs(tie.pos[1]-scene_cam[1]) < 2)
      and (abs(tie.pos[2]-scene_cam[2]) < 2) then
    xwing.crosshair_lock = true
    break
   end
  end
 end
 -- damage
 for damage in all(xwing.damages) do
  damage.counter = max(0, damage.counter - 1)
 end
end

function take_hit(amount)
 sfx(2)

 local new_damage = {
  counter = 30*(3+rnd(2)),
  cracks = new_cracks()
 }

 xwing.flash = true

 xwing.damages[xwing.damage_index] = new_damage
 xwing.damage_index = flr((xwing.damage_index + 1) % 5) -- max damage

 xwing.shields_level = max(0, xwing.shields_level - amount)
 if xwing.shields_level <= 0.001 then
  -- gameover
  xwing.destroyed = true
  xwing.gameover_delay = 30*3
  sfx(16)
 end
end

function bank(angle)
 xwing.roll = mid(-0.05, xwing.roll + angle, 0.05)
end

function unbank(angle)
 if xwing.roll > angle then
  xwing.roll -= angle
 elseif xwing.roll < -angle then
  xwing.roll += angle
 else
  xwing.roll = 0
 end
end


function handle_input()
 if xwing.destroyed then
  -- gameover
  if xwing.gameover_delay == 0 and btnp(4) then
   start_intro()
   return false -- halt update
  end
 else
  local acc = 0.1

  if btn(0) then -- left
   xwing.acc_x = -acc
   xwing.shake_x = -2
   bank(0.005)
  elseif btn(1) then -- right
   xwing.acc_x = acc
   xwing.shake_x = 2
   bank(-0.005)
  else
   xwing.acc_x = 0
   xwing.shake_x = 0
   unbank(0.005)
  end

  if btn(2) then -- up
   xwing.acc_y = acc * settings.yaxis
   xwing.shake_y = 2 * settings.yaxis
  elseif btn(3) then -- down
   xwing.acc_y = -acc * settings.yaxis
   xwing.shake_y = -2 * settings.yaxis
  else
   xwing.acc_y = 0
   xwing.shake_y = 0
  end

  if btnp(4) then
   if xwing.lasers_level > 0.1 then
    fire_laser()
    sfx(0)
   end
  end

  if btnp(5) then
   if xwing.torpedoes > 0 then
    fire_torpedo()
    sfx(1)
    xwing.torpedoes -= 1
   else
    sfx(9)
   end
  end
 end

 return true
end

-- debug

function draw_debug()
 local col = 12

 -- horizon
 local x1, y1 = cos(xwing.roll), sin(xwing.roll)
 local x2, y2 = cos(xwing.roll+0.5), sin(xwing.roll+0.5)
 line(64+5*x1, 20+5*y1, 64+5*x2, 20+5*y2, col)

 print(xwing.roll, 80, 20, col)

 -- entities
 -- for tie in all(ties) do
 --  local p = projectv(tie.pos)
 --  print(tie.pos[3], p.x, p.y, col)
 --  print(tie.destseq, p.x, p.y+6, 8)
 -- end
 -- for laser in all(lasers_pool) do
 --  if not laser.dead then
 --   local p = projectv(laser.pos)
 --   print(laser.pos[3], p.x, p.y, col)
 --  end
 -- end
 -- for mine in all(mines) do
 --  local p = projectv(mine.pos)
 --  print(mine.proximity, p.x, p.y, 8)
 -- end
 -- resources
 print("f"..frame, 0, 10, col)
 print("l"..#lasers_pool, 0, 16, col)
 print("p"..#particles_pool, 0, 22, col)
 print("t"..#ties, 0, 28, col)
 print("m"..#mines, 0, 34, col)
 print("d"..#xwing.damages, 0, 40, col)
 print("ax"..xwing.acc_x, 0, 46, col)
 print("vx"..xwing.vel_x, 0, 52, col)
 print("ay"..xwing.acc_y, 0, 58, col)
 print("vy"..xwing.vel_y, 0, 64, col)
 print("cpu"..stat(1), 0, 72, col)
 print("mem"..stat(0), 0, 78, col)
end

-- intro

splash_duration = 30 * 3

logo = {
 vertices = {
  -- x
  {0, 0},
  {2, 0},
  {0, 2},
  {2, 2},
  -- -
  {3, 1},
  {4, 1},
  -- w
  {5, 0},
  {5, 2},
  {6, 1},
  {7, 2},
  {7, 0},
  -- i
  {8, 0},
  {10, 0},
  {8, 2},
  {10, 2},
  {9, 0},
  {9, 2},
  -- n
  {11, 2},
  {11, 0},
  {13, 2},
  {13, 0},
  -- g
  {16, 0},
  {14, 0},
  {14, 2},
  {16, 2},
  {16, 1},
  {15, 1},
  -- box
  {-1, -1},
  {17, -1},
  {17, 3},
  {-1, 3}
 },
 lines = {
  -- x
  {1, 4},
  {2, 3},
  -- -
  {5, 6},
  -- w
  {7, 8},
  {8, 9},
  {9, 10},
  {10, 11},
  -- i
  {12, 13},
  {14, 15},
  {16, 17},
  -- n
  {18, 19},
  {19, 20},
  {20, 21},
  -- g
  {22, 23},
  {23, 24},
  {24, 25},
  {25, 26},
  {26, 27},
  -- box
  {28, 29},
  {29, 30},
  {30, 31},
  {31, 28}
 }
}

crawl = {
 text = {
  "  the rebel alliance ",
  "   is under attack!  ",
  "                     ",
  "  surrounded by the  ",
  "emperor's most elite ",
  "troops, a small team ",
  "of fierce pilots must",
  "escape from a massive",
  "blockade...          ",
  "                     ",
  "      scramble,      ",
  "    pico squadron!   "
 },
 font_base = 8*2,
 font_metrics = {
  a = {0, 0},
  b = {4, 0},
  c = {8, 0},
  d = {12, 0},
  e = {16, 0},
  f = {20, 0},
  g = {24, 0},
  h = {28, 0},
  i = {32, 0},
  j = {36, 0},
  k = {40, 0},
  l = {44, 0},
  m = {48, 0},
  n = {52, 0},
  o = {56, 0},
  p = {60, 0},
  q = {64, 0},
  r = {68, 0},
  s = {72, 0},
  t = {76, 0},
  u = {80, 0},
  v = {84, 0},
  w = {88, 0},
  x = {92, 0},
  y = {96, 0},
  z = {100, 0},
  [" "] = {104, 0},
  ["."] = {108, 0},
  ["!"] = {112, 0},
  ["'"] = {116, 0},
  [","] = {120, 0},
 },
 height=120,
 line_widths = {},
 pos=0
}

function init_intro()
 logo.z      = 30
 intro_tune_played = false
 intro_crawl_done = false
end

function update_intro_anim()
 if frame < splash_duration then
  return
 end
 if crawl.pos < 85 then
  crawl.pos = flr((frame-splash_duration) * 0.35) - 90
 else
  intro_crawl_done = true

  update_starfield()

  for vertex in all(logo.vertices) do
   local v = {(8-vertex[1])*0.25, (1.5-vertex[2])*0.25, 0}
   v = rotate_y(v[1], v[2], v[3], frame*0.01)
   v[3] += logo.z
   vertex.prj = projectv(v)
  end
  if logo.z > 0 then
   logo.z -= 0.5
  end
 end
end

function init_crawl()
 -- texture
 crawl.texture_width = 21*4
 crawl.texture_height = #crawl.text*7
 crawl.texture = {}
 for str in all(crawl.text) do
  for y=0,6 do
   for idx=1,#str do
    local chr = sub(str, idx, idx)
    local metrics = crawl.font_metrics[chr]
    for x=0,3 do
     local col = sget(metrics[1]+x, crawl.font_base+metrics[2]+y)
     add(crawl.texture, col)
    end
   end
  end
 end
 -- tables
 local final_width = 64
 local dy = (148-final_width)/crawl.height
 for y=0,crawl.height-1 do
  crawl.line_widths[y] = final_width+y*dy*1.5
 end
end

function draw_intro()
 cls()

 if frame < splash_duration then
  local palette = { 1, 13, 12, 12, 12, 12, 12, 12, 12, 13, 1}
  local col = palette[1+flr(frame*(#palette/splash_duration))]
  print("a long time ago in a galaxy far", 0, 58, col)
  print("far away...", 0, 64, col)
 else
  draw_starfield()

  if intro_crawl_done then
   draw_logo()
   if logo.z <= 0 then
    if not intro_tune_played then
     sfx(32)
     intro_tune_played = true
    end

    printc("pico squadron", 81, 4)
    printc("pico squadron", 80, 10)

    printc("press fire to start", 100, frame/2)

    printc("by @xavierdefrang / v1", 122, 1)
   end
  else
   draw_crawl()
  end
 end
end

function draw_logo(col)
 for idx, l in pairs(logo.lines) do
  local p1 = logo.vertices[l[1]].prj
  local p2 = logo.vertices[l[2]].prj
  local col = 10
  if idx > 18 then
   col = 9
  end
  line(p1.x, p1.y, p2.x, p2.y, col)
 end
end

function draw_crawl()
 local palette = {1, 5, 9, 10}
 for y=0,crawl.height-1 do
  local width = crawl.line_widths[y]
  local texy = flr(crawl.pos+y*0.75)
  if texy >= 0 and texy < #crawl.text*7 then
   local col = palette[min(1+flr(y/8), #palette)]
   draw_crawl_line(128-crawl.height+y, texy, width, col)
  end
 end
end

function draw_crawl_line(scry, texty, width, col)
 local offset = 1 + texty*crawl.texture_width
 local dx = crawl.texture_width/width
 local scrx = 64-width/2
 for i=1,width do
  local texel = crawl.texture[flr(offset)]
  if texel != 0 then
   pset(scrx, scry, col)
  end
  offset += dx
  scrx += 1
 end
end

-- main state management


function start_intro()
 reset_scene_cam()

 frame = 0

 init_starfield()
 init_crawl()
 init_intro()

 set_callbacks(update_intro, draw_intro)
end

function update_intro()

 update_intro_anim()

 if btnp(4) then
  sfx(10)
  --sfx(33) -- music?
  start_game()
 end

end

function start_game()
 init_xwing()
 init_ties()
 init_mines()
 init_lasers()

 set_callbacks(update_game, draw_game)
end

function update_game()
 if handle_input() then
  update_lasers()
  update_starfield()
  update_ties()
  update_mines()
  update_xwing()
  update_particles()
  update_comlink()
 end
end

function draw_game()

 if xwing.flash then
  cls(7)
  xwing.flash = false
 else
  cls()
 end
 draw_starfield()
 --draw_background_sprites()
 draw_lasers()
 draw_mines()
 draw_ties()
 draw_particles()
 if xwing.destroyed then
  -- gameover screen
  draw_damages()
  printc("game over", 32, 12+(flr(frame / 4) % 2))
  if xwing.gameover_delay == 0 then
   printc("press fire to continue", 100, frame / 2)
  end
 else
  -- gameplay
  draw_xwing()
  draw_damages()
  draw_hud()
  draw_comlink()
 end
 --draw_debug()
end

function with_frame_counter(update_fun)
 return function()
  frame += 1
  update_fun()
 end
end

function set_callbacks(update_fun, draw_fun)
 _update = with_frame_counter(update_fun)
 _draw   = draw_fun
end

-- main

cartdata("xavier_xwing_pico_squadron_1")

if dget(0) != 0 then
 settings.yaxis = dget(0)
end

menuitem(1, "invert y-axis", function()
 settings.yaxis = -settings.yaxis
 dset(0, settings.yaxis)
end)

start_intro()

__gfx__
00000000000000000000000000000000000000770000005555000000000000100000000000000000000000000000000000000000000000000000000000000000
00000000088000000000000000560000000057770000555555550000000005550000000000000000000000000000000000000000000000000000000000000000
00700700080800000000000005600000000677770005555555555000000000050000000000000000000000000000000000000000000000000000000000000000
0007700082008000000000007676700000667777005555555dd55500000000550000000000000000000000000000000000000000000000000000000000000000
000770008000080000000077656000000066777605555555dddd5550000555550000000000000000000000000000000000000000000000000000000000000000
007007000880008000000776005600000666776805555555ddddd550055555550000000000000000000000000000000000000000000000000000000000000000
000000000008800800007688000000005566788855555555ddddd555015555550000000000000000000000000000000000000000000000000000000000000000
0000000000000888000768550000000056668855555555555ddd5555000000550000000000000000000000000000000000000000000000000000000000000000
0d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dcd000000aa000000000000000540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d0000000a0a00000000000005400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000a900a0000000000076799000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000a0000a000000000065400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aa000a00000000000540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000aa00a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77707770077077007770777007707070777077707070700077707700077077700700777007707770707070707070707070707770000000000700070000000000
70707070700070707000700070007070070007007070700077707070707070707070707070000700707070707070707070700070000000000700700000000000
77707700700070707700770070707770070007007700700070707070707077707070770077700700707070707070070077700700000000000700000000000000
70707070700070707000700070707070070007007070700070707070707070007700707000700700707077707770707000707000000000000000000000700000
70707770077077707770700077707070777077007070777070707070770070000770707077000700077007007770707077707770000070000700000007000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000c0500c65033050300502d0502905025050220501f0501d050190501805012050100500d0500b0500905007050060500605007050090500c0500e0500f0500c050090500705004050010500000000000
00030000184501745016450154501345012450104500e4500d4500b45009450094500745003450064500345002450024500145002450044500245001450014500000000000000000000000000000000000000000
000200001b6501a65018650096501565009650100500f0500e0500d0500c0500b0500b0500b0500a0500a05008050080400704006040050400404002040010300303001020010100301005010030100201001000
00010000260502605025050240500000000000000001805017050160501405012050100500f0500d0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001965014650106500d6500c6500a650096500865007650076500865005650000000b5500c5500c5500c5500b5500955006550045500760005600216501064002630026300262002600026000260001600
000200000a050090500265002650036500e05004650110501205004650140500465015050150501305012050046500f050036500c050026500905004050076500465002640016400263001630016200161000000
0001000000000082500825008250082500f6500c650082500000008250082501c6500825015250082500000007250126501365005250042500225001250012500b65009650076500565004650036500165000000
000100001035003550053501b0501b05019050170501605015050140501305011050100500e0500c0500a0500705005050070500505006050080500a0500b0500c0500d0500a0500605005050040500305004050
000800002934004300293400230029340000002934029340293402934029340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000625003250022500125001250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000016500165002650026500465006650096500c65010650146501b65021650276502d65032650396503f6503f6503f6503f6503e650376503065028650196500f6500c6500865005650056500465001650
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500000735004650086500d65011650186501b6501c6501c6501c6501c6501a650086501565013650106500e6500c6500a64008640066400464003630026300262001620016100161001610016100160000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010f00000c2600c2501300013250132501320011250102500e25018250182501800013250132501120011250102500e2501825018250000001325013250112001125010250112500e2500e2500e2500000000000
0110001a040500e00004000040501100000000040000c00004050100001300013000020000405016000000000405000000000000400001000010500000000000000500000000000000000000000000000000e000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

