local Plan = require("ds_shroudenplan")

local Blink = Class(function(self, player)
    self.player = player
end)

local function ready(player)
    local controller = player.components.playercontroller
    return player == ThePlayer and player:IsValid() and not player:HasTag("playerghost")
        and not player:HasTag("dead") and not player:HasTag("corpse")
        and controller ~= nil and controller:IsEnabled()
        and player.replica.inventory ~= nil and player.components.playeractionpicker ~= nil
end

function Blink:Restore(operation)
    if operation == nil or operation.tool == nil then return end
    local player, source, tool = self.player, operation.source, operation.tool
    local deadline = GetTime() + DS_DODGE.RECOVERY_TIMEOUT
    local function equip_previous(inventory, equipped)
        local previous = operation.previoushands
        if equipped ~= nil or previous == nil or previous == tool or not previous:IsValid()
            or not DS_FindCarriedSlot(inventory, previous) then return true end
        if operation.reequip_at == nil or GetTime() - operation.reequip_at >= 0.25 then
            inventory:UseItemFromInvTile(previous)
            operation.reequip_at = GetTime()
        end
        return false
    end
    local function restore_cursor(inventory, active, equipped)
        local previous, swap = operation.previoushands, operation.cursor_swap
        if swap then
            if DS_IsInventoryBusy(swap.container) then return false end
            if active == tool then return true end
            if active == previous and equipped == nil then
                inventory:EquipActiveItem()
                return false
            elseif active == nil and swap.container:GetItemInSlot(swap.slot) == tool then
                swap.container:TakeActiveItemFromAllOfSlot(swap.slot)
                return false
            end
            return true
        end
        if active ~= nil and active ~= tool then return true end
        if equipped == tool then
            inventory:TakeActiveItemFromEquipSlot(EQUIPSLOTS.HANDS)
            operation.took = true
            return false
        elseif active == tool then
            if equipped ~= nil or previous == nil or not previous:IsValid() then return true end
            local container, slot = DS_FindCarriedSlot(inventory, previous)
            if not container then return true end
            if DS_IsInventoryBusy(container) then return false end
            if not container:CanTakeItemInSlot(tool, slot) then return true end
            operation.cursor_swap = { container = container, slot = slot }
            container:SwapActiveItemWithSlot(slot)
            return false
        end
        return not operation.took
    end
    local function restore()
        local inventory = player.replica.inventory
        if not player:IsValid() or player ~= ThePlayer or inventory == nil or not tool:IsValid() then return true end
        local controller = player.components.playercontroller
        if (controller and controller:IsBusy()) or DS_IsInventoryBusy(inventory)
            or (operation.waitcontainer and DS_IsInventoryBusy(operation.waitcontainer))
            or (source.container and DS_IsInventoryBusy(source.container)) then return false end
        local active, equipped = inventory:GetActiveItem(), inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if source.kind == "cursor" then return restore_cursor(inventory, active, equipped) end
        if active ~= nil and active ~= tool then return true end
        if source.kind == "equip" and equipped == tool then return true end
        if equipped == tool then
            inventory:TakeActiveItemFromEquipSlot(EQUIPSLOTS.HANDS)
            operation.took = true
            return false
        elseif active == tool then
            if source.kind == "equip" and equipped == nil then
                inventory:EquipActiveItem()
            elseif source.container and source.container:GetItemInSlot(source.slot) == nil
                and source.container:CanTakeItemInSlot(tool, source.slot) then
                source.container:PutAllOfActiveItemInSlot(source.slot)
            else
                local container, slot = DS_FindEmptySlot(inventory, tool)
                if container == nil then return true end
                container:PutAllOfActiveItemInSlot(slot)
            end
            operation.returned = true
            return false
        elseif operation.took and not operation.returned then
            return false
        end
        return equip_previous(inventory, equipped)
    end
    if self.recovery then self.recovery:Cancel() self.recovery = nil end
    if restore() then return end
    self.recovery = player:DoPeriodicTask(0.1, function()
        if GetTime() >= deadline or restore() then
            self.recovery:Cancel()
            self.recovery = nil
        end
    end)
end

function Blink:Finish(result, reason)
    local operation = self.pending
    self.pending = nil
    self:Restore(operation)
    return result, reason
end

function Blink:Start(boss, phase)
    if self.pending or self.recovery then return false, "pending" end
    if not ready(self.player) then return false, "unavailable" end
    local inventory = self.player.replica.inventory
    local soul = self.player:HasTag("soulstealer") and inventory:Has("wortox_soul", 1)
        and self.player.CanSoulhop ~= nil and self.player:CanSoulhop()
    local tool, source
    if not soul then
        tool, source = DS_FindBlinkStaff(inventory)
        if tool == nil then return false, "no_resource" end
        if source.kind == "equip" and inventory:GetNumSlots() == 0 then return false, "inventory_full" end
    end
    self.pending = { boss = boss, phase = phase, mode = soul and "soul" or "staff", tool = tool,
        source = source, stage = "prepare", deadline = GetTime() + DS_DODGE.PREPARE_TIMEOUT,
        previoushands = inventory:GetEquippedItem(EQUIPSLOTS.HANDS) }
    return true
end

