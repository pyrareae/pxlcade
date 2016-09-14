local timer = require "timer"
local M = {
name = "Breakout",
c = {},
bricks = {}
}

function shallowcopy(orig) -- http://lua-users.org/wiki/CopyTable
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

local function boxcoll(x,y,xb,yb,x2,y2,x2b,y2b)--box collision
    if x < x2b and
         x2 < xb and
         y < y2b and
         y2 < yb then
--         local a = {x = x+(xb-x)/2, y = y+(yb-y)/2}
--         local b = {x = x2+(x2b-x2)/2, y = y2+(y2b-y2)/2}
        local pen = {up = 0, down = 0, right = 0, left = 0}
        pen['up'] = y - y2b
        pen['down'] = yb - y2
        pen['left'] = x - x2b
        pen['right'] = xb - x2
        local res = {'', 999}
        for k,v in pairs(pen) do
--             print(k..math.abs(v))
            if res[2] > math.abs(v) then
                res = {k, math.abs(v)}
            end
        end
        return res[1]
    end
end
local Brick = {
    new = function(self, color, x, y, xb, yb)
        o = {}
        setmetatable(o, self)
        o.color = color
        o.pos = {x=x,y=y,xb=xb,yb=yb,length=xb-x+1,height=yb-y+1}
        return o
    end
}
Brick.__index = Brick
function M:buildbricks() 
    local width = 8
    local height = 4
    local stack = 4
    local hue = math.random(2, 7)
    self.bricks = {}
    for y=1, stack do
        self.bricks[y] = {}
        local curr = self.bricks[y]
        for x=1, width do
            curr[x] = Brick:new(self.PXL.colors[hue][math.random(2,4)], (x-1)*width, (y-1)*height, x*width-1, y*height-1)
        end
    end
end
local function inc(num, amount, a, b, rollback)--smart incrementer
    local num = num + amount
    if not a and not b then
        num = num + amount
    elseif rollback then
        if num > b then num = a
        elseif num < a then num = b end
    else
        if num > b then num = b
        elseif num < a then num = a end
    end
    return num
end
function M:load()
    --setup main colors
    self.c.ball = self.PXL.colors.blue[2]
--     self.c.paddle = self.PXL.colors.gray[6]
    self.c.paddle = self.PXL.colors[math.random(2,7)][4]
    --init player
    self.player = {
        score = {points = 0, lives = 3, deaths = 0},
        x = nil,
        y = self.screen.y-4,
        size = {x=15,y=2},
        speed = 60,
        getx = function(self)
            return math.floor(self.x-self.size.x/2)
        end,
        gety = function(self)
            return math.floor(self.y-self.size.y/2)
        end,
        die = function(this)
            this.score.deaths = this.score.deaths + 1
            if this.score.deaths > this.score.lives then
                self.state = 'dead'
            end
        end
    }
    self.player.x = self.screen.x/2 - self.player.size.x/2
    self.state = 'run'
    --init ball
    self.ball = {
        bounce = love.audio.newSource(self.cwd.."bounce.wav"),
        traillen = 5,
        trail = {},
        draw = function(this)
            local x,y, lx, ly = math.floor(this.x+0.5), math.floor(this.y+0.5)
            if this.trail[1] then
                lx, ly = this.trail[1].x, this.trail[1].y
            end
            if (x ~= lx or y ~= ly) then
                if #this.trail >= this.traillen then table.remove(this.trail, this.traillen) end
                table.insert(this.trail,1,{x=x,y=y,color=self.c.ball})
            end
            for i=#this.trail,1,-1 do
                local b = this.trail[i]
                local color = shallowcopy(b.color)
                color[4] = i ~= 1 and 50 or 255
                love.graphics.setColor(color)
                love.graphics.rectangle('fill', b.x, b.y, 1+this.radius*2, 1+this.radius*2)
                color = nil
            end
        end,
        reset = function(this)
            this.x = self.screen.x/2
            this.y = self.screen.y*0.75
            this.vel = {x = math.random(-20,20), y = 20}
--             this.vel = {x = 10, y = 10}
        end,
        radius = 1,
        getx = function(self) return math.floor(self.x+self.radius) end,--return center coord
        gety = function(self) return math.floor(self.y+self.radius) end,
        collcheck = function(this, dt)
            --check for walls
            if this.x <=0 or this.x+this.radius*2 >= self.screen.x then
                this.vel.x = -this.vel.x
                this:move(dt)
                this.bounce:setPitch(1.2)
                this.bounce:play()
            end
            if this.y <=0 or this.y+this.radius*2 >= self.screen.y then
                if not (this.y <= 0) then --bottom
                    self.player:die()
                    this:reset()
                end
                this.vel.y = -this.vel.y 
                this:move(dt)
                this.bounce:setPitch(1.3)
                this.bounce:play()
            end
            --check for paddle
            if this:gety()+this.radius+1 >= self.player.y and this:getx()+this.radius >= self.player.x and this:getx()-this.radius < self.player.x+self.player.size.x then
                this.y = self.player.y-(this.radius*2+1)
                this.vel.y = -this.vel.y
                local veer = (this:getx() - (self.player.x+self.player.size.x/2))*4
                this.vel.x = (this.vel.x + veer*2)/3
                this:move(dt)
                self.c.ball = self.c.paddle
                this.bounce:setPitch(1.5)
                this.bounce:play()
            end
            --check for bricks
            local bricks = false
            for i, row in ipairs(self.bricks) do
                for i2, brick in ipairs(row) do
                    bricks = true
                    local side = nil
                    if brick then side = boxcoll(this.x, this.y, this.x+this.radius*2+1, this.y+this.radius*2+1, brick.pos.x, brick.pos.y, brick.pos.xb, brick.pos.yb) end
                    if side then
--                         print(side)
                        if side == "up" then--top
                            this.vel.y = - this.vel.y
                            this.y = brick.pos.yb+1
                        elseif side == "down" then--bottom
                            this.vel.y = - this.vel.y
                            this.y = brick.pos.y - (2*this.radius+1)
                        elseif side == "left" then--right
                            this.vel.x = - this.vel.x
                            this.x = brick.pos.xb+1
                        elseif side == "right" then--left
                            this.vel.x = - this.vel.x
                            this.x = brick.pos.x-this.radius*2-2
                        end
                        --hit brick, do hit brick stuff here
                        this:move(dt, true)
                        this.bounce:setPitch(1.7)
                        this.bounce:play()
                        self.c.ball = brick.color
                        self.player.score.points = self.player.score.points+1
                        table.remove(self.bricks[i], i2)
                    end
                end
            end
            if not bricks then 
                local vel = this.vel.y*1.25
                this:reset()
                self:buildbricks()
                this.vel.y = vel
            end
        end,
        move = function(this, dt, nocheck) --NOTE: there is a bug where up speed is greater than down speed
            this.x = inc(this.x, this.vel.x*dt, 0, this.x+this.radius*2)
            this.y = inc(this.y, this.vel.y*dt, 0, this.y+this.radius*2)
            if not nocheck then
                this:collcheck(dt)
            end
        end
    }
    self.ball:reset()
    self:buildbricks()
