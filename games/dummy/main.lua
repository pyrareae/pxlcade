local M = {
name = "Dummy"
}

function M:load()
    
end
function M:draw()
    love.graphics.print("meow",0,0)
end

return M
