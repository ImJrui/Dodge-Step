local T = dofile("tests/ds_testutil.lua")
TheNet = { IsDedicated = function() return false end }
TheWorld = T.entity("forest")
local hooks = { players = {}, prefabs = {} }
env = {
    AddPlayerPostInit = function(fn) hooks.players[#hooks.players + 1] = fn end,
    AddPrefabPostInit = function(name, fn) hooks.prefabs[name] = fn end,
}
env.modimport = function(relative)
    local chunk = assert(loadfile(relative))
    setfenv(chunk, setmetatable({ env = env, GLOBAL = _G }, { __index = _G }))
    chunk()
end
dofile("main/toolutil.lua")
env.modimport("main/postinit.lua")
local function player()
    local p = T.entity("wilson")
    p.components.playercontroller = {}
    p.replica.inventory = {}
    ThePlayer = p
    for _, fn in ipairs(hooks.players) do fn(p) end
    p:PushEvent("playeractivated")
    T.advance(0.01)
    return p
end

T.test("only the local active player receives boss components", function()
    DS_BOSS_REGISTRY.shrouden = {}
    local remote = T.entity("wendy")
    ThePlayer = nil
    for _, fn in ipairs(hooks.players) do fn(remote) end
    T.advance(0.01)
    T.eq(remote.components.ds_bosswatcher, nil)
    local p = player()
    assert(p.components.ds_shrouden)
    T.eq(p.components.ds_shrouden.enabled, false)
end)
T.test("boss registered before player activation enables local plan", function()
    DS_BOSS_REGISTRY.shrouden = {}
    ThePlayer = nil
    local b = T.entity("shrouden", 10, 0, "idle")
    assert(hooks.prefabs.shrouden, "Shrouden hook must be loaded")
    hooks.prefabs.shrouden(b)
    local p = player()
    T.eq(p.components.ds_shrouden.enabled, true)
end)
T.test("sleep disables, wake re-enables and original callbacks retain results", function()
    DS_BOSS_REGISTRY.shrouden = {}
    local p = player()
    local b = T.entity("shrouden", 10, 0, "idle")
    local woke, slept = 0, 0
    b.OnEntityWake = function(_, x) woke = woke + x return "wake", 4 end
    b.OnEntitySleep = function(_, x) slept = slept + x return "sleep", 7 end
    hooks.prefabs.shrouden(b)
    T.eq(p.components.ds_shrouden.enabled, true)
    b.awake = false
    local a, c = b.OnEntitySleep(b, 2)
    T.eq(a, "sleep") T.eq(c, 7) T.eq(slept, 2)
    T.eq(p.components.ds_shrouden.enabled, false)
    b.awake = true
    a, c = b.OnEntityWake(b, 3)
    T.eq(a, "wake") T.eq(c, 4) T.eq(woke, 3)
    T.eq(p.components.ds_shrouden.enabled, true)
end)
T.test("removing one of multiple bosses keeps plan active until last disappears", function()
    DS_BOSS_REGISTRY.shrouden = {}
    local p = player()
    local b1, b2 = T.entity("shrouden", 10, 0, "idle"), T.entity("shrouden", 20, 0, "idle")
    hooks.prefabs.shrouden(b1) hooks.prefabs.shrouden(b2)
    b1:PushEvent("onremove") b1.valid = false
    T.eq(p.components.ds_shrouden.enabled, true)
    b2:PushEvent("onremove") b2.valid = false
    T.eq(p.components.ds_shrouden.enabled, false)
end)
T.test("watchdog catches missing sleep notifications without scanning all entities", function()
    DS_BOSS_REGISTRY.shrouden = {}
    local p = player()
    local b = T.entity("shrouden", 10, 0, "idle")
    hooks.prefabs.shrouden(b)
    b.awake = false
    T.advance(DS_DODGE.WATCH_PERIOD + 0.01)
    T.eq(p.components.ds_shrouden.enabled, false)
end)
T.test("local player deactivation cancels updates and pending dodge", function()
    DS_BOSS_REGISTRY.shrouden = {}
    local p = player()
    hooks.prefabs.shrouden(T.entity("shrouden", 10, 0, "idle"))
    local plan = p.components.ds_shrouden
    local cancelled = false
    plan.blink.Cancel = function() cancelled = true end
    p:PushEvent("playerdeactivated")
    T.eq(plan.enabled, false)
    T.eq(cancelled, true)
    T.eq(p.components.ds_bosswatcher.task, nil)
    T.eq(p.updating, nil)
end)
T.test("reactivation starts the watcher again without duplicate components", function()
    DS_BOSS_REGISTRY.shrouden = {}
    local p = player()
    local original = p.components.ds_shrouden
    p:PushEvent("playerdeactivated")
    p:PushEvent("playeractivated")
    hooks.prefabs.shrouden(T.entity("shrouden", 10, 0, "idle"))
    T.eq(p.components.ds_shrouden, original)
    T.eq(original.enabled, true)
end)
T.test("component requests only a currently dangerous loaded boss", function()
    DS_BOSS_REGISTRY.shrouden = {}
    local p = player()
    p.x = 8
    local b = T.entity("shrouden", 0, 0, "idle")
    hooks.prefabs.shrouden(b)
    local plan, requests = p.components.ds_shrouden, 0
    plan.blink.Start = function(_, boss, phase)
        T.eq(boss, b) T.eq(phase, "portal") requests = requests + 1 return true
    end
    plan:OnUpdate(1)
    T.eq(requests, 0)
    b.animation = "punch_pre"
    plan:OnUpdate(1)
    T.eq(requests, 1)
end)
T.summary()
