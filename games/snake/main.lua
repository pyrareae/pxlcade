local class = require('lib.class')
local Timer = require('lib.timer')
local inspect = require('lib.inspect')
local M = {
    name="Snake",
}
-- local function absMax(a, b) 
--     local max, min = math.max(a,b), math.min(a,b)
--     if math.abs(max) > math.abs(min) then
--         return max 
--     else
--         return min
--     end
-- end

local function roll(val, inc, ceil, floor)
    local floor = floor or 0
    local val = val + inc
    if val > ceil then
        return floor-1+ (val - ceil)
    elseif val < floor then
        return ceil+1 - (floor - val)
    else
        return val
    end
end

local Snake = class()
-- SnakeInstances = {}
Snake.static.instances = {} --class only shallow copies so this should work
function Snake:init(opt)
--     local args = args or {} --(make calling without args work)
    self.static.instances[#self.static.instances+1] = self--register self
    self.map = M.map
    self.length = opt.length or 5
    self.vel = opt.vel or {x=0,y=0}
    self.body = {}--NOTE keep body vals whole numbers
    self.color = opt.color or M.PXL.colors.blue[2]
    self.headColor = opt.headColor or M.PXL.colors.orange[3]
    self.speed = opt.speed or 6
    self.pos = opt.pos
    self.score = 0
    self.canDie = opt.canDie == nil and true or opt.canDie 
    self.dead = false
    self.selfCollision = opt.selfCollision or false
--     self.startStretched = opt.startStretched or true
    if not self.pos then
        self.pos = {x=math.random(1, self.map.x),y= math.random(1,self.map.y)}
    end
--     for i=1, self.length do --init body at pos (down to up)
--         self.body[i] = {x=self.pos.x, y=self.pos.y+i-1}
--     end
    self:rebuildBody()
end

function Snake:tick(dt) --update function
    if self.dead then return end --abort if dead
    local oldpos = shallowcopy(self.pos)
    --increment pos then compare it against old, both rounded, then handle rebuilding body.
    self.pos.x, self.pos.y = self.pos.x + self.vel.x *dt*self.speed, self.pos.y + self.vel.y *dt*self.speed
    if M.PXL.round(self.pos.x) ~= M.PXL.round(oldpos.x) or M.PXL.round(self.pos.y) ~= M.PXL.round(oldpos.y) then
        self:rebuildBody()
    end
    local head = self.body[1]
    --check for pellet
    if self.map[head.x] and self.map[head.x][head.y] == 1 then --TODO add rollover handler
        self.length = self.length+1 --Yum!
        self.score = self.score+1
        self.map.pellets = self.map.pellets -1
        self.map[head.x][head.y] = 0
        self.speed = self.speed+0.01 --make each pellet boost speed 
    end
    --check for other snake
    local head = self.body[1]
    if self.canDie then
        self.dead = self:collisionCheck()
    end
end

function Snake:collisionCheck(selfcoll)
    local selfcoll = selcoll or self.selfCollision
    local head = self.body[1]
    for i, s in ipairs(self.static.instances) do
        if selfcoll or s ~= self then --ignore self colision (or not)
            for _, seg in ipairs(s.body) do --loop over body and check for collision
                if head.x == seg.x and head.y == seg.y and 
                    seg ~= head then --don't count your own head as a collision
                    return true
                end
            end
        end
    end
    return false
end

function Snake:rebuildBody()
    local new = {}
    new[1] = {x=M.PXL.round(self.pos.x), y=M.PXL.round(self.pos.y)}
    for i=1, math.min(#self.body+1,self.length-1) do--loop through all but the last shifting the body
        new[i+1] = self.body[i] or new[i]
    end
    self.body = new
end

function Snake:draw()
    local function fadecolor(color, x)
       local c = {} --python made me forget if this needs to be done
       local factor = math.exp(1)^(-x/(50+self.length/2)) --change gradient based on len
       for i, v in ipairs(color) do
           c[i] = (v*factor+255*(1-factor)) -- fade to white
       end
       return c
    end
--     love.graphics.setColor(self.color)
    for i = #self.body, 1, -1 do
        local seg = self.body[i]
        love.graphics.setColor(fadecolor(self.color, i))
        if i == 1 then love.graphics.setColor(self.headColor) end --draw head a different color
        if self.dead then love.graphics.setColor(fadecolor(self.color, i+50)) end
        love.graphics.points(seg.x+0.5, seg.y+0.5)
    end
end

local Player = class(Snake) --player snake
function Player:tick(dt)
    --control handling
    if love.keyboard.isDown('up') then
        self.vel = {x=0, y=-1}
        if self._ft then Snake.tick(self, .5/self.speed) end self._ft = nil --force inc by one if this is 1st key read
    elseif love.keyboard.isDown('down') then
        self.vel = {x=0, y=1}
        if self._ft then Snake.tick(self, .5/self.speed) end self._ft = nil
    elseif love.keyboard.isDown('left') then
        self.vel = {x=-1, y=0}
        if self._ft then Snake.tick(self, .5/self.speed) end self._ft = nil
    elseif love.keyboard.isDown('right') then
        self.vel = {x=1, y=0}
        if self._ft then Snake.tick(self, .5/self.speed) end self._ft = nil
    else 
         self._ft = true
    end
    --speed boost cheat
    if love.keyboard.isDown(']') then
        self.speed = 16
    end
    Snake.tick(self, dt)
    if self.dead then M.state = 'dead' end
    --camera handling
    self.map.offset = {
--         x = -M.PXL.round(self.pos.x - self.map.x/2),
--         y = -M.PXL.round(self.pos.y - self.map.y/2) 
        x = -M.PXL.round(self.pos.x - M.screen.x/2),
        y = -M.PXL.round(self.pos.y - M.screen.y/2) 
    }
end

local AI = class(Snake)--the cake is a lie!
function AI:init(opt)
    Snake.init(self, opt)
    self:target() --init target
    self._target, self._avoid = {x=self.pos.x,y=self.pos.y}, {x=0,y=0}
    self.avtimer = Timer:new(opt.avoidtime or 500)
    self.notrunning  = true
    self.avoidRad = opt.avoidrad or 10
    self.avoidOtherAI = opt.avoidOtherAI or false
    if not self.static.instances.ai then self.static.instances.ai = {} end
    self.static.instances.ai[#self.static.instances.ai+1]= self
end
function AI:calcSqVel(dir) -- calculate new velocity from unbound 'dir' and snap it to vertical or horizontal
    local div = math.max(math.abs(dir.x), math.abs(dir.y))--get denominator
    self.vel.x = dir.x/div
    self.vel.y = dir.y/div
    --square movement
    if math.abs(self.vel.x) == 1 then
        self.vel.y = 0
    else
        self.vel.x = 0
    end
end
function AI:target(mode)
    --search for nearest pellet
    local function search(x,y,rad)
        local co = {
            x=M.PXL.round(x-rad),
            y=M.PXL.round(y-rad),
            x2=M.PXL.round(x+rad),
            y2=M.PXL.round(y+rad)
        }
        for ix=co.x, co.x2 do--check top and bottom line
            if self.map[ix] and self.map[ix][co.y]==1 then
                return {x=ix, y=co.y}
            elseif self.map[ix] and self.map[ix][co.y2]==1 then
                return {x=ix, y=co.y2}
            end
        end
        for iy = co.y, co.y2 do --check right and left line
            if self.map[co.x] and self.map[co.x][iy]==1 then
                return {x=co.x, y=iy}
            elseif self.map[co.x2] and self.map[co.x2][iy]==1 then
                return {x=co.x2, y=iy}
            end
        end
        if rad > math.max(self.map.x, self.map.y) then return {x=0,y=0,fail=true} end --search limit
        return search(x,y,rad+1)--search next ring
    end
    
    self._target = search(self.pos.x, self.pos.y, 1)
    if self._target.fail then --stop if all pellets are gone
        self.vel = {x=0,y=0}
        return 
    end
    --calc vel to reach target
    local dir = {x=self._target.x - self.pos.x, y=self._target.y - self.pos.y}
    self:calcSqVel(dir)
end
function AI:avoid()
    local blacklist = {}
    if self.avoidOtherAI then
        for i, l in ipairs(self.static.instances) do --find all other snakes
            if l ~= self then
                for j, v in ipairs(l.body) do--append into bl
                    blacklist[#blacklist+1] = v
                end
            end
        end
    else
        blacklist = M.player.body
    end
    self._avoid = self:circlefind(blacklist, self.avoidRad) --check for anything nearby
    if not self._avoid.fail then --found something
        local dir = {x=-(self._avoid.x - self.pos.x), y=-(self._avoid.y - self.pos.y)}
        self:calcSqVel(dir)
    end
end
function AI:circlefind(list, radlim) -- search in a circular pattern for coords in 'list'
    local radlim = radlim or 10 -- search radius
    local head = self.body[1]
    local function isin(a, b) --check if array 'a' is in array 'b'
--         print(M.PXL.inspect(a))
        for _, v in ipairs(b) do
            local found = true
            for k, iv in pairs(a) do
                if iv ~= v[k] then found = false end
            end
            if found then return true end
        end
        return false
    end
    local round = M.PXL.round -- make typing less annoying
    local function search(x,y,r)
        for a = 0, 2*math.pi, 0.025 do --loop each ring checking for matches
            local cirCoord = {x=round(x + r * math.cos(a)), y=round(y + r * math.sin(a))}
            if isin(cirCoord, list) then
                self.circledebug = {co={x=head.x,y=head.y}, r = r}--debugging visuals
--                 print(inspect(self.circledebug))
                return cirCoord
            end
        end
        if r > radlim then return {x=0,y=0,fail=true} end --search limit
        return search(x,y,r+1)--search next ring
    end
    return search(head.x, head.y, 1)
end
function AI:checkNoSelfCollide(depth, ccw) --alter course to avoid self collisions
    local headptr = self.body[1]
    local headcopy = M.PXL.shallowcopy(headptr)
    local depth = depth or 1
    if depth > 4 then--stuck in a loop
        print("failed to avoid barrier")
        return
    end
    local function inc()
        for k, v in pairs(headptr) do--apply one movement to headcopy
            headptr[k] = v + self.vel[k]
        end
    end
    inc()
    if self:collisionCheck(true) then 
        self.body[1] = headcopy --reset head
        local ccwvel, vel = {x=-self.vel.y, y=self.vel.x} --[[rotate 90 degrees ccw]], {x=self.vel.y, y=-self.vel.x}
        self.vel = ccw and ccwvel or vel --rotate 90 degrees
        inc()
--         print("rotated vel ".. (ccw and 'ccw' or 'cw'))
        if self:checkNoSelfCollide(depth+1) then return true end--check again
        if self:checkNoSelfCollide(depth+1, true) then return true end
    elseif depth > 1 then --in recursion (end yes?)
        self.body[1] = headcopy --reset head
        self.pos = M.PXL.shallowcopy(headptr)
--         print("end")
        return true
    end
    self.body[1] = headcopy --reset head
    return false
end
function AI:tick(dt)
    local head = M.PXL.shallowcopy(self.body[1])
    --avoid self collisions
    self:checkNoSelfCollide()
    Snake.tick(self, dt)
    --square movement algo
    if head ~= self.body[1] then --if moved
        if math.abs(self.vel.x) == 1 then
            if self._target.x == self.body[1].x then
                self:target() --lazyness...
                self:avoid()
            end
        else
            if self._target.y == self.body[1].y then
                self:target()
                self:avoid()
            end
        end
    end
    --check for other snakes to avoid every X
    if self.avtimer:every() then
        self:avoid()
        if self._avoid.fail then
            self:target()
        end
    end
end
function AI:runAll(name, ...) --method on all instances\
    for i, inst in ipairs(self.static.instances.ai) do
        inst[name](inst,...)
    end
end
function M:mapgen(x,y,rate)
    local rate = rate or 0.95
    self.map = {offset={x=0,y=0}}
    self.map.pellets = 0
    self.map.x, self.map.y = self.PXL.round(self.screen.x*x), self.PXL.round(self.screen.y*y)
    for x=1, self.map.x do
        self.map[x] = {}
        for y=1, self.map.y do
            local cell = math.random() > rate and 1 or 0 --0=empty, 1=pellet
            self.map[x][y] = cell --0=empty, 1=pellet
            if cell == 1 then
                self.map.pellets = self.map.pellets+1
            end
        end
    end
end
local function cpuscore()
    local score = 0
    for _, ai in ipairs(Snake.static.instances.ai) do
        score = score + ai.score
    end
    return score/#Snake.static.instances.ai
end
local function cpudead()
    for _, ai in ipairs(Snake.static.instances.ai) do
        if not ai.dead then
            return false
        end
    end
    return true
end
function M:gameinit() --partial game state init
    local mapsize = self.menu.find("Map", true)
    local avoidrad = self.menu.find("avoidR", true)
    local avoidother = self.menu.find("avoidAI", true)
    self:mapgen(mapsize[2], mapsize[3]) --regen mapgen
    local aiCount = self.menu.find("AIcount", true)
    local avoidTime = self.menu.find("avoidT", true)
    
    local aispeed = self.menu.find("AI sp.", true)
    local playerspeed = self.menu.find("P sp.", true)
    Snake.static.instances = {} -- clear old snakes
--     self.player = Player({pos={x=self.map.x/2, y=self.map.y/2}, selfCollision = false, length = 5, speed = playerspeed})--spawn player centered
--     self.ai = AI({color=self.PXL.colors[self.PXL.round(math.random(2,6))][2], headColor = self.PXL.colors.red[2], speed=aispeed, canDie = true, avoidtime=1000, avoidrad=avoidrad})--init ai
    --testing
    self.player = Player({pos={x=self.map.x/2, y=self.map.y/2}, selfCollision = false, length = nil, speed = playerspeed})--spawn player centered
    for i=1, aiCount do
        local name = i==1 and 'ai' or 'ai'..tostring(i)
        self[name] = AI({color=self.PXL.colors[self.PXL.round(math.random(2,6))][2], headColor = self.PXL.colors.red[2], speed=aispeed, canDie = true, avoidtime=avoidTime*100, avoidrad=avoidrad, selfCollision = false, avoidOtherAI = avoidother})--init ai
    end
end
function M:load() -- full game state init
    self.colormap = {
        {0,0,0},
        self.PXL.colors.purple[3]
    }
    self.state = "menu"
    self.menu = {--menu option config
        maxh = 5, --when to scroll down
        pos = 1,
        {name = 'Map', list={{'1x1', 1,1}, {'2x2', 2,2}, {".5x.5", .5, .5}, {".5x2", .5, 2}, {"1.5x3", 1.5, 3}, {"4x4", 4,4}}, selected=1},
        {name = 'AI sp.', range={1, 20}, selected = 4},
        {name = 'P sp.', range={1,20}, selected = 8},
        {name = "VisDebug", list={{'E', true}, {"X", false}}, selected=2},
        {name = 'avoidR', range={1, 20}, selected = 5},
        {name = 'AIcount', range={1, 20}, selected = 4},
        {name = 'avoidT', range={2, 15}, selected = 5},
        {name = "avoidAI", list={{'E', true}, {"X", false}}, selected=2}
    }
    --uncomment for persistant menu state
    if menu then self.menu = menu end menu = self.menu
    
    function self.menu.find(name, getval) --return item with matching name
        for _, v in ipairs(self.menu) do
            if v.name == name then 
                if getval then
                    return v.list and v.list[v.selected] or v.selected
                else
                    return v
                end
            end
        end
    end
    self.menu.pos = 1
    self:gameinit()
end

function M:update(dt)
    if love.keyboard.isDown('q') then GotoMenu() end
    if self.state == 'run' then
        self.player:tick(dt)
        if cpudead() then self.state = 'done' end
    end
    if self.state ~= 'done' then
        self.ai:runAll('tick', dt)
    end
    if self.map.pellets == 0 then
        self.state = 'done'
    end
end
function M:keypressed(key, sc, rep) 
    if self.state == 'done' then
        if key == "r" then
            self.state = "menu"
        end
    elseif self.state == 'menu' then
        if key == 'down' then 
--             self.menu.pos = (self.menu.pos +1)%#self.menu.pos
            self.menu.pos = roll(self.menu.pos, 1, #self.menu, 1)
        elseif key == 'up' then
--             self.menu.pos = self.menu.pos -1
--             if self.menu.pos == 0 then self.menu.pos = #self.menu.pos end
            self.menu.pos = roll(self.menu.pos, -1, #self.menu, 1)
        elseif key == 'right' or key == 'left' then
            local inc = key == "right" and 1 or -1
            local line = self.menu[self.menu.pos]
            if line.range then
                line.selected = roll(line.selected, inc, line.range[2], line.range[1])
            else
                line.selected = roll(line.selected, inc, #line.list, 1)
            end
        elseif key == "return" then
            self.state = "run"
            self:gameinit()
        end
    end
end
function M:draw()
    --draw score
    if self.state == 'run' or self.state == 'done' then
        local renderDebug = self.menu.find("VisDebug", true)[2]
        love.graphics.setColor(self.PXL.colors.gray[3])
        self.PXL.printCenter(tostring(self.player.score).."vs"..tostring(M.PXL.round(cpuscore())),1)
        love.graphics.setColor(self.PXL.colors.gray[2])
        self.PXL.printCenter(tostring(self.map.pellets).." "..tostring(self.map.x).."x"..tostring(self.map.y), 5)
        love.graphics.push()
        love.graphics.translate(self.map.offset.x, self.map.offset.y)
        
        if renderDebug then--draw ai range debugging crap
            for _, ai in ipairs(Snake.static.instances.ai) do
                love.graphics.setColor({0,255,255,50})
                if ai.circledebug and ai.circledebug.r then 
                    love.graphics.ellipse('line', ai.circledebug.co.x, ai.circledebug.co.y, ai.circledebug.r, ai.circledebug.r)
                end
            end
        end
        for x=1-self.map.offset.x, self.screen.x-self.map.offset.x do--draw map
            for y=1-self.map.offset.y, self.screen.y-self.map.offset.y do
                if self.map[x] and self.map[x][y] and self.map[x][y] ~=0 then
                    love.graphics.setColor(self.colormap[1+self.map[x][y]])
                    love.graphics.points(0.5+x, 0.5+y)
                end
            end
        end
        for _, snake in ipairs(Snake.static.instances) do
            snake:draw()
        end
--         M.ai:runall('draw')
        if renderDebug then --show ai targeting
            for _, ai in ipairs(Snake.static.instances.ai) do
                love.graphics.setColor({255,0,0,200})
                love.graphics.points(ai._target.x+.5, ai._target.y+.5)
                love.graphics.setColor({255,255,0,200})
                if not ai._avoid.fail then love.graphics.points(ai._avoid.x+.5, ai._avoid.y+.5) end
            end
        end
        
        love.graphics.pop()
    end
    if self.state == 'dead' then
        love.graphics.setColor({255,0,0,100})
        love.graphics.rectangle('fill',0,0,self.screen.x,self.screen.y)
        love.graphics.setColor({255,255,255,255})
        self.PXL.printCenter("You Died")
    elseif self.state == 'done' then
        love.graphics.setColor({255,255,255,70})
        love.graphics.rectangle('fill',0,0,self.screen.x,self.screen.y)
        love.graphics.setColor({255,255,255,255})
        if self.player.score > cpuscore() or cpudead() then
            self.PXL.printCenter("You Win!")
        else
            self.PXL.printCenter("CPU Wins")
        end
    elseif self.state == 'menu' then
        for i, line in ipairs(self.menu) do
            local offset = self.menu.pos > self.menu.maxh and self.menu.pos - self.menu.maxh or 0 --calc offset if needed
            love.graphics.setColor(i == self.menu.pos and self.PXL.colors.purple[3] or self.PXL.colors.gray[5])
            self.PXL.printCenter(line.name .." ".. tostring(line.range and line.selected or line.list[line.selected][1]), i-offset)
--             self.PXL.printCenter({self.PXL.colors.gray[6], line.name, self.PXL.colors.gray[5], line.range and selected or line.list[line.selected]}, i)
        end
    end
end
return M
