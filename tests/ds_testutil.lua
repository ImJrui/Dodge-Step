local T = { count = 0, now = 0, tasks = {} }
local scripts = os.getenv("DS_GAME_SCRIPTS")
    or "F:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts"
if Class == nil then dofile(scripts .. "/class.lua") end
package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path
GLOBAL = _G
env = { GetModConfigData = function() return nil end }
FRAMES = 1 / 30
COLLISION = { CHARACTERS = 1024 }
EQUIPSLOTS = { HANDS = "hands" }
GetTime = function() return T.now end
Vector3 = function(x, y, z)
    return { x = x, y = y, z = z, Get = function(self) return self.x, self.y, self.z end }
end
dofile("main/constants.lua")
DS_Log = function() end

function T.eq(actual, expected, message)
    assert(actual == expected, (message or "mismatch") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
function T.near(actual, expected, epsilon)
    assert(math.abs(actual - expected) <= (epsilon or 0.00001), tostring(actual) .. " ~= " .. tostring(expected))
end
function T.test(name, fn)
    T.now, T.tasks = 0, {}
    fn()
    T.count = T.count + 1
    print("PASS " .. name)
end
function T.entity(prefab, x, z, animation, rotation, y)
    local e = { prefab = prefab, components = {}, replica = {}, tags = {}, valid = true,
        awake = true, x = x or 0, y = y or 0, z = z or 0, animation = animation, rotation = rotation or 0,
        listeners = {}, GUID = math.random(1000000) }
    e.Transform = {
        GetWorldPosition = function() return e.x, e.y, e.z end,
        GetRotation = function() return e.rotation end,
    }
    e.AnimState = { IsCurrentAnimation = function(_, anim) return e.animation == anim end }
    e.entity = { IsAwake = function() return e.awake end }
    function e:IsValid() return self.valid end
    function e:IsAsleep() return not self.awake end
    function e:IsInLimbo() return self.tags.INLIMBO == true end
    function e:HasTag(tag) return self.tags[tag] == true end
    function e:GetPhysicsRadius(default) return self.radius or default or 0 end
    function e:GetPosition() return Vector3(self.x, self.y, self.z) end
    function e:ListenForEvent(event, fn, source)
        source = source or self
        source.listeners[event] = source.listeners[event] or {}
        source.listeners[event][fn] = self
    end
    function e:RemoveEventCallback(event, fn, source)
        source = source or self
        if source.listeners[event] then source.listeners[event][fn] = nil end
    end
    function e:PushEvent(event, data)
        local copy = {}
        for fn, receiver in pairs(self.listeners[event] or {}) do copy[fn] = receiver end
        for fn, receiver in pairs(copy) do fn(receiver, data) end
    end
    function e:DoTaskInTime(delay, fn)
        local task = { at = T.now + delay, fn = function() fn(self) end }
        function task:Cancel() self.cancelled = true end
        T.tasks[#T.tasks + 1] = task
        return task
    end
    function e:DoPeriodicTask(period, fn, initial)
        local task = self:DoTaskInTime(initial or period, fn)
        task.period = period
        return task
    end
    function e:StartUpdatingComponent(component) self.updating = component end
    function e:StopUpdatingComponent(component) if self.updating == component then self.updating = nil end end
    function e:AddComponent(name)
        self.components[name] = require("components/" .. name)(self)
    end
    return e
end
function T.advance(dt)
    local finish = T.now + dt
    for _ = 1, 1000 do
        local nexttask
        for _, task in ipairs(T.tasks) do
            if not task.cancelled and task.at <= finish and (not nexttask or task.at < nexttask.at) then nexttask = task end
        end
        if not nexttask then break end
        T.now = nexttask.at
        if nexttask.period then nexttask.at = nexttask.at + nexttask.period else nexttask.cancelled = true end
        nexttask.fn()
    end
    T.now = finish
end
function T.controller_methods()
    local file = assert(io.open(scripts .. "/components/playercontroller.lua", "r"))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find("function PlayerController:DoAction(buffaction, spellbook)", 1, true))
    local last = assert(source:find("function PlayerController:OnLeftClick(down)", first, true))
    local scope = setmetatable({ PlayerController = {} }, { __index = _G })
    local chunk = assert(loadstring(source:sub(first, last - 1)))
    setfenv(chunk, scope)
    chunk()
    return scope.PlayerController
end
function T.summary() print("PASS " .. T.count .. " cases") end
return T
