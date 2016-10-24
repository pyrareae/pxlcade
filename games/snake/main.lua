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
function Snake:init(args)
    local args = args or {} --(make calling without args work)
    self.map = M.map
    self.length = args.length or 5
    self.vel = args.vel or {x=0,y=0}
    self.body = {}--NOTE keep body vals whole numbers
    self.color = args.color or M.PXL.colors.blue[2]
    self.headColor = args.headColor or M.PXL.colors.orange[3]
    self.speed = args.speed or 6
    self.pos = args.pos
    if not self.pos then
        self.pos = {x=math.random(1, self.map.x),y= math.random(1,self.map.y)}
    end
--     for i=1, self.length do --init body at pos (down to up)
--         self.body[i] = {x=self.pos.x, y=self.pos.y+i-1}
--     end
    self:rebuildBody()
end

function Snake:tick(dt) --update function
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
        self.map[head.x][head.y] = 0
        return true
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
       for i, v in ipairs(color) do
           c[i] = v*math.exp(1)^(-x/85)
       end
       return c
    end
--     love.graphics.setColor(self.color)
    for i = #self.body, 1, -1 do
        local seg = self.body[i]
        love.graphics.setColor(fadecolor(self.color, i))
        if i == 1 then love.graphics.setColor(self.headColor) end --draw head a different color
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
    Snake.tick(self, dt)
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
    self.timer = Timer:new(200)
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
        if rad > self.map.x then return false end --search limit
        return search(x,y,rad+1)--search next ring
    end
    self._target = search(self.pos.x, self.pos.y, 1)
    if not self._target then --stop if all pellets are gone
        self.vel = {x=0,y=0}
        return 
    end
    --calc vel to reach target
    local dir = {x=self._target.x - self.pos.x, y=self._target.y - self.pos.y}
    local div = math.max(math.abs(dir.x), math.abs(dir.y))--get denominator
    self.vel.x = dir.x/div
    self.vel.y = dir.y/div
end
function AI:tick(dt)
    --retarget every x ms
    if self.timer:every() then
        self:target()
    end
    Snake.tick(self, dt)
--     if self._target and self.map[self._target.x][self._target.y] ~= 1 then 
--         self:target()--retarget if pellet is gone
--     end
end

function M:load()
    M.colormap = {
        {0,0,0},
        M.PXL.colors.purple[3]
    }
    M.map = {offset={x=0,y=0}}
    M.map.x, M.map.y = M.screen.x*1.5, M.screen.y*1.5 --double screen size
    --gen empty map
    for x=1, M.map.x do
        M.map[x] = {}
        for y=1, M.map.y do
            M.map[x][y] = math.random() > 0.95 and 1 or 0 --0=empty, 1=pellet
        end
    end
    --init player..
    M.player = Player({pos={x=self.map.x/2, y=self.map.y/2}})--spawn player centered
    M.ai = AI({color=M.PXL.colors.cyan[2], headColor = M.PXL.colors.red[2], speed=4})--init ai
end

function M:update(dt)
    if love.keyboard.isDown('q') then GotoMenu() end
    M.player:tick(dt)
    M.ai:tick(dt)
end
function M:draw()
    love.graphics.push()
    love.graphics.translate(self.map.offset.x, self.map.offset.y)
    for x=1-self.map.offset.x, self.screen.x-self.map.offset.x do--draw map
        for y=1-self.map.offset.y, self.screen.y-self.map.offset.y do
            if M.map[x] and M.map[x][y] then
                love.graphics.setColor(M.colormap[1+M.map[x][y]])
                love.graphics.points(0.5+x, 0.5+y)
            end
        end
    end
    M.player:draw()
    M.ai:draw()
    --show ai target
    love.graphics.setColor({255,0,0,127}); if M.ai._target.x then love.graphics.points(M.ai._target.x+.5, M.ai._target.y+.5) end
    love.graphics.pop()
end
return M
