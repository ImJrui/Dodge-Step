local T = dofile("tests/ds_testutil.lua")
local Plan = require("ds_shroudenplan")
local skills = {
    { key = "DS_PORTAL_DISTANCE", phase = "portal", animation = "punch_pre", default = 12,
        values = { 10, 11, 12, 13, 14, 15, 16, 17, 18 }, step = 1 },
    { key = "DS_PUDDLE_DISTANCE", phase = "puddle", animation = "teleport_loop", default = 4.5,
        values = { 4, 4.5, 5, 5.5, 6 }, step = 0.5 },
    { key = "DS_LASER_DISTANCE", phase = "laser", animation = "optic_blast_pre2", default = 7,
        values = { 6, 6.5, 7, 7.5, 8 }, step = 0.5 },
}

local function configure(values)
    env = { GetModConfigData = function(key) return values[key] end }
    dofile("main/constants.lua")
end
local function check_boundary(skill, distance)
    local boss = T.entity("shrouden", 0, 0, skill.animation)
    local player = T.entity("wilson", distance, 0)
    T.eq(Plan.GetThreat(boss, player), skill.phase, skill.key .. " boundary")
    player.x = distance + 0.01
    T.eq(Plan.GetThreat(boss, player), nil, skill.key .. " outside")
end
local function radius(point)
    return math.sqrt(point.x * point.x + point.z * point.z)
end

T.test("configuration menu exposes every requested distance and localized disable option", function()
    for _, locale in ipairs({ "en", "zh", "fr" }) do
        local metadata = { locale = locale }
        setfenv(assert(loadfile("modinfo.lua")), metadata)()
        local options = {}
        for _, option in ipairs(metadata.configuration_options) do options[option.name] = option end
        for _, skill in ipairs(skills) do
            local option = assert(options[skill.key], "missing option: " .. skill.key)
            T.eq(option.default, skill.default)
            T.eq(#option.options, #skill.values + 1)
            T.eq(option.options[1].data, false)
            T.eq(option.options[1].description, locale == "zh" and "不躲避" or "Do not dodge")
            assert(type(option.label) == "string" and #option.label > 0)
            assert(type(option.hover) == "string" and #option.hover > 0)
            for index, distance in ipairs(skill.values) do
                T.eq(option.options[index + 1].data, distance)
                T.eq(option.options[index + 1].description, tostring(distance))
            end
        end
    end
end)
T.test("missing settings use the requested default trigger boundaries", function()
    configure({})
    for _, skill in ipairs(skills) do check_boundary(skill, skill.default) end
end)

for _, skill in ipairs(skills) do
    T.test(skill.phase .. " uses every configured trigger distance", function()
        for _, distance in ipairs(skill.values) do
            configure({ [skill.key] = distance })
            check_boundary(skill, distance)
        end
    end)
    T.test(skill.phase .. " can be disabled without disabling other skills", function()
        configure({ [skill.key] = false })
        local boss = T.entity("shrouden", 0, 0, skill.animation)
        T.eq(Plan.GetPhase(boss), skill.phase)
        T.eq(Plan.GetThreat(boss, T.entity("wilson", 0, 0)), nil)
        T.eq(Plan.GetThreat(boss, T.entity("wilson", 1, 4)), nil)
        for _, other in ipairs(skills) do
            if other ~= skill then check_boundary(other, other.default) end
        end
        local checked = 0
        local point = Plan.FindLanding(boss, T.entity("wilson", 0, 0), skill.phase, function()
            checked = checked + 1
            return true
        end)
        T.eq(point, nil)
        T.eq(checked, 0)
    end)
    T.test(skill.phase .. " landing exclusion follows every configured distance", function()
        local boss = T.entity("shrouden", 0, 0, skill.animation)
        local player = T.entity("wilson", 0, 0)
        for _, distance in ipairs(skill.values) do
            configure({ [skill.key] = distance })
            local point = Plan.FindLanding(boss, player, skill.phase, function(pt)
                return radius(pt) <= distance + 0.000001
                    and (skill.phase ~= "portal" or pt.x > 0 and math.abs(pt.z) < 0.000001)
            end)
            T.eq(point, nil, "must reject landings within the configured range")
            point = assert(Plan.FindLanding(boss, player, skill.phase, function() return true end))
            T.eq(Plan.GetThreat(boss, T.entity("wilson", point.x, point.z)), nil)
        end
    end)
end

T.test("all three skills can be disabled together", function()
    configure({ DS_PORTAL_DISTANCE = false, DS_PUDDLE_DISTANCE = false, DS_LASER_DISTANCE = false })
    for _, skill in ipairs(skills) do
        local boss = T.entity("shrouden", 0, 0, skill.animation)
        T.eq(Plan.GetThreat(boss, T.entity("wilson", 0, 0)), nil)
    end
end)
T.test("invalid settings fall back independently to safe defaults", function()
    for _, skill in ipairs(skills) do
        for _, value in ipairs({ true, "disabled", 0, skill.values[1] - skill.step,
            skill.values[#skill.values] + skill.step, skill.values[1] + skill.step / 2,
            math.huge, 0 / 0 }) do
            configure({ [skill.key] = value })
            for _, other in ipairs(skills) do check_boundary(other, other.default) end
        end
    end
end)
T.test("portal rectangle stays active at the smallest configured sector radius", function()
    configure({ DS_PORTAL_DISTANCE = 10 })
    local boss = T.entity("shrouden", 0, 0, "punch_pre")
    T.eq(Plan.GetThreat(boss, T.entity("wilson", 1, 4)), "portal")
    T.eq(Plan.GetThreat(boss, T.entity("wilson", 1, -4)), "portal")
    T.eq(Plan.GetThreat(boss, T.entity("wilson", 10.01, 0)), nil)
end)
configure({})
T.summary()