function Blink:Cast(operation)
    local player = self.player
    local inventory, controller = player.replica.inventory, player.components.playercontroller
    if operation.mode == "soul" then
        if not player:CanSoulhop() or not inventory:Has("wortox_soul", 1) then return self:Finish("failed", "no_resource") end
    elseif not DS_IsBlinkStaff(operation.tool) then
        return self:Finish("failed", "no_resource")
    end
    local hands = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if operation.mode == "staff" and hands ~= nil and hands ~= operation.tool
        and DS_FindEmptySlot(inventory, hands) == nil then
        return self:Finish("failed", "inventory_full")
    end
    local safe = DS_BuildLandingValidator(player, operation.boss, operation.mode)
    local point = Plan.FindLanding(operation.boss, player, operation.phase, safe)
    if point == nil then return self:Finish("failed", "no_landing") end
    local picker = player.components.playeractionpicker
    local actions = operation.mode == "soul" and picker:GetPointSpecialActions(point, nil, true)
        or picker:GetRightClickActions(point, nil)
    local action = actions[1]
    if action == nil or action.action ~= ACTIONS.BLINK or action.invobject ~= operation.tool then
        return self:Finish("failed", "no_action")
    end
    operation.point = point
    local ox, _, oz = player.Transform:GetWorldPosition()
    operation.ox, operation.oz = ox, oz
    operation.stage = "inflight"
    operation.deadline = GetTime() + DS_DODGE.BLINK_TIMEOUT
    local function send()
        if self.pending ~= operation or operation.sent then return end
        if not ready(player) or not DS_IsBossLoaded(operation.boss)
            or Plan.GetThreat(operation.boss, player) ~= operation.phase
            or (operation.mode == "soul" and (inventory:GetActiveItem() ~= nil
                or not player:CanSoulhop() or not inventory:Has("wortox_soul", 1)))
            or (operation.mode == "staff" and not DS_IsBlinkStaff(operation.tool))
            or (operation.mode == "staff" and inventory:GetActiveItem() ~= operation.tool
                and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= operation.tool)
            or not DS_BuildLandingValidator(player, operation.boss, operation.mode)(point) then return end
        local platform, x, z = controller:GetPlatformRelativePosition(point.x, point.z)
        operation.sent = true
        if operation.mode == "soul" then
            SendRPCToServer(RPC.ControllerAltActionButtonPoint, ACTIONS.BLINK.code, x, z,
                true, true, true, ACTIONS.BLINK.mod_name, platform, platform ~= nil)
        else
            -- A nil target forces a point action even when loot covers the destination.
            SendRPCToServer(RPC.RightClick, ACTIONS.BLINK.code, x, z, nil, nil,
                true, 0, true, ACTIONS.BLINK.mod_name, platform, platform ~= nil)
        end
        DS_Log("DEBUG", "Blink requested", operation.phase, operation.mode)
    end
    if controller.ismastersim then
        operation.sent = true
    else
        action.preview_cb = send
        action.non_preview_cb = send
    end
    controller:DoAction(action)
end

function Blink:Update()
    local operation = self.pending
    if operation == nil then return end
    local player = self.player
    if not ready(player) or not DS_IsBossLoaded(operation.boss) then return self:Finish("failed", "unavailable") end
    if operation.stage == "inflight" then
        local px, _, pz = player.Transform:GetWorldPosition()
        local dx, dz = px - operation.ox, pz - operation.oz
        local ex, ez = px - operation.point.x, pz - operation.point.z
        if operation.sent and dx * dx + dz * dz >= DS_DODGE.MIN_BLINK_DISTANCE ^ 2 and ex * ex + ez * ez <= 4 then
            return self:Finish("success")
        elseif GetTime() >= operation.deadline then
            return self:Finish("failed", "timeout")
        end
        return
    end
    if Plan.GetThreat(operation.boss, player) ~= operation.phase then return self:Finish("failed", "expired") end
    if GetTime() >= operation.deadline then return self:Finish("failed", "timeout") end
    local inventory = player.replica.inventory
    if DS_IsInventoryBusy(inventory)
        or (operation.waitcontainer and DS_IsInventoryBusy(operation.waitcontainer)) then return end
    operation.waitcontainer = nil
    local active = inventory:GetActiveItem()
    if operation.stage == "stash" then
        if active == operation.cursor then return end
        if active ~= nil then return self:Finish("failed", "cursor_changed") end
        operation.stage = "prepare"
    elseif operation.stage == "take" then
        if active == nil then return end
        if active ~= operation.tool then return self:Finish("failed", "cursor_changed") end
    end
    local controller = player.components.playercontroller
    if controller:IsBusy() then return end
    if active ~= nil and not (operation.mode == "staff" and active == operation.tool) then
        local container, slot = DS_FindEmptySlot(inventory, active)
        if container == nil then return self:Finish("failed", "inventory_full") end
        operation.cursor, operation.stage = active, "stash"
        operation.waitcontainer = container
        container:PutAllOfActiveItemInSlot(slot)
        return
    end
    if operation.mode == "staff" and active == nil then
        local tool, source = DS_FindBlinkStaff(inventory)
        if tool ~= operation.tool then return self:Finish("failed", "resource_changed") end
        operation.source = source
        operation.stage = "take"
        operation.took = true
        operation.waitcontainer = source.container
        if source.container and DS_IsInventoryBusy(source.container) then
            operation.stage = "prepare"
            operation.took = false
            return
        end
        if source.kind == "equip" then
            inventory:TakeActiveItemFromEquipSlot(source.slot)
        else
            source.container:TakeActiveItemFromAllOfSlot(source.slot)
        end
        return
    end
    return self:Cast(operation)
end

function Blink:Cancel()
    if self.pending then self:Finish("failed", "cancelled") end
end

function Blink:OnRemoveEntity()
    self.pending = nil
    if self.recovery then self.recovery:Cancel() self.recovery = nil end
end

return Blink
