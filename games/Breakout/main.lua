local timer = require "timer"
local M = {
name = "Breakout",
c = {}
}
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
--             this.vel = {x = math.random(-30,30), y = 30}
            this.vel = {x = 0, y = 30}
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
                if not this.y<=0 then --bottom
                    state = 'bottom'
                end
                this.vel.y = -this.vel.y 
                this:move(dt)
            end
            --check for paddle
            if this:gety()+this.radius >= self.player.y and this:getx()+this.radius >= self.player.x and this:getx()-this.radius < self.player.x+self.player.size.x then
                print('this.y: '..this.y..', player.y: '..self.player.y)
                this.y = self.player.y-(this.radius*2+1)
                this.vel.y = -this.vel.y
                this:move(dt)
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
end

return M
