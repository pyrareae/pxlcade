local games = {}
games['pong'] = require("games.pong.main")
games['pong'].cwd = 'games/pong/'
local selected = 'pong'
function love.load()
    games[selected]:load()
end
function love.update(dt)
    games[selected]:update(dt)
end
function love.keypressed(key, screencode, isrepeat)
    games[selected]:keypressed(key, screencode, isrepeat)
end
function love.draw()
    games[selected]:draw()
end
