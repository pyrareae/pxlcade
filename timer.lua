local T = {--class vars
--     timers = {}--keep track of all timers (useful for 'ticking' all of them, if callback are needed)
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
    o.stopped = false
--     self.timers[#self.timers+1] = o --save this into list
    return o
end

function T:pause() -- suspend countdown
    self.stopped = true
    self._remaining = self:remaining() -- save current remaining time
end

function T:resume() -- restart countdown
    self.stopped = false
    self.last = self.millis()-self._remaining
end

function T:start(time) --resume + reset
    if time then
        self.timer = time
    end
    self:resume()
    self:reset()
end

function T:check(time) -- check by argument or time provided in constructor
    if self.stopped then return false end
    local now = self.millis()
    local time = time or self.timer
    return time+self.last < now
end

function T:once(time) -- only return true once after time elapsed
    if not self.fired and self:check(time) then
        self.fired = true
        return true
    end
    return false
end

function T:every(time) -- repeat the timer over and over
    if self:check(time) then
        self:reset()
        return true
    end
    return false
end

function T:reset() --reset the timer
    self.fired = false
    self.last = self.millis()
end

function T:remaining(time) --return remaining time in millis
    local time = time or self.timer
    return (self.last + time)-self.millis()
end

return T
