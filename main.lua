local timer = require("timer")
local games = {}
-- games['pong'] = require("games.pong.main")
-- games['pong'].cwd = 'games/pong/'
games.selected = 'pong'
function games:active()
    return self[self.selected]
end
local PXL = {}
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
PXL.state = 'intro'
PXL.images = {}
PXL.timers = {}

function love.load()
    --generat setup
    PXL.screen.canvas = love.graphics.newCanvas(PXL.screen.x,PXL.screen.y)
    PXL.timers.intro = timer:new(1000)
    
    --include resources
    PXL.images.banner = love.graphics.newImage("images/banner.png")
    PXL.images.arrow = love.graphics.newImage("images/arrow.png")
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
        games[name] = require("games."..name..".main")
        games[name].cwd = "games/"..name.."/" -- tell the module it's directory path
        games[name].icon = love.graphics.newImage("games/"..name.."/icon.png")
        games[name].screen = PXL.screen--give the module screen a ref to screen
        games[name].PXL = PXL
    end
--     games[selected]:load()
end
function love.update(dt)
    if PXL.timers.intro:once() then
        PXL.state = 'menu'
    end
    
    if PXL.state == 'menu' then
        
    elseif PXL.state == 'game' and games:active().update then
        games:active():update(dt)
    end
end
function love.keypressed(key, screencode, isrepeat)
    if PXL.state == 'menu' then
        if key == "return" then
            PXL.state = 'game'
            games:active():load()
        elseif key == "right" then
        elseif key == "left" then
        elseif key == 'q' then
            love.event.push('quit')
        end
    elseif PXL.state == 'game' and games:active().keypressed then
        games:active():keypressed(key, screencode, isrepeat)
    end
end
function love.draw()
--  the canvas is also used by the modules
    PXL.screen.canvas:setFilter('nearest', 'nearest', 0)
    love.graphics.setCanvas(PXL.screen.canvas)
    love.graphics.setDefaultFilter('nearest', 'nearest', 0)
    love.graphics.clear()
    love.graphics.setFont(PXL.font)
    
    if PXL.state == 'menu' then
        love.graphics.draw(games:active().icon, 8,1)
        love.graphics.setColor(PXL.colors.purple[2])
        love.graphics.rectangle("fill", 1, 38, PXL.screen.x-2,1)
        love.graphics.setColor(PXL.colors.gray[6])
        love.graphics.printf(games:active().name, 0, 38-2, PXL.screen.x,'center')
    elseif PXL.state == 'intro' then
        love.graphics.draw(PXL.images.banner, 0,0)
    elseif PXL.state == 'game' then
        games:active():draw()
    end
    
    love.graphics.setCanvas()
--     love.graphics.setBlendMode("alpha", "multiply")
    love.graphics.setColor(255,255,255,255)--reset color
    love.graphics.draw(PXL.screen.canvas, PXL.screen:offset(),0,0, PXL.screen:scale(), PXL.screen:scale())
end
