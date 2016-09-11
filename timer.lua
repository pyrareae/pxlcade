local T = {--class vars
    timers = {}--keep track of all timers (useful for 'ticking' all of them)
}
T.__index = T
function T.millis()
    return love.timer.getTime() * 1000
end
function T:new(time)
    local o = {}
    setmetatable(o, self)
    o.timer = time or 0
    o.last = self.millis()
    o.fired = false
    self.timers[#self.timers+1] = o --save this into list
    return o
end

function T:check(time) -- check by argument or time provided in constructor
    local now = self.millis()
    local time = time or self.timer
    return time+self.last < now
end

function T:once(time) -- only return true once after time elapsed
    if not self.fired and self:check(time) then
        self.fired = true
        return true
    end
end

function T:every(time) -- repeat the timer over and over
    if self:check(time) then
        self:reset()
        return true
    end
end

function T:reset() --reset the timer
    self.fired = false
    self.last = self.millis()
end

function T:remaining(time) --return remaining time in millis
    local time = time or self.timer
    return self.millis() - (self.last + time)
end

return T
