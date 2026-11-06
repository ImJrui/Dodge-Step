local Plan = {}
local cos, sin, sqrt, ceil = math.cos, math.sin, math.sqrt, math.ceil
local radians = math.pi / 180

function Plan.GetPhase(boss)
    local anim = boss.AnimState
    if anim:IsCurrentAnimation("punch_pre") or anim:IsCurrentAnimation("punch_loop") then
        return "portal"
    elseif anim:IsCurrentAnimation("optic_blast_pre2")
        or anim:IsCurrentAnimation("optic_blast_pre3")
        or anim:IsCurrentAnimation("optic_blast_loop") then
        return "laser"
    elseif anim:IsCurrentAnimation("teleport_loop") then
        return "puddle"
    end
end

function Plan.GetThreat(boss, player)
    local phase = Plan.GetPhase(boss)
    if phase == nil then return end
    local bx, _, bz = boss.Transform:GetWorldPosition()
    local px, _, pz = player.Transform:GetWorldPosition()
    local dx, dz = px - bx, pz - bz
    local dist2 = dx * dx + dz * dz
    if phase == "portal" then
        local heading = boss.Transform:GetRotation() * radians
        local dot = dx * cos(heading) - dz * sin(heading)
        if dist2 <= DS_SHROUDEN.FRONT_RADIUS ^ 2 + 0.000001
            and dot >= sqrt(dist2) * cos(DS_SHROUDEN.HALF_ANGLE * radians) - 0.000001 then
            return phase
        end
    elseif dist2 <= (phase == "laser" and DS_SHROUDEN.LASER_RADIUS or DS_SHROUDEN.PUDDLE_RADIUS) ^ 2 then
        return phase
    end
end

function Plan.FindLanding(boss, player, phase, canland)
    local bx, _, bz = boss.Transform:GetWorldPosition()
    local px, _, pz = player.Transform:GetWorldPosition()
    local behind = boss.Transform:GetRotation() * radians + math.pi
    local function candidate(radius, angle)
        if phase == "laser" and radius <= DS_SHROUDEN.LASER_RADIUS then return end
        if phase == "puddle" and radius <= DS_SHROUDEN.PUDDLE_RADIUS then return end
        if phase == "portal" and radius <= DS_SHROUDEN.FRONT_RADIUS
            and cos(angle - behind + math.pi) >= cos(DS_SHROUDEN.HALF_ANGLE * radians) - 0.000001 then return end
        local pt = Vector3(bx + radius * cos(angle), 0, bz - radius * sin(angle))
        local dx, dz = pt.x - px, pt.z - pz
        local distance = dx * dx + dz * dz
        if distance <= DS_DODGE.MAX_BLINK_DISTANCE ^ 2
            and distance >= DS_DODGE.MIN_BLINK_DISTANCE ^ 2
            and canland(pt) then
            return pt
        end
    end
    if phase == "portal" then
        for radius = DS_SHROUDEN.REAR_INNER + DS_SHROUDEN.REAR_STEP,
            DS_SHROUDEN.REAR_OUTER, DS_SHROUDEN.REAR_STEP do
            local pt = candidate(radius, behind)
            if pt then return pt end
            local steps = ceil(DS_SHROUDEN.HALF_ANGLE * radians * radius / DS_SHROUDEN.ARC_STEP)
            for index = 1, steps do
                local delta = DS_SHROUDEN.HALF_ANGLE * radians * index / steps
                pt = candidate(radius, behind + delta) or candidate(radius, behind - delta)
                if pt then return pt end
            end
        end
    end
    for radius = DS_SHROUDEN.ESCAPE_RADIUS, DS_SHROUDEN.ESCAPE_STEP, -DS_SHROUDEN.ESCAPE_STEP do
        local steps = ceil(2 * math.pi * radius / DS_SHROUDEN.ARC_STEP)
        for index = 0, steps - 1 do
            local pt = candidate(radius, behind + index * 2 * math.pi / steps)
            if pt then return pt end
        end
    end
end

return Plan
