local M = {}
M.name = "Pong"
M.fx = {
    trail = true,
    sparkle = true,
    grain = true
}
M.player1 = {
    y = 0,
    x = 0,
    len = 10,
    thickness =3,
    speed = 75
}
M.player2 = {
    y = 0,
    x = 0,
    len = 10,
    thickness =3,
    speed = 75
}
M.ball = {
    x = 0,
    y = 0,
    xVel = 0,
    yVel = 0,
    size = 3,
}
M.colors = {
    white =  {255,255,255},
    gray =   {200,200,200},
    darkGray={100,100,100},
    violet = {150,150,255},
    pink =   {255,70,170}
}
M.difficulty = 2
M.difficulties = {"easy", "normal", "hard"}
M.multiplayer = false
M.menuline = 0
M.lastmouse = 0
M.score = {
    player = 0,
    deaths = 0,
    cpu = 0,
    limits = {5,3,1},
    limit = nil
}
function M:resetball()
    self.ball.x = self.screen.x/2
    self.ball.y = self.screen.y/2
    self.ball.xVel = (math.random(-1,1) > 0) and 35 or -35
    self.ball.yVel = math.random(-15,15)
end
function M:initgame() --init/reset game state
    M:resetball()
    self.inmenu = true
    self.alive = true
    self.player1.x = self.collborder.right
    self.player1.y = self.screen.y/2
    self.player2.y = self.screen.y/2
    self.player2.x = self.collborder.left-self.player2.thickness
    self.score.player = 0
    self.score.deaths = 0
    self.score.cpu = 0
end
M.cwd = nil -- this should be set by main code
function M:load()
    --these two are here so that screen exists when run
    M.collborder = {
        left =  M.player2.thickness + 4,
        right = M.screen.x - M.player1.thickness - 3
    }
--     M.canvas = M.PXL.screen.canvas --quick ref change xxx
    local cwd = self.cwd
    self.font = love.graphics.newFont(cwd.."AerxFont.ttf", 16)
    self.sounds = {
        bounce = love.audio.newSource(cwd.."bounce.wav")
    }
    self.kittyimg = love.graphics.newImage(cwd.."kitty.png")
--     self.pixelimg = love.graphics.newImage(cwd.."pixelmask.png")
    local spk = love.graphics.newImage(cwd.."spark.png")
    self.trail = love.graphics.newParticleSystem(spk, 60)
    self.trail:setParticleLifetime(1,2)
    self.trail:setEmissionRate(20)
    self.trail:setSizes(0.3, 1)
    self.trail:setSizeVariation(1)
    self.trail:setLinearAcceleration(-20,-20,20,20)
    self.trail:setColors(170,50,255,255,255,0,0,180)
    self:initgame()
end

function M:keypressed(key, sc, r)
    local length = table.getn(self.difficulties)
    if not r and self.inmenu then
        if key == "up" or key == "down" then
            self.menuline = self.menuline == 0 and 1 or 0
        elseif key == "return" then 
            self.score.limit = self.score.limits[self.difficulty]
            self.inmenu = false
        end
        if self.menuline == 0 then
            if key == "right" then
                -- (test) ? cond1 : cond2
                self.difficulty = (self.difficulty+1 > length) and 1 or self.difficulty+1
            elseif key == "left" then
                self.difficulty = (self.difficulty-1 <= 0) and length or self.difficulty-1
            end
        elseif self.menuline == 1 then
            if key == "left" or key == "right" then
                self.multiplayer = not self.multiplayer
            end
        end
    end
end

function M:update(dt)
    if self.fx.trail then
        self.trail:update(dt)
    end
    --misc input
    if love.keyboard.isDown('q') then
