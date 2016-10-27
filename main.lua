local timer = require("lib.timer")
local shine = require('lib.shine')
local class = require('lib.class')
local PXL = {}

--helpers
local function saferun(func, ...)
    ok, msg = pcall(func, ...)
    if not ok then
        print(msg)
    end
end
local function safemethodrun(obj, funcname, ...)
    saferun(obj[funcname], obj, ...)
end
PXL.inspect = require('lib.inspect')
function PXL.shallowcopy(orig) -- http://lua-users.org/wiki/CopyTable
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
function PXL.round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end
function PXL.printCenter(text, row, offset)
    local height = 8 --GAH 'magic numbers'!
    if offset then
        love.graphics.printf(text, 1, offset, PXL.screen.x, 'center')
    elseif row then
        local row = row -1
        love.graphics.printf(text, 1, 1+height*row, PXL.screen.x, 'center')
    else--centered y
        love.graphics.printf(text, 1, PXL.screen.y/2-height/2, PXL.screen.x, 'center')
    end
end

-- games.selected = 1
-- PXL.state = 'intro'
PXL.state = 'menu'

local Games = class()
function Games:init()
    self.selected = 1
    self.updateTimes = {} -- store file update times
    self.list = {}
    self.timer = timer:new(2000)
    self:load()
    self:updateCheck()
end
function Games:active()
    return self.list[self.selected]
end
function Games:gotoNext()
    self.selected = (self.selected + 1) <= #self.list and (self.selected + 1) or 1
end
function Games:gotoPrev()
    self.selected = (self.selected - 1) > 0 and (self.selected - 1) or #self.list
