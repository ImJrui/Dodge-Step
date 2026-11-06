local PLENV = env
GLOBAL.setfenv(1, GLOBAL)

local function activate(inst)
    if inst ~= ThePlayer or not inst:IsValid() then return end
    if inst.components.ds_bosswatcher == nil then inst:AddComponent("ds_bosswatcher") end
    inst.components.ds_bosswatcher:Start()
end

local function deactivate(inst)
    if inst.components.ds_bosswatcher then inst.components.ds_bosswatcher:Stop() end
end

PLENV.AddPlayerPostInit(function(inst)
    if TheNet:IsDedicated() then return end
    inst:ListenForEvent("playeractivated", activate)
    inst:ListenForEvent("playerdeactivated", deactivate)
    inst:DoTaskInTime(0, activate)
end)
