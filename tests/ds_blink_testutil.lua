local T = dofile("tests/ds_testutil.lua")
local scripts = os.getenv("DS_GAME_SCRIPTS")
    or "F:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts"
local function source(file)
    local handle = assert(io.open(scripts .. "/" .. file))
    local text = handle:read("*a") handle:close() return text
end
local realcontroller = T.controller_methods()
local controller_source = source("components/playercontroller.lua")
local first = assert(controller_source:find("function PlayerController:OnRemoteRightClick(", 1, true))
local last = assert(controller_source:find("function PlayerController:RemapMapAction(", first, true))
local scope = setmetatable({ PlayerController = realcontroller }, { __index = _G })
local chunk = assert(loadstring(controller_source:sub(first, last - 1)))
setfenv(chunk, scope) chunk()
package.preload.equipslotutil = function() return { ToID = function(slot) return slot == "hands" and 2 or 1 end } end
CONTROL_SECONDARY = 1
SetClientRequestedAction = function() end
ClearClientRequestedAction = function() end
local rpc_source = source("networkclientrpc.lua")
local rpc_names = { "PutAllOfActiveItemInSlot", "TakeActiveItemFromAllOfSlot", "TakeActiveItemFromEquipSlot", "RightClick", "ControllerAltActionButtonPoint" }
local rpc_scope = setmetatable({
    checkuint = function(v) return type(v) == "number" and v >= 0 and v % 1 == 0 end,
    checknumber = function(v) return type(v) == "number" end,
    optentity = function(v) return v == nil or type(v) == "table" end,
    optnumber = function(v) return v == nil or type(v) == "number" end,
    optbool = function(v) return v == nil or type(v) == "boolean" end,
    checkbool = function(v) return v == nil or type(v) == "boolean" end,
    optstring = function(v) return v == nil or type(v) == "string" end,
    printinvalid = function(name) error("invalid RPC: " .. name) end,
    printinvalidplatform = function() end,
    IsPointInRange = function() return true end,
    IsRotationValid = function() return true end,
    ConvertPlatformRelativePositionToAbsolutePosition = function(x, z, platform, relative)
        if relative then return platform.x + x, platform.z + z end
        return x, z
    end,
}, { __index = _G })
local handlers = {}
for _, name in ipairs(rpc_names) do
    local start = assert(rpc_source:find("    " .. name .. " = function", 1, true))
    local finish = assert(rpc_source:find("\n    [%w_]+ = function", start + 1))
    local load = assert(loadstring("return {\n" .. rpc_source:sub(start, finish - 1) .. "\n}"))
    setfenv(load, rpc_scope)
    handlers[name] = load()[name]
end

function T.item(prefab, gem)
    local item = T.entity(prefab)
    item.usage = { percent = prefab == "orangestaff" and 100 or 255, charge = prefab == "king_cane" and 180 or 255 }
    item.replica.inventoryitem = { IsLockedInSlot = function() return false end, classified = {
        percentused = { value = function() return item.usage.percent end },
        recharge = { value = function() return item.usage.charge end },
    } }
    item.replica.equippable = { EquipSlot = function() return "hands" end, IsRestricted = function() return false end }
    if prefab == "orangestaff" or gem then item.components.reticule = {} end
    if gem then item._gem = { value = function() return gem end } item.tags.rechargeable = true end
    return item