end
function Games:next()--returns next game
    return self.list[(self.selected + 1) <= #self.list and (self.selected + 1) or 1] --rollback increment
end
function Games:prev()
    return self.list[(self.selected - 1) > 0 and (self.selected - 1) or #self.list] --rollback decrement
end

function Games:updateCheck()--check for updates in games and reload the files
    if not self.timer:every() then return end
    local dirty = false
    for i, v in ipairs(self.list) do
        local modtime, err = love.filesystem.getLastModified(v.path)
--         print(err)
--         print(string.format("%i :: %i -- %s",self.updateTimes[i]or 0, modtime or 0, v.path))
        if self.updateTimes[i] then
            if self.updateTimes[i] ~= modtime then
                dirty = true
                self.updateTimes[i] = modtime
            end
        else--first run
            self.updateTimes[i] = modtime
        end
    end
    if dirty then 
        print("[pxl]reload triggered")
        self:load()
    end
end

function Games:load()
    print("[pxl]loading subgames")
    local list = love.filesystem.getDirectoryItems( 'games' )
    self.list = {}
    PXL.state = 'menu'
    for k, name in ipairs(list) do
        print(k..": "..name)
        local reqpath = "games."..name..".main"
        local path = "games/"..name.."/main.lua"
        self.list[k] = love.filesystem.load(path)()
        self.list[k].reqpath = reqpath
        self.list[k].path = path
        self.list[k].cwd = "games/"..name.."/" -- tell the module it's directory path
        if love.filesystem.exists("games/"..name.."/icon.png") then --check for title image
            self.list[k].icon = love.graphics.newImage("games/"..name.."/icon.png")
        else
            self.list[k].icon = love.graphics.newImage("images/no_icon.png")
        end
        self.list[k].screen = PXL.screen--give the module screen a ref to screen(which makes no sense with the next line)
        self.list[k].PXL = PXL
    end
end

PXL.lastres = {0,0}
PXL.options={--setting here!
    fx = { -- filters
        crt = false,
        grain = false,
        gpugrain = true,
        crtwarp = true
    },
    anim = {
        intro = 500,
        btn = 100,
        slide = 250,
        text = 150
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
PXL.images = {}
PXL.timers = {}
PXL.states = { --substates
    arrow = 'idle',
    slide = 'idle'
}
PXL.anim = {--animation data etc.
    arrow = {left=0,right=0, rcolor = {255,255,255}, lcolor={255,255,255}},
    slide = {offset=nil, imga = nil, imgb = nil},
    text  = {text = '', offset = 0, state = 'final'}--putting state here just cause it makes more sense
}

local function buildFX() --setup shader FX
    --FX
    local crt = shine.crt()
    local separate_chroma = shine.separate_chroma()
--     local scanlines = shine.scanlines()
    local glow = shine.glowsimple()
    separate_chroma.angle = 0.2
    separate_chroma.radius = 1
--     scanlines.pixel_size=PXL.screen:scale()
--     scanlines.line_height=0.3
--     scanlines.opacity = 0.2
    crt.x, crt.y = 0.03, 0.0325
    glow.min_luma = 0.2
    glow.sigma = 10
    
--     PXL.post_effect = grain:chain(separate_chroma):chain(crt)
    if PXL.options.fx.crtwarp then
        PXL.post_effect = separate_chroma:chain(crt):chain(glow)
    else
        PXL.post_effect = separate_chroma:chain(glow)
    end
end

function love.load()
    --generic setup
    PXL.games = Games()--include games
    math.randomseed( os.time() ) --xaos yo!
    love.mouse.setVisible(false)
    PXL.screen.canvas = love.graphics.newCanvas(PXL.screen.x,PXL.screen.y)
    --timers
    PXL.timers.intro = timer:new(PXL.options.anim.intro)
    PXL.timers.arrow = timer:new(PXL.options.anim.btn):pause()
    PXL.timers.slide = timer:new(PXL.options.anim.slide):pause()
    PXL.timers.text  = timer:new(PXL.options.anim.text/2):pause()
    
    --build grain FX
    PXL.grain = shine.filmgrain()
    PXL.grain.opacity = 0.15
    PXL.grain.grainsize = 1
    
    buildFX()--init other fx
    
    --include resources
    PXL.images.banner = love.graphics.newImage("images/banner.png")
    PXL.images.arrow = love.graphics.newImage("images/arrow.png")
    PXL.images.deco1 = love.graphics.newImage("images/deco1.png")
    PXL.images.crt = love.graphics.newImage("images/pixelmask.png")
    PXL.font = love.graphics.newFont("fonts/AerxFont.ttf", 16)
    PXL.font:setLineHeight(0.625) --8px high + 1px margin top/bottom
    
     --create color palette (why use an image? because I can even if it makes everything hadrer!)
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
    
    --is state is shorted to 'game' on init
    if PXL.state == 'game' then
        safemethodrun(self.games:active(), 'load')
        PXL.timers.intro:pause()
    end
end
function love.mousemoved( x, y, dx, dy, istouch )
    if PXL.state == 'game' and PXL.games:active().mousemoved then
        PXL.games:active().mousemoved(x,y,dx,dy,istouch)
    end
end
function love.keypressed(key, screencode, isrepeat)
    if PXL.state == 'menu' and not isrepeat then
        if key == "return" then
            PXL.state = 'game'
            PXL.games:active():load()
        elseif key == "right" then
            PXL.games:gotoNext()
            PXL.states.arrow = "right out"
            PXL.states.slide = "next"
            PXL.anim.text.state = 'start'
        elseif key == "left" then
            PXL.games:gotoPrev()
            PXL.states.arrow = "left out"
            PXL.states.slide = "prev"
            PXL.anim.text.state = 'start'
        elseif key == 'q' then
            love.event.push('quit')
        end
    elseif PXL.state == 'game' and PXL.games:active().keypressed then
        safemethodrun(PXL.games:active(), 'keypressed', key, screencode, isrepeat)
    end
    if key == '1' then--fx toggling
        PXL.options.fx.crt = not PXL.options.fx.crt
    elseif key == '2' then
        PXL.options.fx.gpugrain = not PXL.options.fx.gpugrain
    elseif key == '3' then
        PXL.options.fx.crtwarp = not PXL.options.fx.crtwarp
        buildFX()
    end
end
function love.update(dt)
    PXL.games:updateCheck() -- watch subgames for changes (in main.lua)
    local res = {love.graphics.getHeight(), love.graphics.getWidth()}
    if (PXL.lastres[0] ~= res[0]) or (PXL.lastres[1] ~= res[1]) then
        buildFX() --the shine lib doesn't update for changing screen sizes itself so we do it here
        PXL.lastres = res
        print("fx rebuilt"..PXL.inspect(res)..PXL.inspect(PXL.lastres))
    end
    
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
            PXL.anim.slide.imga = PXL.games:prev().icon
            PXL.anim.slide.imgb = PXL.games:active().icon
            PXL.states.slide = "next anim"
            PXL.timers.slide:start()
        elseif PXL.states.slide == "prev" then
            PXL.anim.slide.offset = 60
            PXL.anim.slide.imga = PXL.games:active().icon
            PXL.anim.slide.imgb = PXL.games:next().icon
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
        --text anim
        if PXL.anim.text.state == 'start' then
            PXL.timers.text:start()
            PXL.anim.text.state = "down"
        end if PXL.anim.text.state == 'down' then
            PXL.anim.text.offset = PXL.timers.text:percent()*8
            if PXL.timers.text:check() then
                PXL.timers.text:start()
                PXL.anim.text.state = "up"
                PXL.anim.text.text = PXL.games:active().name
            end
        elseif PXL.anim.text.state == 'up' then 
            PXL.anim.text.offset = PXL.timers.text:percent(true)*8
            if PXL.timers.text:check() then
                PXL.anim.text.state = 'final'
            end
        end if PXL.anim.text.state == 'final' then
            PXL.anim.text.text = PXL.games:active().name --for init
            PXL.anim.text.offset = 0
            PXL.anim.state = 'idle'
        end
    elseif PXL.state == 'game' and PXL.games:active().update then
        safemethodrun(PXL.games:active(), 'update', dt)
    end
end
local function draw()
--  the canvas is also used by the modules
    local old_canvas = love.graphics.getCanvas()--for compatibillity with shine
    PXL.screen.canvas:setFilter('nearest', 'nearest', 0)
    love.graphics.setCanvas(PXL.screen.canvas)
--     love.graphics.setDefaultFilter('nearest', 'nearest', 0)
    love.graphics.clear()
    love.graphics.setFont(PXL.font)
    
    local function smalldraw()
        if PXL.state == 'menu' then
            if PXL.states.slide == 'idle' then
                love.graphics.draw(PXL.games:active().icon, 8,1)
            else
                love.graphics.draw(PXL.anim.slide.imga, 8-PXL.anim.slide.offset,1)
                love.graphics.draw(PXL.anim.slide.imgb, 68-PXL.anim.slide.offset,1)
            end
            love.graphics.setColor(PXL.colors.purple[3])
            love.graphics.rectangle("fill", 1, 38, PXL.screen.x-2,20, 5, 4)--divider line / bg
            love.graphics.setColor(PXL.colors.gray[1])
            local namelen = PXL.font:getWidth(PXL.anim.text.text)
            love.graphics.printf(PXL.anim.text.text, 1, 37+PXL.anim.text.offset, PXL.screen.x,'center')--shadow text
            love.graphics.setColor(PXL.colors.gray[6])
            love.graphics.printf(PXL.anim.text.text, 0, 36+PXL.anim.text.offset, PXL.screen.x,'center')--game name
            love.graphics.setColor(PXL.colors.blue[4])
            love.graphics.draw(PXL.images.deco1, PXL.screen.x/2-namelen/2-2, 42+PXL.anim.text.offset, 0, 1, 1, 2, 0)--text decorations
            love.graphics.draw(PXL.images.deco1, PXL.screen.x/2+namelen/2+2, 42+PXL.anim.text.offset, 0, 1, 1, 2, 0)
            --arrows
            love.graphics.setColor(PXL.anim.arrow.lcolor)
            love.graphics.draw(PXL.images.arrow, 2+PXL.anim.arrow.left,11, 0, -1, 1, 6, 0)
            love.graphics.setColor(PXL.anim.arrow.rcolor)
            love.graphics.draw(PXL.images.arrow, 56+PXL.anim.arrow.right,11)
            love.graphics.setColor(PXL.colors.gray[6])
        elseif PXL.state == 'intro' then
            love.graphics.draw(PXL.images.banner, 0,0)
        elseif PXL.state == 'game' then
            safemethodrun(PXL.games:active(), 'draw')
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
    end

    if PXL.options.fx.gpugrain then
        PXL.grain:draw(smalldraw)
    else
        smalldraw()
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
-- love.draw = draw
function love.draw()
    PXL.post_effect:draw(draw)
    love.graphics.print("FPS: "..tostring(love.timer.getFPS()), 10, 10)
end
