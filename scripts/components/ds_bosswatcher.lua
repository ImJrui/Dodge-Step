local BossWatcher = Class(function(self, inst)
    self.inst = inst
end)

function BossWatcher:Refresh()
    if self.inst ~= ThePlayer or self.task == nil then return end
    for prefab, registry in pairs(DS_BOSS_REGISTRY) do
        local name = "ds_" .. prefab
        if self.inst.components[name] == nil then self.inst:AddComponent(name) end
        local loaded = {}
        for boss in pairs(registry) do
            if DS_IsBossLoaded(boss) then loaded[boss] = true end
        end
        local component = self.inst.components[name]
        if next(loaded) then component:Enable(loaded) else component:Disable() end
    end
end

function BossWatcher:Start()
    if self.task ~= nil or self.inst ~= ThePlayer then return end
    self.task = self.inst:DoPeriodicTask(DS_DODGE.WATCH_PERIOD, function() self:Refresh() end)
    self:Refresh()
end

function BossWatcher:Stop()
    if self.task then self.task:Cancel() self.task = nil end
    for prefab in pairs(DS_BOSS_REGISTRY) do
        local component = self.inst.components["ds_" .. prefab]
        if component then component:Disable() end
    end
end

function BossWatcher:OnRemoveEntity()
    self:Stop()
end

return BossWatcher