end
function M:mousemoved(x,y,dx,dy,touch)
    
end
function M:keypressed(key, sc, r)
    if key == 'r' and not r then
        self:load()
    end
end
function M:update(dt)
    self.ball:move(dt)
    if love.keyboard.isDown("right") then
        self.player.x = inc(self.player.x, self.player.speed*dt, 1, self.screen.x-self.player.size.x)
    elseif love.keyboard.isDown("left") then
        self.player.x = inc(self.player.x, -self.player.speed*dt, 1, self.screen.x-self.player.size.x)
    elseif love.keyboard.isDown('q') then
        GotoMenu()
    end
    
end
function M:draw()
    love.graphics.setLineWidth(1)
    love.graphics.setLineStyle('rough')
    --game over screen
    if self.state == 'dead' then
        love.graphics.printf({self.colors.red[2], "Game Over\n", self.colors.white, string.format("Score: %d\nRestart..R\nQuit..Q", self.score.points)}, 0, 1, self.screen.x, 'center')
        return
    end
    --draw text
    love.graphics.setColor(self.PXL.colors.gray[3])
    love.graphics.printf("score: "..self.player.score.points, 0, 23, self.screen.x, 'center')
    love.graphics.printf(string.format("lives: %i/%i", self.player.score.lives-self.player.score.deaths, self.player.score.lives), 0, 30, self.screen.x, 'center')
    --draw ball
    self.ball:draw()
--     love.graphics.setColor(self.c.ball)
--     love.graphics.rectangle('fill', self.ball.x, self.ball.y, 1+self.ball.radius*2, 1+self.ball.radius*2)
    --draw paddle
    love.graphics.setColor(self.c.paddle)
    love.graphics.rectangle('line', self.player.x, self.player.y, self.player.size.x, self.player.size.y)
    --draw bricks
    for _, row in ipairs(self.bricks) do
        for _, brick in ipairs(row) do
            love.graphics.setColor(brick.color)
            love.graphics.rectangle('fill', brick.pos.x, brick.pos.y, brick.pos.length, brick.pos.height)
            love.graphics.setLineWidth(1)
            love.graphics.setColor({255,255,255,100})
            love.graphics.line(brick.pos.xb+1, brick.pos.y+1, 
                                brick.pos.x+1, brick.pos.y+1,
                                brick.pos.x+1, brick.pos.yb+1)--shadow/highlights
            love.graphics.setColor({0,0,0,100})
            love.graphics.line(brick.pos.xb+1, brick.pos.y+1,
                                brick.pos.xb+1, brick.pos.yb+1,
                                brick.pos.x+1, brick.pos.yb+1)
        end
    end
end

return M