--         love.event.push('quit')
        GotoMenu()
    end
    if love.keyboard.isDown('r') then
        self:initgame()
    end
    if self.inmenu or not self.alive then
        return
    end
    --paddle logic
    if love.keyboard.isDown('up') then
        self.player1.y = self.player1.y - self.player1.speed * dt
        if self.player1.y < 0 then
            self.player1.y = 0
        end
    elseif love.keyboard.isDown('down') then 
        self.player1.y = self.player1.y + self.player1.speed * dt
        if self.player1.y > self.screen.y - self.player1.len then
            self.player1.y = self.screen.y - self.player1.len
        end
    end
    local mY = love.mouse.getY()
    if self.lastmouse ~= mY then
        self.player1.y = mY/self.screen:scale() - self.player1.len/2
        self.lastmouse = mY
    end
    --P2
    if self.multiplayer then--peoples
        if love.keyboard.isDown('a') then
            self.player2.y = self.player2.y - self.player2.speed * dt
        elseif love.keyboard.isDown('z') then 
            self.player2.y = self.player2.y + self.player2.speed * dt
        end
    else--cpu paddle
        local last = self.player2.y
        local cap = nil
        if self.difficulty == 1 then
            cap = 10
        elseif self.difficulty == 2 then
            cap = 18
        elseif self.difficulty == 3 then
            cap = 25
        end
        self.player2.y = ((self.ball.y+self.ball.size/2)-self.player2.len/2)
        local diff = self.player2.y - last
        if math.abs(diff) > cap*dt then
            if diff <= 0 then
                self.player2.y = last-cap*dt
            else
                self.player2.y = last+cap*dt
            end
        end
    end
    --stay in screen
    if self.player2.y > self.screen.y - self.player2.len then
        self.player2.y = self.screen.y - self.player2.len
    end
    if self.player2.y < 0 then
        self.player2.y = 0
    end
    --ball logic
    self.ball.x = self.ball.x + self.ball.xVel * dt
    self.ball.y = self.ball.y + self.ball.yVel * dt
    --collision check
    local function paddlecoll(player, pitch) 
        self.trail:emit(30)
        local pitch = pitch or 1.5
        self.ball.xVel = -self.ball.xVel
        local rand =  math.random(-5, 5)
        local veer = (self.ball.y+self.ball.size/2) - (player.y+player.len/2)
        if self.difficulty == 1 then
            cap = 150
        elseif self.difficulty == 2 then
            cap = 200
        elseif self.difficulty == 3 then
            cap = 300
        end
        self.ball.yVel = veer*4+rand*3
        self.ball.xVel = self.ball.xVel > 0 and self.ball.xVel + self.difficulty*2 or self.ball.xVel - self.difficulty*2
        if math.abs(self.ball.xVel) > cap then
            self.ball.xVel = self.ball.xVel > 0 and cap or -cap
        end
        self.sounds.bounce:setPitch(pitch)
        self.sounds.bounce:play()
    end
    if self.ball.x + self.ball.size >= self.collborder.right then--right border
        if self.ball.y+self.ball.size >= self.player1.y and self.ball.y <= self.player1.y + self.player1.len and math.abs((self.ball.x + self.ball.size) - self.collborder.right) <= self.ball.xVel*dt then --hit paddle
            paddlecoll(self.player1)
            self.ball.x = self.collborder.right - self.ball.size-1 --anti stick
        else --missed
--             score.player = score.player -1
            self.score.cpu = self.score.cpu+1
            self:resetball()
            if not self.multiplayer then
                self.score.deaths = self.score.deaths+1
                if self.score.deaths > self.score.limit then
                    self.alive = false
                end
            end
        end
    end
    if self.ball.x <= self.collborder.left then--left border
        if self.ball.y+self.ball.size >= self.player2.y and self.ball.y <= self.player2.y + self.player2.len then --hit paddle
            self.ball.x = self.collborder.left
            paddlecoll(self.player2,1.7)
        else
            self.score.player = self.score.player + 1
--             score.cpu = score.cpu-1
            self:resetball()
        end
    end
    if self.ball.y < 0 or self.ball.y+self.ball.size > self.screen.y then--top/bottom walls
        self.ball.yVel = -self.ball.yVel*1.5
        self.sounds.bounce:setPitch(1)
        self.sounds.bounce:play()
    end
end

