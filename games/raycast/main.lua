local class = require 'lib.class' -- yay fake classes!
local M = {
    name = "raycast"
}
local Player = class()
function Player:init(x,y,dir) 
    self.x = x
    self.y = y
    self.direction = dir
end
local Map = class()
function Map:init(size)
    self.size = size
    self.wallGrid = {}
end
M:load()
    M:
end
M:draw()


return M
