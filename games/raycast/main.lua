local class = require 'lib.class'
local ins = require 'lib.inspect'
local M = { 
    name = "raycast",
    color = {0,255,75,255}
}
local CIRCLE = math.pi
local INF = 1/0
local function TableConcat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end
--based/ported from http://www.playfuljs.com/a-first-person-engine-in-265-lines/
local Player = class()
function Player:init(x,y,dir) 
    self.x = x
    self.y = y
    self.direction = dir
end
function Player:rotate(angle)
    self.direction = (self.direction + angle + CIRCLE)
end
function Player:walk(distance, map)
    local dx = math.cos(self.direction) * distance
    local dy = math.sin(self.direction) * distance
    if map:get(self.x + dx, self.y) <= 0 then self.x = self.x + dx end
    if map:get(self.x, self.y + dy) <= 0 then self.y = self.y + dy end
end
function Player:update(map, seconds)
    if love.keyboard.isDown('left')  then self:rotate(-math.pi * seconds) end
    if love.keyboard.isDown('right') then self:rotate(math.pi * seconds) end
    if love.keyboard.isDown('up')    then self:walk(3*seconds,map) end
    if love.keyboard.isDown('down')  then self:walk(-3*seconds,map) end
end
local Map = class()
function Map:init(size)
    self.size = size
    self.wallGrid = {}
    self.light = 0
end
function Map:randomize()
    for i=1,self.size*self.size do
        self.wallGrid[i] = math.floor(math.random(0,1)+0.3)
    end
end
function Map:get(x,y)
    x = math.floor(x)
    y = math.floor(y)
    if x<0 or x>self.size-1 or y<0 or y>self.size-1 then return -1 end
    return self.wallGrid[y*self.size + x]
end
function Map:cast(point, angle, range)
    local sin = math.sin(angle)
    local cos = math.cos(angle)
    local noWall = {length2 = INF}
    
    local function step(rise, run, x, y, inverted)
        if (run == 0) then return noWall end
        local dx = run > 0 and math.floor(x + 1) - x or math.ceil(x - 1) - x
        local dy = dx * (rise / run)
        return {
            x= inverted and y + dy or x + dx,
            y= inverted and x + dx or y + dy,
            length2= dx * dx + dy * dy
        }
    end
    
    local function inspect(step, shiftX, shiftY, distance, offset)
        local dx = cos < 0 and shiftX or 0
        local dy = sin < 0 and shiftY or 0
        step.height = self:get(step.x - dx, step.y - dy)
        step.distance = distance + math.sqrt(step.length2)
        if (shiftX) then step.shading = cos < 0 and 2 or 0
        else step.shading = sin < 0 and 2 or 1 end
        step.offset = offset - math.floor(offset)
        return step
    end 
    
    local function ray(origin)
        local list = {}
        local origin = origin
        for i=1, 1000 do --dirty hack
            local stepX = step(sin, cos, origin.x, origin.y)
            local stepY = step(sin, cos, origin.y, origin.x, true)
            local nextStep = (stepX.length2 < stepY.length2) and
                    inspect(stepX, 1, 0, origin.distance, stepX.y) or
                    inspect(stepY, 0, 1, origin.distance, stepY.x)
--             if nextStep.distance > range then return {origin}
--             else return TableConcat({origin}, ray(nextStep)) end
--             print (nextStep.distance)
            if nextStep.distance > range then return list
            else
                table.insert(list, origin)
                origin = nextStep
            end
        end
        print('ray error')
        return list
    end
--     print('-----')
    return ray({x=point.x, y=point.y, height=0, distance=0})
end
function Map:update(seconds) 
    if (self.light > 0) then self.light = math.max(self.light - 10 * seconds, 0)
    elseif (math.random() * 5 < seconds) then self.light = 2 end
end
local Camera = class()
function Camera:init(resolution, focalLength)
    self.width = M.screen.x
    self.height = M.screen.y
    self.resolution = resolution
    self.spacing = self.width / resolution
    self.focalLength = focalLength or 0.8
    self.range = 7
    self.lightRange = 5
    self.scale = (self.width + self.height) / 1200
end
function Camera:render(player,map)
    self:drawColumns(player, map)
end
function Camera:drawColumns(player, map)
    for column = 0, self.resolution do
        local x = column / self.resolution - 0.5
        local angle = math.atan2(x, self.focalLength)
        local ray = map:cast(player, player.direction+angle, self.range)
        self:drawColumn(column, ray, angle, map)
    end
end
function Camera:drawColumn(column, ray, angle, map)
--     local texture = map.wallTexture
    local left = math.floor(column * self.spacing)
    local width = math.ceil(self.spacing)
    local hit = 1
    while hit < #ray and ray[hit].height and ray[hit].height <= 0 do hit = hit+1 end
    for s = #ray -1, 0, -1 do
        local step = ray[s]
        if (s == hit) then
--             local x = math.floor(texture.width * step.offset)
            local wall = self:project(step.height, angle, step.distance)
            love.graphics.setColor(M.color)
            love.graphics.rectangle('fill', left, wall.top, width, wall.height)
            return
        end
    end
    love.graphics.setColor({255,0,0,75}) --error
    love.graphics.rectangle('fill', left, M.PXL.screen.y/2, width, 1)  
    print(ins(ray))
end
function Camera:project(height, angle, distance)
    local z = distance + math.cos(angle)
    local wallHeight = self.height * height / z
    local bottom = self.height / 2 * (1+1/z)
    return {
        top=bottom-wallHeight,
        height=wallHeight
    }
end
function M:load()
    M.player = Player(15.3, -1.2, math.pi * 0.3)
    M.map = Map(32)
    M.camera = Camera(100, 0.2)
    M.map:randomize()
end
function M:update(dt)
    if love.keyboard.isDown('q') then GotoMenu() end
    M.map:update(dt)
    M.player:update(M.map, dt)
end
function M:draw()
    M.camera:render(M.player, M.map)
end

return M
