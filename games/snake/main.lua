local class = require('lib.class')
local Timer = require('timer')
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

local Snake = class()
SnakeInstances = {}
function Snake:init(args)
    local args = args or {} --(make calling without args work)
    SnakeInstances[#SnakeInstances+1] = self--register self
    self.map = M.map
    self.length = args.length or 5
    self.vel = args.vel or {x=0,y=0}
    self.body = {}--NOTE keep body vals whole numbers
    self.color = args.color or M.PXL.colors.blue[2]
    self.headColor = args.headColor or M.PXL.colors.orange[3]
    self.speed = args.speed or 6
    self.pos = args.pos
    self.score = 0
    self.canDie = args.canDie == nil and true or args.canDie 
    self.dead = false
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
        for i, s in ipairs(SnakeInstances) do
            if s ~= self then --ignore self colision
                for _, seg in ipairs(s.body) do --loop over body and check for collision
                    if head.x == seg.x and head.y == seg.y then
                        self.dead = true
                    end
                end
            end
        end
    end
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
function AI:init(...)
    Snake.init(self, ...)
    self:target() --init target
--     self.timer = Timer:new(200)
end
function AI:target()
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
function AI:tick(dt)
--square movement algo
    local head = M.PXL.shallowcopy(self.body[1])
    Snake.tick(self, dt)
    if head ~= self.body[1] then --if moved
        if math.abs(self.vel.x) == 1 then
            if self._target.x == self.body[1].x then
                self:target() --lazyness...
            end
        else
            if self._target.y == self.body[1].y then
                self:target()
            end
        end
    end
    
end

function M:load()
    SnakeInstances = {} -- clear old snakes
    M.colormap = {
        {0,0,0},
        M.PXL.colors.purple[3]
    }
    M.state = "run"
    M.map = {offset={x=0,y=0}}
    M.map.x, M.map.y = M.PXL.round(M.screen.x*math.random(0.5,2)), M.PXL.round(M.screen.y*math.random(0.5,2))
    M.map.pellets = 0
    --gen empty map
    for x=1, M.map.x do
        M.map[x] = {}
        for y=1, M.map.y do
            local cell = math.random() > 0.95 and 1 or 0 --0=empty, 1=pellet
            M.map[x][y] = cell --0=empty, 1=pellet
            if cell == 1 then
                M.map.pellets = M.map.pellets+1
            end
        end
    end
    --init player..
    M.player = Player({pos={x=self.map.x/2, y=self.map.y/2}})--spawn player centered
    M.ai = AI({color=M.PXL.colors.cyan[2], headColor = M.PXL.colors.red[2], speed=5, canDie = false})--init ai
    print(M.ai.canDie)
end

function M:update(dt)
    if love.keyboard.isDown('q') then GotoMenu() end
    if self.state == 'run' then
        self.player:tick(dt)
    end
    if self.state ~= 'done' then
        self.ai:tick(dt)
    end
    if self.map.pellets == 0 then
        self.state = 'done'
    end
end
function M:draw()
    --draw score
    love.graphics.setColor(self.PXL.colors.gray[3])
    self.PXL.printCenter(tostring(self.player.score).."vs"..tostring(self.ai.score),1)
    love.graphics.setColor(self.PXL.colors.gray[2])
    self.PXL.printCenter(tostring(self.map.pellets).." "..tostring(self.map.x).."x"..tostring(self.map.y), 5)
    love.graphics.push()
    love.graphics.translate(self.map.offset.x, self.map.offset.y)
    for x=1-self.map.offset.x, self.screen.x-self.map.offset.x do--draw map
        for y=1-self.map.offset.y, self.screen.y-self.map.offset.y do
            if self.map[x] and self.map[x][y] and self.map[x][y] ~=0 then
                love.graphics.setColor(self.colormap[1+self.map[x][y]])
                love.graphics.points(0.5+x, 0.5+y)
            end
        end
    end
    for _, snake in ipairs(SnakeInstances) do
        snake:draw()
    end
--     love.graphics.setColor({255,0,0,127}); if self.ai._target then love.graphics.points(self.ai._target.x+.5, self.ai._target.y+.5) end --show ai target
    love.graphics.pop()
    if self.state == 'dead' then
        love.graphics.setColor({255,0,0,100})
        love.graphics.rectangle('fill',0,0,self.screen.x,self.screen.y)
        love.graphics.setColor({255,255,255,255})
        self.PXL.printCenter("You Died")
    elseif self.state == 'done' then
        love.graphics.setColor({255,255,255,70})
        love.graphics.rectangle('fill',0,0,self.screen.x,self.screen.y)
        love.graphics.setColor({255,255,255,255})
        if self.player.score > self.ai.score then
            self.PXL.printCenter("You Win!")
        else
            self.PXL.printCenter("CPU Wins")
        end
    end
end
return M
