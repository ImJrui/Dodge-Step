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

local function container_available(container, inventory, player)
    return container == inventory or (container.inst ~= nil and container.inst:IsValid()
        and container:IsOpenedBy(player))
end

local function prepare_inventory(player, operation)
    local inventory = player.replica.inventory
    local active = inventory:GetActiveItem()
    local stash, stashslot
    if active and active ~= operation.tool then
        stash, stashslot = DS_FindEmptySlot(inventory, active)
        if stash == nil then return nil, "inventory_full" end
        if not container_available(stash, inventory, player) then return nil, "container_closed" end
        if DS_IsInventoryBusy(stash) then return nil, "busy" end
    end
    local source = operation.source
    if source and source.container then
        if not container_available(source.container, inventory, player) then return nil, "container_closed" end
        if DS_IsInventoryBusy(source.container) then return nil, "busy" end
        if source.container:GetItemInSlot(source.slot) ~= operation.tool then return nil, "resource_changed" end
    elseif source and source.kind == "equip" then
        if inventory:GetNumSlots() == 0 then return nil, "inventory_full" end
        if inventory:GetEquippedItem(source.slot) ~= operation.tool then return nil, "resource_changed" end
    elseif source and active ~= operation.tool then
        return nil, "cursor_changed"
    end
    local previous = inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if operation.tool and previous ~= operation.tool and (previous or source.kind == "cursor") then
        local stored = previous or operation.tool
        local room = false
        for _, container in ipairs({ inventory, inventory:GetOverflowContainer() }) do
            if container_available(container, inventory, player) and not DS_IsInventoryBusy(container) then
                for slot = 1, container:GetNumSlots() do
                    local freed = source.container == container and source.slot == slot
                    local occupied = container:GetItemInSlot(slot) ~= nil and not freed
                    if not occupied and not (stash == container and stashslot == slot)
                        and container:CanTakeItemInSlot(stored, slot) then room = true break end
                end
            end
        end
        if not room then return nil, "inventory_full" end
    end
    return { stash = stash, stashslot = stashslot, cursor = active, previoushands = previous }
end

function Blink:Restore(operation)
    if operation == nil or not operation.sent then return end
    local player, tool = self.player, operation.tool
    local deadline = GetTime() + DS_DODGE.RECOVERY_TIMEOUT
    local function restore()
        if player ~= ThePlayer or not player:IsValid() then return true end
        local inventory, controller = player.replica.inventory, player.components.playercontroller
        if inventory == nil then return true end
        if (controller and controller:IsBusy()) or DS_IsInventoryBusy(inventory) then return false end
        local active, equipped = inventory:GetActiveItem(), inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if not operation.inventory_seen then
            operation.inventory_seen = (operation.completed and operation.source and operation.source.kind == "equip")
                or not tool
                or (equipped == tool and operation.source.kind ~= "equip")
                or (active == tool and operation.source.kind ~= "cursor")
            if not operation.inventory_seen then return false end
        end
        local previous = operation.previoushands
        if active and active ~= tool and active ~= previous and active ~= operation.cursor then return true end
        local restore_weapon = previous and previous:IsValid()
        if restore_weapon and equipped ~= previous and (equipped == nil or equipped == tool) then
            if active == previous and equipped == nil then
                inventory:EquipActiveItem()
                return false
            elseif active == tool then
                local container, slot = DS_FindCarriedSlot(inventory, previous)
                if container and container_available(container, inventory, player) then
                    if DS_IsInventoryBusy(container) then return false end
                    if container:CanTakeItemInSlot(tool, slot) then
                        operation.waitcontainer = container
                        container:SwapActiveItemWithSlot(slot)
                        return false
                    end
                end
            elseif active == nil then
                if equipped == tool then
                    inventory:TakeActiveItemFromEquipSlot(EQUIPSLOTS.HANDS)
                    return false
                end
                local container = DS_FindCarriedSlot(inventory, previous)
                if container then
                    if DS_IsInventoryBusy(container) then return false end
                    inventory:UseItemFromInvTile(previous)
                    return false
                end
            end
        elseif tool and equipped == tool and previous ~= tool and active == nil then
            if inventory:GetNumSlots() == 0 then return true end
            inventory:TakeActiveItemFromEquipSlot(EQUIPSLOTS.HANDS)
            return false
        end
        -- Recovery always empties operation-owned cursor items instead of restoring a cursor staff.
        if active then
            local container, slot = DS_FindEmptySlot(inventory, active)
            if not container then return false end
            if not container_available(container, inventory, player) then return false end
            if DS_IsInventoryBusy(container) then return false end
            operation.waitcontainer = container
            container:PutAllOfActiveItemInSlot(slot)
            return false
        end
        if operation.waitcontainer and DS_IsInventoryBusy(operation.waitcontainer) then return false end
        return true
    end
    if self.recovery then self.recovery:Cancel() self.recovery = nil end
    if restore() then return end
    self.recovery = player:DoPeriodicTask(0.1, function()
        local done = restore()
        if done or GetTime() >= deadline then
            self.recovery:Cancel()
            self.recovery = nil
            if not done then DS_Log("WARN", "Blink inventory recovery timed out") end
        end
    end)