function M:draw()
--     self.PXL.screen.canvas:setFilter('nearest', 'nearest', 0)
--     love.graphics.setCanvas(self.PXL.screen.canvas)
--     love.graphics.setDefaultFilter('nearest', 'nearest', 0)
--     love.graphics.clear()
--     love.graphics.setFont(self.font)
--     debug.debug()
    
    if not self.alive then
        love.graphics.setColor(self.colors.white)
        love.graphics.printf({{255,75,75}, "Game Over\n", self.colors.white, string.format("%d:%d\nRestart..R\nQuit..Q", self.score.cpu, self.score.player)}, 0, 1, self.screen.x, 'center')
    elseif self.inmenu then
        love.graphics.setColor(self.colors.violet)
        love.graphics.printf("Pong", 0, 5, self.screen.x, 'center')
        love.graphics.setColor(self.menuline == 0 and self.colors.white or self.colors.violet)
        love.graphics.printf("Difficulty", 0, 13, self.screen.x, 'center')
        love.graphics.printf(self.difficulties[self.difficulty], 0, 20, self.screen.x, 'center')
        local mode = self.multiplayer and "multi" or "single"
        love.graphics.setColor(self.menuline == 1 and self.colors.white or self.colors.violet)
        love.graphics.printf(mode, 0,27,self.screen.x,'center')
    else
        love.graphics.setLineWidth(1)
        love.graphics.setLineStyle('rough')
        --decorations
        if self.multiplayer then
            love.graphics.setColor(255,255,255,150)
            love.graphics.draw(self.kittyimg, 15,10)
        end
        love.graphics.setColor(self.colors.darkGray)
        love.graphics.printf(string.format("%i-%i", self.score.cpu, self.score.player), 0, 5, self.screen.x, 'center')
        if not self.multiplayer then
            love.graphics.printf(string.format("%d/%d", self.score.deaths, self.score.limit), 0, 36, self.screen.x, 'center')
        end
        love.graphics.setColor(160,160,160,100)
        love.graphics.rectangle('fill', self.screen.x/2-1, 0, 1, self.screen.y)
        --love.graphics.rectangle('fill', collborder.right, 0, 5, love.graphics:getHeight())
        --draw ball
        love.graphics.setColor(self.colors.violet)
        love.graphics.rectangle('fill', self.ball.x, self.ball.y, self.ball.size, self.ball.size)
        --ball sparkles
        if self.fx.sparkle then
            for i=1, 100 do
                local x = self.ball.x+self.ball.size/2
                local y = self.ball.y+self.ball.size/2
                love.graphics.setColor(math.random(200,255),math.random(200,255),math.random(200,255),math.random(25,100))
                local dist = 4*i/100
                love.graphics.rectangle('fill',x+math.random(-dist-1,dist), y+math.random(-dist-1,dist),1,1)
            end
        end
        if self.fx.trail then 
            self.trail:setPosition(self.ball.x+self.ball.size/2, self.ball.y+self.ball.size/2)
            love.graphics.draw(self.trail, 0,0)
        end
        --draw paddles
        love.graphics.setColor(self.multiplayer and self.colors.pink or self.colors.white)
        love.graphics.rectangle('line', self.player1.x, self.player1.y, self.player1.thickness, self.player1.len)    speed = 
        love.graphics.setColor(self.multiplayer and self.colors.violet or self.colors.gray)
        love.graphics.rectangle('line', self.player2.x, self.player2.y, self.player2.thickness, self.player2.len)
    end
    
--     --noise effect
--     if self.fx.grain then
--         for y=0,self.screen.y do
--             for x=0,self.screen.x do
--                 local color = math.random(0,255)
--                 love.graphics.setColor(color,color,color,25)
--                 love.graphics.rectangle('fill',x+self.screen:offset(),y,1,1)
--             end
--         end
--     end
--     love.graphics.setColor(255,255,255,255)
    
--     love.graphics.setCanvas()
-- --     love.graphics.setBlendMode("alpha", "premultiplied")
--     love.graphics.setColor(255,255,255,255)
--     love.graphics.draw(self.PXL.screen.canvas, self.screen:offset(),0,0, self.screen:scale(), self.screen:scale())
--     if self.fx.crt then
--         love.graphics.setBlendMode("multiply")
--         love.graphics.draw(self.pixelimg,self.screen:offset(),0,0,self.screen:scale()/10,self.screen:scale()/10)
--         love.graphics.setBlendMode("alpha")
--     end
end
return M
