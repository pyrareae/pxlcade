local timer = require "timer"
local M = {
name = "Breakout",
c = {},
bricks = {}
}
local function boxcoll(x,y,xb,yb,x2,y2,x2b,y2b)--box collision check http://gamedev.stackexchange.com/questions/29786/a-simple-2d-rectangle-collision-algorithm-that-also-determines-which-sides-that
    local w = 0.5*((xb-x)+(x2b-x2))
    local h = 0.5*((yb-y)+(y2b-y2))
    local dx = x+(xb-x)/2 - x2+(x2b-x2)/2
    local dy = y+(yb-y)/2 - y2+(y2b-y2)/2

    if (math.abs(dx) <= w and math.abs(dy) <= h) then
        local wy = w * dy
        local hx = h * dx

        if (wy > hx) then
            if (wy > -hx) then
                return 'top'
            else
                return 'left'
            end
        else
            if (wy > -hx) then
                return 'right'
            else
                return 'bottom'
            end
        end
    end
    return nil
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
    self.c.paddle = self.PXL.colors.gray[6]
    --init player
    self.player = {
        x = self.screen.x/2,
        y = self.screen.y-4,
        size = {x=15,y=2},
        speed = 100,
        getx = function(self)
            return math.floor(self.x-self.size.x/2)
        end,
        gety = function(self)
            return math.floor(self.y-self.size.y/2)
        end
    }
    self.state = 'run'
    --init ball
    self.ball = {
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
            end
            if this.y <=0 or this.y+this.radius*2 >= self.screen.y then
                if not (this.y <= 0) then --bottom
                    state = 'bottom'
                end
                this.vel.y = -this.vel.y 
                this:move(dt)
            end
            --check for paddle
            if this:gety()+this.radius+1 >= self.player.y and this:getx()+this.radius >= self.player.x and this:getx()-this.radius < self.player.x+self.player.size.x then
                this.y = self.player.y-(this.radius*2+1)
                this.vel.y = -this.vel.y
                this:move(dt)
                self.c.ball = self.c.paddle
            end
            --check for bricks
            for i, row in ipairs(self.bricks) do
                for i2, brick in ipairs(row) do
                    local side = nil
                    if brick then side = boxcoll(brick.pos.x, brick.pos.y, brick.pos.xb, brick.pos.yb, this.x, this.y, this.x+2*this.radius, this.y+2*this.radius) end
                    if side then
                        print(side)
                        if side == "bottom" then
                            this.vel.y = - this.vel.y
--                             this.y = brick.pos.yb+1
                        elseif side == "top" then
                            this.vel.y = - this.vel.y
--                             this.y = brick.pos.y - (2*this.radius+1)
                        elseif side == "right" then
                            this.vel.x = - this.vel.x
--                             this.x = brick.pos.x + (2*this.radius+1)
                        elseif side == "left" then
                            this.vel.x = - this.vel.x
--                             this.x = brick.pos.xb+1
                        end
                        this:move(dt, true)
                        self.c.ball = brick.color
                        table.remove(self.bricks[i], i2)
                    end
                end
            end
        end,
        move = function(this, dt, nocheck)
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
    --draw ball
    love.graphics.setColor(self.c.ball)
    love.graphics.rectangle('fill', self.ball.x, self.ball.y, 1+self.ball.radius*2, 1+self.ball.radius*2)
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
