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
