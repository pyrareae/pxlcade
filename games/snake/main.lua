local class = require('lib.class')
local M = {
    name="Snake",
}

Snake = class()
function Snake:init(args)
    local args = args or {} --lua weirdness. (make calling without args work with named arg setup)
    self.map = M.map
    self.length = args.length or 5
    self.vel = args.vel or {x=0,y=0}
    self.body = {}--NOTE keep body vals whole numbers
    self.color = args.color or M.PXL.colors.blue[2]
    self.headColor = args.headColor or M.PXL.colors.orange[3]
    self.speed = args.speed or 6
    self.pos = args.pos
    if not pos then
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
    if M.map[head.x][head.y] == 1 then
        self.length = self.length+1 --Yum!
        M.map[head.x][head.y] = 0
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

function Snake:draw(offset)
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
        love.graphics.points(seg.x+0.5+offset.x, seg.y+0.5+offset.y)
    end
end

Player = class(Snake) --player snake
function Player:tick(dt)
    --control handling
    if love.keyboard.isDown('up') then
        self.vel = {x=0, y=-1}
    elseif love.keyboard.isDown('down') then
        self.vel = {x=0, y=1}
    elseif love.keyboard.isDown('left') then
        self.vel = {x=-1, y=0}
    elseif love.keyboard.isDown('right') then
        self.vel = {x=1, y=0}
    end
    Snake.tick(self, dt)
end

function M:load()
    M.colormap = {
        {0,0,0},
        M.PXL.colors.red[3]
    }
    M.map = {offset={}}
--     M.map.x, M.map.y = 100, 80
    M.map.x, M.map.y = M.screen.x, M.screen.y --just until camera in written
    M.map.offset.x, M.map.offset.y = 0,0
    --gen empty map
    for x=1, M.map.x do
        M.map[x] = {}
        for y=1, M.map.y do
            M.map[x][y] = math.random() > 0.95 and 1 or 0 --0=empty, 1=pellet
        end
    end
    --init player..
    M.player = Player()
end

function M:update(dt)
    M.player:tick(dt)
end
function M:draw()
    for x=1+M.map.offset.x, M.screen.x do--draw visible map accounting for offset
        for y=1+M.map.offset.y, M.screen.y do
            if M.map[x][y] then
                love.graphics.setColor(M.colormap[1+M.map[x][y]])
                love.graphics.points(0.5+x, 0.5+y)
            end
        end
    end
    M.player:draw(M.map.offset)
end
return M
