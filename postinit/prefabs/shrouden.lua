local PLENV = env
GLOBAL.setfenv(1, GLOBAL)

PLENV.AddPrefabPostInit("shrouden", function(inst)
    if TheNet:IsDedicated() then return end
    local onwake, onsleep = inst.OnEntityWake, inst.OnEntitySleep
    inst.OnEntityWake = function(entity, ...)
        DS_SetBossLoaded(entity, true)
        if onwake then return onwake(entity, ...) end
    end
    inst.OnEntitySleep = function(entity, ...)
        DS_SetBossLoaded(entity, false)
        if onsleep then return onsleep(entity, ...) end
    end
    inst:ListenForEvent("onremove", function() DS_SetBossLoaded(inst, false) end)
    DS_SetBossLoaded(inst, DS_IsBossLoaded(inst))
end)
