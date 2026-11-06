local PLENV = env
GLOBAL.setfenv(1, GLOBAL)

DS_MOD_ID = "ds_dodge_step"

DS_LOG_LEVEL = {
    TRACE = 1,
    DEBUG = 2,
    INFO = 3,
    WARN = 4,
    ERROR = 5,
    FATAL = 6,
}

local debug_mode = PLENV.GetModConfigData("DS_DEBUG_MODE")
if type(debug_mode) ~= "number"
    or debug_mode < DS_LOG_LEVEL.TRACE
    or debug_mode > DS_LOG_LEVEL.FATAL
    or debug_mode % 1 ~= 0 then
    debug_mode = DS_LOG_LEVEL.INFO
end

DS_CONFIG = {
    DEBUG_MODE = debug_mode,
}
