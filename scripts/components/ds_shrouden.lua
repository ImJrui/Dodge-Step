local Blink = require("ds_blink")
local Plan = require("ds_shroudenplan")

local Shrouden = Class(function(self, inst)
    self.inst = inst
    self.enabled = false
    self.bosses = {}
    self.blink = Blink(inst)
    self.elapsed = 0
    self.nextattempt = 0
end)

function Shrouden:Enable(bosses)
    if self.inst ~= ThePlayer then return end
    self.bosses = bosses or self.bosses
    if self.enabled then return end
    self.enabled = true
    self.nextattempt = 0
    self.inst:StartUpdatingComponent(self)
    DS_Log("INFO", "Shrouden dodge enabled")
end

function Shrouden:Disable()
    self.bosses = {}
    self.blink:Cancel()
    if not self.enabled then return end
    self.enabled = false
    self.elapsed = 0
    self.lastfailure = nil
    self.inst:StopUpdatingComponent(self)
    DS_Log("INFO", "Shrouden dodge disabled")
end

function Shrouden:OnUpdate(dt)
    if not self.enabled then return end
    if self.inst ~= ThePlayer or not self.inst:IsValid() then self:Disable() return end
    self.elapsed = self.elapsed + dt
    if self.elapsed < DS_DODGE.CHECK_PERIOD then return end
    self.elapsed = 0
    if self.blink.pending then
        local result, reason = self.blink:Update()
        if result then
            self.nextattempt = GetTime() + (result == "success" and DS_DODGE.COOLDOWN or DS_DODGE.RETRY_DELAY)
            if result == "success" then
                self.lastfailure = nil
                DS_Log("INFO", "Shrouden dodge confirmed")
            elseif reason ~= self.lastfailure then
                self.lastfailure = reason
                DS_Log("DEBUG", "Shrouden dodge stopped", reason)
            end
        end
        return
    end
    if GetTime() < self.nextattempt then return end
    local selected, phase, rank
    local priorities = { laser = 3, puddle = 2, portal = 1 }
    for boss in pairs(self.bosses) do
        if DS_IsBossLoaded(boss) then
            local threat = Plan.GetThreat(boss, self.inst)
            if threat and (rank == nil or priorities[threat] > rank) then
                selected, phase, rank = boss, threat, priorities[threat]
            end
        end
    end
    if selected then
        local started, reason = self.blink:Start(selected, phase)
        if not started then
            self.nextattempt = GetTime() + DS_DODGE.RETRY_DELAY
            if reason ~= self.lastfailure then
                self.lastfailure = reason
                DS_Log("DEBUG", "Shrouden dodge unavailable", reason)
            end
        else
            self.blink:Update()
        end
    end
end

function Shrouden:OnRemoveEntity()
    self:Disable()
    self.blink:OnRemoveEntity()
end

return Shrouden
