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

local function get_distance(name, minimum, maximum, step, default)
    local value = PLENV.GetModConfigData(name)
    if value == false then return false end
    if type(value) ~= "number" or value < minimum or value > maximum
        or (value - minimum) % step ~= 0 then
        return default
    end
    return value
end

DS_CONFIG = {
    DEBUG_MODE = debug_mode,
    PORTAL_DISTANCE = get_distance("DS_PORTAL_DISTANCE", 10, 18, 1, 12),
    PUDDLE_DISTANCE = get_distance("DS_PUDDLE_DISTANCE", 4, 6, 0.5, 4.5),
    LASER_DISTANCE = get_distance("DS_LASER_DISTANCE", 6, 9, 0.5, 7.5),
}

DS_BOSS_REGISTRY = { shrouden = {} }

DS_DODGE = {
    WATCH_PERIOD = 0.25,
    CHECK_PERIOD = 2 * FRAMES,
    PREPARE_TIMEOUT = 2,
    BLINK_TIMEOUT = 2.5,
    RECOVERY_TIMEOUT = 5,
    RETRY_DELAY = 0.35,
    COOLDOWN = 0.75,
    MAX_BLINK_DISTANCE = 36,
    MIN_BLINK_DISTANCE = 3,
    HAZARD_CLEARANCE = {
        shadowthrall_wings = 4,
        shadowthrall_hands = 4,
        shadowthrall_horns = 4,
        shadowthrall_mouth = 4,
        charliearena_spike = 2,
    },
}

DS_SHROUDEN = {
    FRONT_RADIUS = DS_CONFIG.PORTAL_DISTANCE,
    HALF_ANGLE = 60,
    FRONT_RECT_LENGTH = 4 * math.tan(math.pi / 6),
    FRONT_RECT_HALF_WIDTH = 4,
    REAR_INNER = 4,
    REAR_OUTER = 8,
    REAR_STEP = 0.25,
    ESCAPE_RADIUS = 20,
    ESCAPE_STEP = 0.5,
    ARC_STEP = 0.75,
    LASER_RADIUS = DS_CONFIG.LASER_DISTANCE,
    PUDDLE_RADIUS = DS_CONFIG.PUDDLE_DISTANCE,
}

DS_STAFF = {
    MIN_USES = 1,
    ORANGE_MIN_PERCENT = 5,
    CHARGE_FULL = 180,
    USAGE_ABSENT = 255,
}