end
local function copy(values) local ret = {} for key, value in pairs(values) do ret[key] = value end return ret end
function T.fixture(mode)
    local Blink = require("ds_blink")
    local f = { calls = {}, queue = {}, delivered = 0, mode = mode, executed = {}, events = {} }
    local player = T.entity("wilson", 8, 0)
    local server = T.entity("wilson", 8, 0)
    f.player, f.server = player, server
    f.boss = T.entity("shrouden", 0, 0, "punch_pre")
    ThePlayer = player
    ACTIONS = { BLINK = { code = 37, invalid_hold_action = true } }
    RPC = { RightClick = "RightClick", ControllerAltActionButtonPoint = "ControllerAltActionButtonPoint",
        PutAllOfActiveItemInSlot = "PutAllOfActiveItemInSlot", TakeActiveItemFromAllOfSlot = "TakeActiveItemFromAllOfSlot",
        TakeActiveItemFromEquipSlot = "TakeActiveItemFromEquipSlot" }
    local function inventory(owner)
        local inv = { inst = owner, slots = {}, equips = {}, size = 4, souls = false }
        function inv:GetItems() return self.slots end
        function inv:GetEquips() return self.equips end
        function inv:GetItemInSlot(slot) return self.slots[slot] end
        function inv:GetEquippedItem(slot) return self.equips[slot] end
        function inv:GetActiveItem() return self.active end
        function inv:GetOverflowContainer() return self.overflow end
        function inv:GetNumSlots() return self.size end
        function inv:CanTakeItemInSlot() return true end
        function inv:Has(prefab) return prefab == "wortox_soul" and self.souls end
        return inv
    end
    local si, ci = inventory(server), inventory(player)
    f.inventory, f.serverinventory = ci, si
    ci.classified = { IsBusy = function() return ci.busy == true end }
    server.components.inventory = si
    player.replica.inventory, server.replica.inventory = ci, si
    player.CanSoulhop = function() return ci.souls end
    server.CanSoulhop = function() return si.souls end
    local function queue(name, ...)
        local request = { name = name, args = { ... }, n = select("#", ...), at = GetTime() }
        f.calls[#f.calls + 1] = request
        f.queue[#f.queue + 1] = request
    end
    SendRPCToServer = queue
    function si:PutAllOfActiveItemInSlot(slot)
        if self.active and self.slots[slot] == nil then self.slots[slot], self.active = self.active, nil end
    end
    function si:TakeActiveItemFromAllOfSlot(slot)
        if self.active == nil then self.active, self.slots[slot] = self.slots[slot], nil end
    end
    function si:TakeActiveItemFromEquipSlot(slot)
        if self.active == nil then self.active, self.equips[slot] = self.equips[slot], nil end
    end
    function si:TakeActiveItemFromEquipSlotID(id) T.eq(id, 2) self:TakeActiveItemFromEquipSlot("hands") end
    function si:SwapActiveItemWithSlot(slot) self.active, self.slots[slot] = self.slots[slot], self.active end
    function si:EquipActiveItem()
        if self.equips.hands == nil then self.equips.hands, self.active = self.active, nil end
    end
    function si:UseItemFromInvTile(item)
        if self.active then return end
        for slot, value in pairs(self.slots) do
            if value == item then self.slots[slot], self.equips.hands = nil, item return end
        end
        if self.overflow then
            for slot, value in pairs(self.overflow.slots) do
                if value == item then self.overflow.slots[slot], self.equips.hands = nil, item return end
            end
        end
    end
    function si:EquipActionItem(item)
        local old = self.equips.hands
        if old ~= nil and old ~= item then
            local dest, slot = DS_FindEmptySlot(self, old)
            assert(dest, "batch would drop old weapon")
            dest.slots[slot] = old
        end
        self.equips.hands = item
        if self.active == item then self.active = nil end
    end
    local function localcommand(name, ...)
        if ci.busy then return end
        ci.busy = true
        queue("cleanup:" .. name, ...)
    end
    for _, name in ipairs({ "PutAllOfActiveItemInSlot", "TakeActiveItemFromAllOfSlot", "TakeActiveItemFromEquipSlot", "SwapActiveItemWithSlot", "EquipActiveItem", "UseItemFromInvTile" }) do
        ci[name] = function(_, ...) return localcommand(name, ...) end
    end
    local function pc(owner, inv, ishost)
        local controller = { inst = owner, ismastersim = ishost, remote_controls = {} }
        function controller:IsEnabled() return not self.disabled end
        function controller:IsBusy() return self.busy == true end
        function controller:CanLocomote() return true end
        function controller:DecodeControlMods() end
        function controller:ClearControlMods() end
        function controller:GetPlatformRelativePosition(x, z)
            if f.platform then return f.platform, x - f.platform.x, z - f.platform.z end
            return nil, x, z
        end
        controller.DoActionAutoEquip = realcontroller.DoActionAutoEquip
        function controller:DoAction(act)
            self.last = act
            return realcontroller.DoAction(self, act)
        end
        controller.locomotor = { PushAction = function(_, act) f.executed[#f.executed + 1] = act end }
        owner.GetBufferedAction = function() return nil end
        return controller
    end
    local cpc, spc = pc(player, ci, false), pc(server, si, true)
    if mode == "nopredict" then cpc.locomotor = nil end
    spc.OnRemoteRightClick = realcontroller.OnRemoteRightClick
    player.components.playercontroller, server.components.playercontroller = cpc, spc
    f.controller = cpc
    local function picker(owner, inv)
        local p = {}
        local function action(point, item)
            return { action = ACTIONS.BLINK, invobject = item, target = nil,
                GetActionPoint = function() return point end, IsValid = function() return true end }
        end
        function p:GetPointActions(point, item, right, target)
            T.eq(right, true) T.eq(target, nil)
            return not f.blocked and DS_IsBlinkStaff(item) and { action(point, item) } or {}
        end
        function p:GetRightClickActions(point, target)
            return self:GetPointActions(point, inv.active or inv.equips.hands, true, target)
        end
        function p:GetPointSpecialActions(point, useitem, right)
            T.eq(useitem, nil) T.eq(right, true)
            return not f.blocked and inv.souls and { action(point, nil) } or {}
        end
        function p:DoGetMouseActions(point, target) return nil, self:GetRightClickActions(point, target)[1] end
        return p
    end
    player.components.playeractionpicker, server.components.playeractionpicker = picker(player, ci), picker(server, si)
    function spc:OnRemoteControllerAltActionButtonPoint(code, point, released, noforce, special)
        T.eq(special, true)
        local act = server.components.playeractionpicker:GetPointSpecialActions(point, nil, true)[1]
        if act then self:DoAction(act) end
    end
    TheWorld = { Map = { IsPassableAtPoint = function() return true end, IsAboveGroundAtPoint = function() return true end,
        IsGroundTargetBlocked = function() return false end, GetPlatformAtPoint = function() return nil end } }
    TheSim = { FindEntities = function() return {} end }
    IsTeleportingPermittedFromPointToPoint = function() return true end
    CanEntitySeePoint = function() return true end
    env = {} dofile("main/toolutil.lua")
    f.blink = Blink(player)
    function f:Backpack(size)
        local entity = T.entity("backpack")
        local serverentity = T.entity("backpack")
        local pack, serverpack = inventory(entity), inventory(serverentity)
        pack.size, serverpack.size = size or 2, size or 2
        pack.busy, pack.open = false, true
        function pack:IsOpenedBy() return self.open end
        function pack:IsBusy() return self.busy end
        function serverpack:IsOpenedBy() return pack.open end
        function serverpack:PutAllOfActiveItemInSlot(slot)
            if si.active and self.slots[slot] == nil then self.slots[slot], si.active = si.active, nil end
        end
        function serverpack:TakeActiveItemFromAllOfSlot(slot)
            if si.active == nil then si.active, self.slots[slot] = self.slots[slot], nil end
        end
        function serverpack:SwapActiveItemWithSlot(slot) si.active, self.slots[slot] = self.slots[slot], si.active end
        function pack:PutAllOfActiveItemInSlot(slot)
            if pack.busy or ci.busy then return end
            pack.busy, ci.busy = true, true
            queue("PutAllOfActiveItemInSlot", slot, entity)
        end
        function pack:TakeActiveItemFromAllOfSlot(slot)
            if pack.busy or ci.busy then return end
            pack.busy, ci.busy = true, true
            queue("TakeActiveItemFromAllOfSlot", slot, entity)
        end
        function pack:SwapActiveItemWithSlot(slot)
            if pack.busy or ci.busy then return end
            pack.busy, ci.busy = true, true
            queue("cleanup:PackSwap", slot)
        end
        function si:PackSwap(slot) serverpack:SwapActiveItemWithSlot(slot) end
        serverentity.components.container = serverpack
        ci.overflow, si.overflow = pack, serverpack
        f.pack, f.serverpack = pack, serverpack
        return pack
    end
    function f:Seed()
        si.slots, si.equips, si.active, si.souls = copy(ci.slots), copy(ci.equips), ci.active, ci.souls
        si.size = ci.size
        if self.pack then self.serverpack.slots = copy(self.pack.slots) end
        if mode == "host" then
            player.components.inventory = si
            player.replica.inventory = si
            spc.inst = player
            player.components.playercontroller = spc
            player.components.playeractionpicker = picker(player, si)
            f.inventory, f.controller = si, spc
        end
    end
    function f:Deliver(limit)
        limit = limit or #self.queue
        while self.delivered < math.min(limit, #self.queue) do
            self.delivered = self.delivered + 1
            local request = self.queue[self.delivered]
            if request.name:sub(1, 8) == "cleanup:" then
                local name = request.name:sub(9)
                si[name](si, unpack(request.args, 1, request.n))
            else
                local args = copy(request.args)
                if self.pack and args[2] == self.pack.inst then args[2] = self.serverpack.inst end
                handlers[request.name](server, unpack(args, 1, request.n))
            end
        end
    end
    function f:Sync()
        ci.slots, ci.equips, ci.active, ci.souls = copy(si.slots), copy(si.equips), si.active, si.souls
        ci.busy = false
        if self.pack then self.pack.slots, self.pack.busy = copy(self.serverpack.slots), false end
    end
    function f:Move()
        local act = assert(self.executed[#self.executed], "server did not accept blink")
        local point = act:GetActionPoint()
        player.x, player.z = point.x, point.z
        return point
    end
    function f:Recover()
        for _ = 1, 35 do self:Deliver() self:Sync() T.advance(0.1) end
    end
    return f
end
return T
