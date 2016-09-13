local timer = require("timer")
local shine = require('lib.shine')
local games = {}
-- games['pong'] = require("games.pong.main")
-- games['pong'].cwd = 'games/pong/'
games.selected = 1
function games:active()
    return self[self.selected]
end
function games:gotoNext()
    self.selected = (self.selected + 1) <= #self and (self.selected + 1) or 1
end
function games:gotoPrev()
    self.selected = (self.selected - 1) > 0 and (self.selected - 1) or #self
end
function games:next()--returns next game
    return self[(self.selected + 1) <= #self and (self.selected + 1) or 1] --rollback increment
end
function games:prev()
    return self[(self.selected - 1) > 0 and (self.selected - 1) or #self] --rollback decrement
end
local PXL = {}
PXL.options={--setting here!
    fx = { --cpu filters
        crt = true,
        grain = true
    },
    anim = {
        intro = 500,
        btn = 100,
        slide = 250
    }
}
PXL.screen = {
    x = 64,--internal render size
    y = 48,
    scale= function(self)
        local xs = love.graphics.getWidth()/self.x
        local ys = love.graphics.getHeight()/self.y
        return math.min(xs,ys)
    end,
    offset = function(self)
        local off = (love.graphics.getWidth()-self.x*self:scale())/2
        return off > 0 and off or 0
    end
}
function GotoMenu() --return to main menu, call from subgames
    PXL.state="menu"
end
PXL.state = 'game'
PXL.images = {}
PXL.timers = {}
PXL.states = { --substates
    arrow = 'idle',
    slide = 'idle'
}
PXL.anim = {--animation data etc.
    arrow = {left=0,right=0, rcolor = {255,255,255}, lcolor={255,255,255}},
    slide = {offset=nil, imga = nil, imgb = nil}
}

function love.load()
    --generic setup
    love.mouse.setVisible(false)
    PXL.screen.canvas = love.graphics.newCanvas(PXL.screen.x,PXL.screen.y)
    --timers
    PXL.timers.intro = timer:new(PXL.options.anim.intro)
    PXL.timers.arrow = timer:new(PXL.options.anim.btn):pause()
    PXL.timers.slide = timer:new(PXL.options.anim.slide):pause()
    
    --FX
--     local grain = shine.filmgrain()
--     local crt = shine.crt()
--     local separate_chroma = shine.separate_chroma()
--     local scanlines = shine.scanlines()
--     local glow = shine.glowsimple()
--     grain.opacity = 0.3
--     grain.grainsize = 10
-- --     crt.y = 0.05
-- --     crt.x = 0.05
--     separate_chroma.angle = 0.2
--     separate_chroma.radius = 0
--     scanlines.pixel_size=PXL.screen:scale()
--     scanlines.line_height=0.3
--     scanlines.opacity = 0.2
--     glow.min_luma = 0.2
--     glow.sigma = 10
--     
-- --     PXL.post_effect = grain:chain(separate_chroma):chain(crt)
--     PXL.post_effect = separate_chroma:chain(scanlines):chain(crt):chain(glow)
    
    --include resources
    PXL.images.banner = love.graphics.newImage("images/banner.png")
    PXL.images.arrow = love.graphics.newImage("images/arrow.png")
    PXL.images.deco1 = love.graphics.newImage("images/deco1.png")
    PXL.images.crt = love.graphics.newImage("images/pixelmask.png")
    PXL.font = love.graphics.newFont("fonts/AerxFont.ttf", 16)
    
     --create color palette
    local palette = love.image.newImageData( 'images/palette.png' )
    PXL.colors = {{},{},{},{},{},{},{}}
    for x = 1, palette:getWidth() do --read first line horizontally
        local r,g,b = palette:getPixel(x-1,0)
        PXL.colors[1][x] = {r,g,b}
    end
    for x = 1, palette:getWidth() do --read the color strips
        for y=2,palette:getHeight() do 
            local r,g,b = palette:getPixel(x-1,y-1)
            PXL.colors[x+1][y-1] = {r,g,b}
        end
    end
    --better names
    PXL.colors.gray = PXL.colors[1];PXL.colors.magenta = PXL.colors[2];PXL.colors.purple=PXL.colors[3];PXL.colors.cyan = PXL.colors[4];PXL.colors.blue = PXL.colors[5];PXL.colors.red=PXL.colors[6];PXL.colors.orange = PXL.colors[7]
    
    --include games
    print("loading subgames")
    local list = love.filesystem.getDirectoryItems( 'games' )
    for k, name in ipairs(list) do
        print(k..": "..name)
        games[k] = require("games."..name..".main")
        games[k].cwd = "games/"..name.."/" -- tell the module it's directory path
        games[k].icon = love.graphics.newImage("games/"..name.."/icon.png")
        games[k].screen = PXL.screen--give the module screen a ref to screen
        games[k].PXL = PXL
    end
    --is state is shorted to 'game' on init
    if PXL.state == 'game' then
        games:active():load()
        PXL.timers.intro:pause()
    end
end
function love.mousemoved( x, y, dx, dy, istouch )
    if PXL.state == 'game' and games:active().mousemoved then
        games:active().mousemoved(x,y,dx,dy,istouch)
    end
end
function love.keypressed(key, screencode, isrepeat)
    if PXL.state == 'menu' and not isrepeat then
        if key == "return" then
            PXL.state = 'game'
            games:active():load()
        elseif key == "right" then
            games:gotoNext()
            PXL.states.arrow = "right out"
            PXL.states.slide = "next"
        elseif key == "left" then
            games:gotoPrev()
            PXL.states.arrow = "left out"
            PXL.states.slide = "prev"
        elseif key == 'q' then
            love.event.push('quit')
        end
    elseif PXL.state == 'game' and games:active().keypressed then
        games:active():keypressed(key, screencode, isrepeat)
    end
end
function love.update(dt)
    if PXL.timers.intro:once() then
        PXL.state = 'menu'
    end
    
    if PXL.state == 'menu' then
        --arrow anim
        if PXL.states.arrow == "right out" then
            PXL.anim.arrow.right = 1
            PXL.anim.arrow.rcolor = PXL.colors.purple[3]
            PXL.states.arrow = 'return'
            PXL.timers.arrow:start()
        elseif PXL.states.arrow == "left out" then
            PXL.anim.arrow.left = -1
            PXL.anim.arrow.lcolor = PXL.colors.purple[3]
            PXL.states.arrow = 'return'
            PXL.timers.arrow:start()
        end
        if PXL.timers.arrow:once() then
            if PXL.states.arrow == 'return' then
                PXL.anim.arrow.left = 0
                PXL.anim.arrow.right = 0
                PXL.anim.arrow.rcolor = PXL.colors.gray[6]
                PXL.anim.arrow.lcolor = PXL.colors.gray[6]
            end
        end
        --image anim
        if PXL.states.slide == "next" then
            PXL.anim.slide.offset = 0
            PXL.anim.slide.imga = games:prev().icon
            PXL.anim.slide.imgb = games:active().icon
            PXL.states.slide = "next anim"
            PXL.timers.slide:start()
        elseif PXL.states.slide == "prev" then
            PXL.anim.slide.offset = 60
            PXL.anim.slide.imga = games:active().icon
            PXL.anim.slide.imgb = games:next().icon
            PXL.states.slide = "prev anim"
            PXL.timers.slide:start()
        end
        if PXL.states.slide == "next anim" then
            PXL.anim.slide.offset = 60 - (60 * PXL.timers.slide:remaining()/PXL.timers.slide.timer)
        elseif PXL.states.slide == "prev anim" then
            PXL.anim.slide.offset = 60 * PXL.timers.slide:remaining()/PXL.timers.slide.timer
        end
        if PXL.timers.slide:once() then --anim finished
            PXL.states.slide = 'idle'
        end
    elseif PXL.state == 'game' and games:active().update then
        games:active():update(dt)
    end
end
local function draw()
--  the canvas is also used by the modules
    local old_canvas = love.graphics.getCanvas()--for compatibillity with shine
    PXL.screen.canvas:setFilter('nearest', 'nearest', 0)
    love.graphics.setCanvas(PXL.screen.canvas)
    love.graphics.setDefaultFilter('nearest', 'nearest', 0)
    love.graphics.clear()
    love.graphics.setFont(PXL.font)
    
    if PXL.state == 'menu' then
        if PXL.states.slide == 'idle' then
            love.graphics.draw(games:active().icon, 8,1)
        else
            love.graphics.draw(PXL.anim.slide.imga, 8-PXL.anim.slide.offset,1)
            love.graphics.draw(PXL.anim.slide.imgb, 68-PXL.anim.slide.offset,1)
        end
        love.graphics.setColor(PXL.colors.purple[2])
        love.graphics.rectangle("fill", 1, 38, PXL.screen.x-2,1)
        love.graphics.setColor(PXL.colors.gray[6])
        local namelen = PXL.font:getWidth(games:active().name)
        love.graphics.printf(games:active().name, 0, 38-2, PXL.screen.x,'center')
        love.graphics.setColor(PXL.colors.purple[2])
        love.graphics.draw(PXL.images.deco1, PXL.screen.x/2-namelen/2-2, 42, 0, 1, 1, 2, 0)
        love.graphics.draw(PXL.images.deco1, PXL.screen.x/2+namelen/2+2, 42, 0, 1, 1, 2, 0)
        --arrows
        love.graphics.setColor(PXL.anim.arrow.lcolor)
        love.graphics.draw(PXL.images.arrow, 2+PXL.anim.arrow.left,11, 0, -1, 1, 6, 0)
        love.graphics.setColor(PXL.anim.arrow.rcolor)
        love.graphics.draw(PXL.images.arrow, 56+PXL.anim.arrow.right,11)
        love.graphics.setColor(PXL.colors.gray[6])
    elseif PXL.state == 'intro' then
        love.graphics.draw(PXL.images.banner, 0,0)
    elseif PXL.state == 'game' then
        games:active():draw()
    end
    
    if PXL.options.fx.grain then
        for y=0,PXL.screen.y do
            for x=0,PXL.screen.x do
                local color = math.random(0,255)
                love.graphics.setColor(color,color,color,15)
                love.graphics.rectangle('fill',x+PXL.screen:offset(),y,1,1)
            end
        end
    end
    
    love.graphics.setCanvas(old_canvas)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(255,255,255,255)--reset color
    love.graphics.draw(PXL.screen.canvas, PXL.screen:offset(),0,0, PXL.screen:scale(), PXL.screen:scale())
    
    if PXL.options.fx.crt then
        love.graphics.setBlendMode("multiply")
        love.graphics.draw(PXL.images.crt,PXL.screen:offset(),0,0,PXL.screen:scale()/10,PXL.screen:scale()/10)
        love.graphics.setBlendMode("alpha")
    end
end
love.draw = draw
-- function love.draw()
--     PXL.post_effect:draw(draw)
-- end
