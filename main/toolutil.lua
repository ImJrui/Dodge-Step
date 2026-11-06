local PLENV = env
GLOBAL.setfenv(1, GLOBAL)

function DS_Log(level, ...)
    level = string.upper(tostring(level))
    local priority = DS_LOG_LEVEL[level]
    if priority == nil or priority < DS_CONFIG.DEBUG_MODE then
        return
    end

    local messages = {}
    for index = 1, select("#", ...) do
        messages[index] = tostring(select(index, ...))
    end
    print("[DS_DodgeStep] " .. level .. ": " .. table.concat(messages, " "))
end

function DS_GetString(key, ...)
    if type(key) ~= "string" then
        return tostring(key)
    end

    local value = STRINGS.DS_MOD
    for part in string.gmatch(key, "[^%.]+") do
        if type(value) ~= "table" then
            return key
        end
        value = value[part]
    end
    if type(value) ~= "string" then
        return key
    end
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end
    return value
end

function DS_IsBossLoaded(boss)
    return boss ~= nil and boss:IsValid() and not boss:IsInLimbo() and not boss:IsAsleep()
end

function DS_SetBossLoaded(boss, loaded)
    local registry = DS_BOSS_REGISTRY[boss.prefab]
    if registry == nil then return end
    registry[boss] = loaded and true or nil
    local watcher = ThePlayer and ThePlayer.components.ds_bosswatcher
    if watcher then watcher:Refresh() end
end

function DS_IsBlinkStaff(item)
    if item == nil or not item:IsValid() or item:HasTag("nomagiccast") then return false end
    if item.replica.inventoryitem and item.replica.inventoryitem:IsLockedInSlot() then return false end
    return item.prefab == "orangestaff"
        or (item.prefab == "king_cane" and item._gem ~= nil and item._gem:value() == "orangegem"
            and item.components.reticule ~= nil)
end

function DS_FindBlinkStaff(inventory)
    local active = inventory:GetActiveItem()
    if DS_IsBlinkStaff(active) then return active, { kind = "cursor" } end
    local containers = { inventory, inventory:GetOverflowContainer() }
    for _, container in ipairs(containers) do
        for slot = 1, container:GetNumSlots() do
            local item = container:GetItemInSlot(slot)
            if DS_IsBlinkStaff(item) then return item, { container = container, slot = slot } end
        end
    end
    for slot, item in pairs(inventory:GetEquips()) do
        if DS_IsBlinkStaff(item) then return item, { kind = "equip", slot = slot } end
    end
end

function DS_FindEmptySlot(inventory, item)
    for _, container in ipairs({ inventory, inventory:GetOverflowContainer() }) do
        for slot = 1, container:GetNumSlots() do
            if container:GetItemInSlot(slot) == nil and container:CanTakeItemInSlot(item, slot) then
                return container, slot
            end
        end
    end
end

function DS_BuildLandingValidator(player, boss, mode)
    local bx, _, bz = boss.Transform:GetWorldPosition()
    local blockers = {}
    local player_radius = player:GetPhysicsRadius(0.5)
    for _, entity in ipairs(TheSim:FindEntities(bx, 0, bz, DS_SHROUDEN.ESCAPE_RADIUS + 8, nil, { "INLIMBO" })) do
        if entity ~= player and entity:IsValid() and not entity:IsInLimbo() then
            local clearance = DS_DODGE.HAZARD_CLEARANCE[entity.prefab]
            if clearance == nil and entity.Physics then
                local mask = entity.Physics:GetCollisionMask()
                if math.floor(mask / COLLISION.CHARACTERS) % 2 == 1 then
                    clearance = entity:GetPhysicsRadius(0) + player_radius
                end
            end
            if clearance and clearance > 0 then
                local x, _, z = entity.Transform:GetWorldPosition()
                blockers[#blockers + 1] = { x = x, z = z, radius2 = clearance * clearance }
            end
        end
    end
    return function(point)
        local map = TheWorld.Map
        if not map:IsPassableAtPoint(point:Get()) or map:IsGroundTargetBlocked(point) then return false end
        if mode == "staff" and not map:IsAboveGroundAtPoint(point:Get())
            and map:GetPlatformAtPoint(point.x, point.z) == nil then return false end
        local px, py, pz = player.Transform:GetWorldPosition()
        if not IsTeleportingPermittedFromPointToPoint(px, py, pz, point.x, 0, point.z) then return false end
        if CanEntitySeePoint and not CanEntitySeePoint(player, point:Get()) then return false end
        for _, blocker in ipairs(blockers) do
            local dx, dz = point.x - blocker.x, point.z - blocker.z
            if dx * dx + dz * dz < blocker.radius2 - 0.000001 then return false end
        end
        return true
    end
end

function DS_IsInventoryBusy(inventory)
    local components = inventory.inst and inventory.inst.components
    if components and (components.inventory or components.container) then return false end
    if inventory.IsBusy then return inventory:IsBusy() end
    if inventory.classified then return inventory.classified:IsBusy() end
    return inventory.inst ~= nil
end

function DS_FindCarriedSlot(inventory, target)
    for _, container in ipairs({ inventory, inventory:GetOverflowContainer() }) do
        for slot, item in pairs(container:GetItems()) do
            if item == target then return container, slot end
        end
    end
    return false
end