end

function Blink:Finish(result, reason)
    local operation = self.pending
    self.pending = nil
    if operation then operation.completed = result == "success" end
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
    end
    self.pending = { boss = boss, phase = phase, mode = soul and "soul" or "staff", tool = tool,
        source = source, deadline = GetTime() + DS_DODGE.PREPARE_TIMEOUT }
    return true
end

function Blink:Submit(operation)
    local player = self.player
    local inventory, controller = player.replica.inventory, player.components.playercontroller
    if DS_IsInventoryBusy(inventory) or controller:IsBusy() then return end
    if operation.mode == "soul" then
        if not player:CanSoulhop() or not inventory:Has("wortox_soul", 1) then return self:Finish("failed", "no_resource") end
    elseif not DS_IsBlinkStaff(operation.tool) then
        return self:Finish("failed", "no_resource")
    end
    local prepared, reason = prepare_inventory(player, operation)
    if not prepared then
        if reason == "busy" then return end
        return self:Finish("failed", reason)
    end
    local safe = DS_BuildLandingValidator(player, operation.boss, operation.mode)
    local point = Plan.FindLanding(operation.boss, player, operation.phase, safe)
    if not point then return self:Finish("failed", "no_landing") end
    local picker = player.components.playeractionpicker
    local actions = operation.mode == "soul" and picker:GetPointSpecialActions(point, nil, true)
        or picker:GetPointActions(point, operation.tool, true, nil)
    local action = actions[1]
    if not action or action.action ~= ACTIONS.BLINK or action.invobject ~= operation.tool then
        return self:Finish("failed", "no_action")
    end
    local source = operation.source
    local equipid = source and source.kind == "equip" and require("equipslotutil").ToID(source.slot) or nil
    if source and source.kind == "equip" and equipid == nil then return self:Finish("failed", "equip_slot") end
    operation.previoushands, operation.cursor = prepared.previoushands, prepared.cursor
    operation.point = point
    local x, _, z = player.Transform:GetWorldPosition()
    operation.ox, operation.oz = x, z
    operation.stage, operation.sent = "inflight", true
    operation.deadline = GetTime() + DS_DODGE.BLINK_TIMEOUT
    if controller.ismastersim then
        if prepared.stash then prepared.stash:PutAllOfActiveItemInSlot(prepared.stashslot) end
        if operation.mode == "staff" and inventory:GetActiveItem() ~= operation.tool then
            if source.kind == "equip" then inventory:TakeActiveItemFromEquipSlot(source.slot)
            else source.container:TakeActiveItemFromAllOfSlot(source.slot) end
        end
        if inventory:GetActiveItem() ~= operation.tool then return self:Finish("failed", "inventory_changed") end
        controller:DoAction(action)
    else
        -- Original server RPC handlers process these requests in order; no local busy prediction is changed.
        if prepared.stash then
            SendRPCToServer(RPC.PutAllOfActiveItemInSlot, prepared.stashslot,
                prepared.stash ~= inventory and prepared.stash.inst or nil)
        end
        if source and source.kind == "equip" then
            SendRPCToServer(RPC.TakeActiveItemFromEquipSlot, equipid)
        elseif source and source.container then
            SendRPCToServer(RPC.TakeActiveItemFromAllOfSlot, source.slot,
                source.container ~= inventory and source.container.inst or nil)
        end
        local platform, px, pz = controller:GetPlatformRelativePosition(point.x, point.z)
        if operation.mode == "soul" then
            SendRPCToServer(RPC.ControllerAltActionButtonPoint, ACTIONS.BLINK.code, px, pz,
                true, true, true, ACTIONS.BLINK.mod_name, platform, platform ~= nil)
        else
            SendRPCToServer(RPC.RightClick, ACTIONS.BLINK.code, px, pz, nil, nil,
                true, 0, true, ACTIONS.BLINK.mod_name, platform, platform ~= nil)
        end
    end
    DS_Log("DEBUG", "Blink batch requested", operation.phase, operation.mode)
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
        if dx * dx + dz * dz >= DS_DODGE.MIN_BLINK_DISTANCE ^ 2 and ex * ex + ez * ez <= 4 then
            return self:Finish("success")
        elseif GetTime() >= operation.deadline then return self:Finish("failed", "timeout") end
        return
    end
    if Plan.GetThreat(operation.boss, player) ~= operation.phase then return self:Finish("failed", "expired") end
    if GetTime() >= operation.deadline then return self:Finish("failed", "timeout") end
    return self:Submit(operation)
end

function Blink:Cancel()
    if self.pending then self:Finish("failed", "cancelled") end
end

function Blink:OnRemoveEntity()
    self.pending = nil
    if self.recovery then self.recovery:Cancel() self.recovery = nil end
end

return Blink
