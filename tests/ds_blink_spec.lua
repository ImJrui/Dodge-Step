local T = dofile("tests/ds_testutil.lua")
local Blink = require("ds_blink")
local realcontroller = T.controller_methods()
local function item(prefab, gem)
    local i = T.entity(prefab)
    i.replica.inventoryitem = { IsLockedInSlot = function() return false end }
    i.replica.equippable = { EquipSlot = function() return EQUIPSLOTS.HANDS end, IsRestricted = function() return false end }
    if prefab == "orangestaff" or gem then i.components.reticule = {} end
    if gem then i._gem = { value = function() return gem end } end
    return i
end
local function fixture(mode)
    local p = T.entity("wilson", 8, 0)
    local b = T.entity("shrouden", 0, 0, "punch_pre")
    ThePlayer = p
    local inv = { slots = {}, equips = {}, pending = {}, moves = {}, active = nil, souls = false }
    inv.classified = { IsBusy = function() return inv.busy == true end }
    function inv:GetItems() return self.slots end
    function inv:GetEquips() return self.equips end
    function inv:GetItemInSlot(slot) return self.slots[slot] end
    function inv:GetEquippedItem(slot) return self.equips[slot] end
    function inv:GetActiveItem() return self.active end
    function inv:GetNumSlots() return 3 end
    function inv:GetOverflowContainer() return self.overflow end
    function inv:CanTakeItemInSlot() return true end
    function inv:Has(prefab) return prefab == "wortox_soul" and self.souls end
    function inv:PutAllOfActiveItemInSlot(slot)
        if self.busy then return end
        if self.predicted then
            local old = self.active
            self.moves[#self.moves + 1] = { "put", slot }
            self.slots[slot], self.active, self.busy = old, nil, true
            self.pending[#self.pending + 1] = function() self.busy = false end
            return
        end
        self.moves[#self.moves + 1] = { "put", slot }
        local expected = self.active
        self.pending[#self.pending + 1] = function()
            assert(self.slots[slot] == nil)
            self.slots[slot], self.active = expected, nil
        end
    end
    function inv:TakeActiveItemFromAllOfSlot(slot)
        if self.busy then return end
        if self.predicted then
            self.moves[#self.moves + 1] = { "take", slot }
            self.active, self.slots[slot], self.busy = self.slots[slot], nil, true
            self.pending[#self.pending + 1] = function() self.busy = false end
            return
        end
        self.moves[#self.moves + 1] = { "take", slot }
        self.pending[#self.pending + 1] = function()
            assert(self.active == nil)
            self.active, self.slots[slot] = self.slots[slot], nil
        end
    end
    function inv:TakeActiveItemFromEquipSlot(slot)
        if self.busy then return end
        self.pending[#self.pending + 1] = function()
            self.active, self.equips[slot] = self.equips[slot], nil
        end
    end
    function inv:SwapActiveItemWithSlot(slot)
        if self.busy then return end
        if self.predicted then
            self.active, self.slots[slot] = self.slots[slot], self.active
            self.busy = true
            self.pending[#self.pending + 1] = function() self.busy = false end
        else
            self.pending[#self.pending + 1] = function()
                self.active, self.slots[slot] = self.slots[slot], self.active
            end
        end
    end
    function inv:EquipActiveItem()
        if self.busy then return end
        self.pending[#self.pending + 1] = function()
            self.equips.hands, self.active = self.active, nil
        end
    end
    function inv:Flush()
        local pending = self.pending
        self.pending = {}
        for _, fn in ipairs(pending) do fn() end
    end
    function inv:EquipActionItem(tool)
        if self.busy then return end
        if self.predicted then
            self.busy = true
            self.pending[#self.pending + 1] = function() self.busy = false end
        end
        local previous = self.equips.hands
        self.equips.hands, self.active = tool, nil
        if previous and previous ~= tool then
            for slot = 1, self:GetNumSlots() do
                if self.slots[slot] == nil then self.slots[slot] = previous break end
            end
        end
    end
    function inv:UseItemFromInvTile(tool)
        if self.busy or self.active ~= nil then return end
        if self.predicted then
            self.busy = true
            self.pending[#self.pending + 1] = function()
                self.busy = false
                for slot, value in pairs(self.slots) do
                    if value == tool then self.slots[slot], self.equips.hands = nil, tool return end
                end
            end
            return
        end
        for slot, value in pairs(self.slots) do
            if value == tool then self.slots[slot], self.equips.hands = nil, tool return end
        end
    end
    p.replica.inventory = inv
    p.CanSoulhop = function() return inv.souls end
    ACTIONS = { BLINK = { code = 37, canforce = false, invalid_hold_action = true } }
    RPC = { RightClick = "RightClick", ControllerAltActionButtonPoint = "SoulPoint" }
    local calls = {}
    SendRPCToServer = function(...) calls[#calls + 1] = { ... } end
    local pc = { ismastersim = mode == "host", locomotor = mode == "nopredict" and nil or {}, enabled = true }
    if mode == "nopredict" then pc.locomotor = nil end
    function pc:IsEnabled() return self.enabled end
    function pc:IsBusy() return self.busy == true end
    function pc:CanLocomote() return true end
    function pc:GetPlatformRelativePosition(x, z) return nil, x, z end
    pc.inst = p
    p.GetBufferedAction = function() return nil end
    pc.DoActionAutoEquip = realcontroller.DoActionAutoEquip
    function pc:DoAction(act)
        self.last = act
        return realcontroller.DoAction(self, act)
    end
    if pc.locomotor then
        pc.locomotor.PreviewAction = function(_, act) if act:IsValid() then act.preview_cb() end end
        pc.locomotor.PushAction = function() pc.hostactions = (pc.hostactions or 0) + 1 end
    end
    p.components.playercontroller = pc
    local picker = { requests = {}, blocked = false }
    local function action(point, tool)
        return { action = ACTIONS.BLINK, invobject = tool, target = nil,
            GetActionPoint = function() return point end,
            IsValid = function(self) return not self.autoequipped or inv:GetActiveItem() == nil end }
    end
    function picker:GetRightClickActions(point, target)
        T.eq(target, nil, "ground clutter must not become the target")
        self.requests[#self.requests + 1] = "staff"
        return self.blocked and {} or { action(point, inv.active) }
    end
    function picker:GetPointSpecialActions(point, useitem, right)
        T.eq(useitem, nil)
        T.eq(right, true)
        self.requests[#self.requests + 1] = "soul"
        return self.blocked and {} or { action(point, nil) }
    end
    p.components.playeractionpicker = picker
    TheWorld = { Map = {
        IsPassableAtPoint = function() return true end,
        IsAboveGroundAtPoint = function() return true end,
        IsGroundTargetBlocked = function() return false end,
        GetPlatformAtPoint = function() return nil end,
    } }
    TheSim = { FindEntities = function() return {} end }
    IsTeleportingPermittedFromPointToPoint = function() return true end
    CanEntitySeePoint = function() return true end
    env = {}
    dofile("main/toolutil.lua")
    return { player = p, boss = b, inventory = inv, controller = pc, picker = picker,
        calls = calls, blink = Blink(p) }
end
local function tick(f, flush)
    if flush ~= false then f.inventory:Flush() end
    T.advance(0.1)
    return f.blink:Update()
end
local function cast(f)
    for _ = 1, 10 do
        tick(f)
        if f.controller.last then return end
    end
    error("no blink action submitted")
end

T.test("Wortox souls take priority even with an orange staff equipped", function()
    local f = fixture()
    f.player.tags.soulstealer, f.inventory.souls = true, true
    f.inventory.equips.hands = item("orangestaff")
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    T.eq(f.controller.last.invobject, nil)
    T.eq(f.picker.requests[1], "soul")
    T.eq(f.calls[1][1], "SoulPoint")
    T.eq(f.calls[1][7], true, "must request inherent special action")
end)
T.test("mouse item is stored before staff is taken and synchronization is awaited", function()
    local f = fixture()
    local staff, cursor = item("orangestaff"), item("twigs")
    f.inventory.slots[1], f.inventory.active = staff, cursor
    assert(f.blink:Start(f.boss, "portal"))
    tick(f, false)
    T.eq(f.inventory.moves[1][1], "put")
    tick(f, false)
    T.eq(#f.inventory.moves, 1)
    cast(f)
    T.eq(f.inventory.slots[2], cursor)
    T.eq(f.inventory.equips.hands, staff)
    T.eq(f.calls[1][1], "RightClick")
    T.eq(f.calls[1][5], nil, "RPC target must be nil")
    T.eq(f.controller.last.invobject, staff)
end)
T.test("full inventory never drops the active item or takes a staff", function()
    local f = fixture()
    f.inventory.active = item("twigs")
    f.inventory.slots = { item("orangestaff"), item("rocks"), item("flint") }
    assert(f.blink:Start(f.boss, "portal"))
    tick(f)
    T.eq(#f.inventory.moves, 0)
    T.eq(f.controller.last, nil)
    T.eq(f.inventory.active.prefab, "twigs")
end)
T.test("only orange-gem king cane with client reticule is accepted", function()
    local f = fixture()
    f.inventory.slots[1] = item("king_cane", "yellowgem")
    T.eq(f.blink:Start(f.boss, "portal"), false)
    f.inventory.slots[1] = item("king_cane", "orangegem")
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    T.eq(f.controller.last.invobject.prefab, "king_cane")
end)
T.test("depleted souls fall back to a ready staff, nomagiccast is excluded", function()
    local f = fixture()
    f.player.tags.soulstealer = true
    local staff = item("orangestaff")
    staff.tags.nomagiccast = true
    f.inventory.slots[1] = staff
    T.eq(f.blink:Start(f.boss, "portal"), false)
    staff.tags.nomagiccast = nil
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    T.eq(f.picker.requests[1], "staff")
end)
T.test("nonpredicting client sends exactly one point request", function()
    local f = fixture("nopredict")
    f.inventory.active = item("orangestaff")
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    tick(f)
    T.eq(#f.calls, 1)
end)
T.test("host uses local controller action without RPC", function()
    local f = fixture("host")
    f.inventory.active = item("orangestaff")
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    T.eq(#f.calls, 0)
    T.eq(f.controller.hostactions, 1)
end)
T.test("actual displacement confirms success then restores original staff slot", function()
    local f = fixture()
    local staff = item("orangestaff")
    f.inventory.slots[1] = staff
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    local point = f.controller.last:GetActionPoint()
    f.player.x, f.player.z = point.x, point.z
    T.eq(tick(f), "success")
    for _ = 1, 5 do f.inventory:Flush() T.advance(0.1) end
    T.eq(f.inventory.slots[1], staff)
    T.eq(f.inventory.active, nil)
end)
T.test("unconfirmed cast times out rather than claiming success", function()
    local f = fixture()
    f.inventory.active = item("orangestaff")
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    T.advance(DS_DODGE.BLINK_TIMEOUT + 0.1)
    T.eq(f.blink:Update(), "failed")
    T.eq(#f.calls, 1)
end)
T.test("skill ends or user changes cursor during preparation cancels cast", function()
    local f = fixture()
    f.inventory.slots[1] = item("orangestaff")
    assert(f.blink:Start(f.boss, "portal"))
    tick(f)
    f.inventory:Flush()
    f.inventory.active = item("rocks")
    T.eq(tick(f), "failed")
    T.eq(#f.calls, 0)
    f = fixture()
    f.inventory.active = item("orangestaff")
    assert(f.blink:Start(f.boss, "portal"))
    f.boss.animation = "idle"
    T.eq(tick(f), "failed")
    T.eq(#f.calls, 0)
end)
T.test("hazards respect minimum distances and ordinary loot is not a blocker", function()
    local f = fixture()
    local minion = T.entity("shadowthrall_mouth", -8, 0)
    local spike = T.entity("charliearena_spike", -8, 10)
    local loot = T.entity("twigs", -8, 15)
    local rock = T.entity("rock1", -8, 20)
    rock.radius = 1
    rock.Physics = { GetCollisionMask = function() return 1024 end }
    TheSim.FindEntities = function() return { minion, spike, loot, rock } end
    local safe = DS_BuildLandingValidator(f.player, f.boss, "staff")
    T.eq(safe(Vector3(-4.01, 0, 0)), false)
    T.eq(safe(Vector3(-4, 0, 0)), true)
    T.eq(safe(Vector3(-8, 0, 8.81)), false)
    T.eq(safe(Vector3(-8, 0, 8.8)), true)
    T.eq(safe(Vector3(-8, 0, 15)), true)
    T.eq(safe(Vector3(-8, 0, 20)), false)
end)
T.test("impassable ground, holes and forbidden teleports reject landing", function()
    local f = fixture()
    local point = Vector3(-6, 0, 0)
    TheWorld.Map.IsPassableAtPoint = function() return false end
    T.eq(DS_BuildLandingValidator(f.player, f.boss, "staff")(point), false)
    TheWorld.Map.IsPassableAtPoint = function() return true end
    TheWorld.Map.IsGroundTargetBlocked = function() return true end
    T.eq(DS_BuildLandingValidator(f.player, f.boss, "staff")(point), false)
    TheWorld.Map.IsGroundTargetBlocked = function() return false end
    IsTeleportingPermittedFromPointToPoint = function() return false end
    T.eq(DS_BuildLandingValidator(f.player, f.boss, "staff")(point), false)
end)
T.test("cancel while take request is in flight still restores the late arriving staff", function()
    local f = fixture()
    local staff = item("orangestaff")
    f.inventory.slots[1] = staff
    assert(f.blink:Start(f.boss, "portal"))
    tick(f, false)
    f.blink:Cancel()
    for _ = 1, 8 do f.inventory:Flush() T.advance(0.1) end
    T.eq(f.inventory.active, nil)
    T.eq(f.inventory.slots[1], staff)
    T.eq(#f.calls, 0)
end)
T.test("previous weapon is restored after staff returns to inventory", function()
    local f = fixture()
    local staff, weapon = item("orangestaff"), item("spear")
    f.inventory.slots[1], f.inventory.equips.hands = staff, weapon
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    local point = f.controller.last:GetActionPoint()
    f.player.x, f.player.z = point.x, point.z
    T.eq(tick(f), "success")
    for _ = 1, 10 do f.inventory:Flush() T.advance(0.1) end
    T.eq(f.inventory.equips.hands, weapon)
    local found = false
    for _, value in pairs(f.inventory.slots) do if value == staff then found = true end end
    T.eq(found, true)
end)
T.test("staff already equipped is returned to its equipment slot", function()
    local f = fixture()
    local staff = item("orangestaff")
    f.inventory.equips.hands = staff
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    local point = f.controller.last:GetActionPoint()
    f.player.x, f.player.z = point.x, point.z
    T.eq(tick(f), "success")
    for _ = 1, 5 do f.inventory:Flush() T.advance(0.1) end
    T.eq(f.inventory.equips.hands, staff)
end)
T.test("autoequip is refused if a full inventory would drop the prior weapon", function()
    local f = fixture()
    f.inventory.active = item("orangestaff")
    f.inventory.equips.hands = item("spear")
    f.inventory.slots = { item("rocks"), item("twigs"), item("flint") }
    assert(f.blink:Start(f.boss, "portal"))
    T.eq(tick(f), "failed")
    T.eq(#f.calls, 0)
    T.eq(f.inventory.equips.hands.prefab, "spear")
end)
T.test("backpack staff is found and retrieved through its own container", function()
    local f = fixture()
    local staff = item("orangestaff")
    local pack = { slots = { staff }, pending = f.inventory.pending }
    function pack:GetNumSlots() return 1 end
    function pack:GetItemInSlot(slot) return self.slots[slot] end
    function pack:CanTakeItemInSlot(_, slot) return self.slots[slot] == nil end
    function pack:TakeActiveItemFromAllOfSlot(slot)
        f.inventory.pending[#f.inventory.pending + 1] = function()
            f.inventory.active, self.slots[slot] = self.slots[slot], nil
        end
    end
    function pack:PutAllOfActiveItemInSlot(slot)
        f.inventory.pending[#f.inventory.pending + 1] = function()
            self.slots[slot], f.inventory.active = f.inventory.active, nil
        end
    end
    f.inventory.overflow = pack
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    T.eq(f.controller.last.invobject, staff)
    local point = f.controller.last:GetActionPoint()
    f.player.x, f.player.z = point.x, point.z
    T.eq(tick(f), "success")
    for _ = 1, 8 do f.inventory:Flush() T.advance(0.1) end
    T.eq(pack.slots[1], staff)
end)
T.test("all four minion prefabs enforce the four-unit exclusion", function()
    local f = fixture()
    for _, prefab in ipairs({"shadowthrall_wings", "shadowthrall_hands", "shadowthrall_horns", "shadowthrall_mouth"}) do
        TheSim.FindEntities = function() return { T.entity(prefab, -8, 0) } end
        local safe = DS_BuildLandingValidator(f.player, f.boss, "staff")
        T.eq(safe(Vector3(-4.01, 0, 0)), false)
        T.eq(safe(Vector3(-4, 0, 0)), true)
    end
end)
T.test("cancel never overwrites an unrelated mouse item", function()
    local f = fixture()
    local staff, replacement = item("orangestaff"), item("twigs")
    f.inventory.slots[1] = staff
    assert(f.blink:Start(f.boss, "portal"))
    tick(f)
    f.inventory:Flush()
    f.inventory.active = replacement
    f.blink:Cancel()
    T.advance(2.1)
    T.eq(f.inventory.active, replacement)
    T.eq(#f.calls, 0)
end)
T.test("busy or input-disabled local player cannot send a blink", function()
    local f = fixture()
    f.inventory.active = item("orangestaff")
    f.controller.enabled = false
    T.eq(f.blink:Start(f.boss, "portal"), false)
    f.controller.enabled, f.controller.busy = true, true
    assert(f.blink:Start(f.boss, "portal"))
    tick(f)
    T.eq(#f.calls, 0)
    f.controller.busy = false
    cast(f)
    T.eq(#f.calls, 1)
end)
T.test("no landing sends no point action and starts bounded staff cleanup", function()
    local f = fixture()
    f.inventory.slots[1] = item("orangestaff")
    TheWorld.Map.IsPassableAtPoint = function() return false end
    assert(f.blink:Start(f.boss, "portal"))
    for _ = 1, 5 do tick(f) end
    T.eq(#f.calls, 0)
    T.eq(f.controller.last, nil)
end)
T.test("preview callback rechecks resources before sending", function()
    local f = fixture()
    f.inventory.active = item("orangestaff")
    f.controller.locomotor.PreviewAction = function() end
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    f.inventory.equips.hands.tags.nomagiccast = true
    f.controller.last.preview_cb()
    T.eq(#f.calls, 0)
end)
T.test("player scheme throttles successful requests while a puddle keeps pursuing", function()
    local f = fixture()
    f.player.x, f.boss.animation = 2, "teleport_loop"
    f.inventory.active = item("orangestaff")
    local Component = require("components/ds_shrouden")
    local scheme = Component(f.player)
    scheme.blink = f.blink
    scheme:Enable({ [f.boss] = true })
    scheme:OnUpdate(0.1)
    T.eq(#f.calls, 1)
    local point = f.controller.last:GetActionPoint()
    f.player.x, f.player.z = point.x, point.z
    scheme:OnUpdate(0.1)
    f.boss.x, f.boss.z = f.player.x + 1, f.player.z
    scheme:OnUpdate(0.1)
    T.eq(#f.calls, 1)
    for _ = 1, 10 do f.inventory:Flush() T.advance(0.1) end
    scheme:OnUpdate(0.1)
    T.eq(#f.calls, 2)
    scheme:Disable()
    T.eq(scheme.enabled, false)
end)
T.test("predicted cursor changes do not bypass inventory synchronization", function()
    local f = fixture()
    local staff = item("orangestaff")
    f.inventory.predicted = true
    f.inventory.slots[1], f.inventory.active = staff, item("twigs")
    assert(f.blink:Start(f.boss, "portal"))
    tick(f, false)
    T.eq(f.inventory.active, nil)
    T.eq(f.inventory.busy, true)
    tick(f, false)
    T.eq(#f.inventory.moves, 1)
    f.inventory:Flush()
    tick(f, false)
    T.eq(f.inventory.active, staff)
    T.eq(f.inventory.busy, true)
    tick(f, false)
    T.eq(f.controller.last, nil)
    f.inventory:Flush()
    cast(f)
    T.eq(#f.calls, 1)
end)
T.test("recovery waits for stored staff and original equipment acknowledgement", function()
    local f = fixture()
    local staff, weapon = item("orangestaff"), item("spear")
    f.inventory.predicted = true
    f.inventory.slots[1], f.inventory.equips.hands = staff, weapon
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    f.inventory:Flush()
    local point = f.controller.last:GetActionPoint()
    f.player.x, f.player.z = point.x, point.z
    T.eq(tick(f), "success")
    f.inventory:Flush()
    T.advance(0.1)
    T.eq(f.inventory.busy, true)
    T.advance(0.1)
    T.eq(f.inventory.equips.hands, nil)
    assert(f.blink.recovery, "must wait while store is unacknowledged")
    f.inventory:Flush()
    T.advance(0.1)
    assert(f.blink.recovery, "must wait while re-equip is unacknowledged")
    f.inventory:Flush()
    T.advance(0.1)
    T.eq(f.inventory.equips.hands, weapon)
    T.eq(f.blink.recovery, nil)
end)
T.test("zero-slot inventory never invokes the original equipped-item drop path", function()
    local f = fixture()
    f.inventory.GetNumSlots = function() return 0 end
    f.inventory.equips.hands = item("orangestaff")
    T.eq(f.blink:Start(f.boss, "portal"), false)
    T.eq(#f.inventory.pending, 0)
    T.eq(#f.calls, 0)
end)
T.test("cursor-origin staff restores original weapon then returns to the cursor", function()
    local f = fixture()
    local staff, weapon = item("orangestaff"), item("spear")
    f.inventory.predicted = true
    f.inventory.active, f.inventory.equips.hands = staff, weapon
    assert(f.blink:Start(f.boss, "portal"))
    cast(f)
    f.inventory:Flush()
    local point = f.controller.last:GetActionPoint()
    f.player.x, f.player.z = point.x, point.z
    T.eq(tick(f), "success")
    for _ = 1, 12 do f.inventory:Flush() T.advance(0.1) end
    T.eq(f.inventory.active, staff)
    T.eq(f.inventory.equips.hands, weapon)
    T.eq(f.blink.recovery, nil)
end)
T.summary()
