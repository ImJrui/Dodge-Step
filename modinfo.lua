local chinese_locales = {
    zh = true, zhr = true, zht = true,
    ch = true, chs = true, cht = true, sc = true, tc = true,
    zh_cn = true, zh_tw = true, ["zh-cn"] = true, ["zh-tw"] = true,
}

local function en_zh(text)
    return chinese_locales[locale] and text.zh or text.en
end

name = en_zh({ en = "Dodge Step", zh = "闪身步" })
description = en_zh({
    en = "Client-only automatic dodging for Shrouden.\n\nPortal summons: if you are in front of the boss within the configured range (default: 12 units), blink behind it.\nOptic blast: after the boss teleports into position, blink away within the configured distance (default: 7 units).\nIchor pursuit: when the boss turns into a puddle, blink away within the configured distance (default: 4.5 units).\n\nEach skill's trigger distance can be configured, or its dodging disabled.\n\nWortox uses Soul Hop first; otherwise, use a Lazy Explorer or an orange-gem King's Staff. Avoids dangerous landing spots and restores your previous weapon after dodging.",
    zh = "仅客户端，自动闪避暗影憎恶（Shrouden）的危险技能。\n\n传送门召唤：当你位于 Boss 前方的设定距离内（默认12）时，闪现到 Boss 身后。\n镭射激光：当 Boss 传送落位且进入设定距离（默认7.5）时，闪现远离 Boss。\n恶液追击：当 Boss 化身恶液并进入设定距离（默认4.5）时，闪现拉开距离。\n\n三种技能可分别设置闪避触发距离，也可选择不躲避。\n\n沃拓克优先使用灵魂跳跃，其他情况使用懒人手杖或镶嵌橙宝石的国王权杖。自动避开危险落点，闪避后恢复原武器。",
})
author = "好想好想吃兔兔"
version = "0.2.2"
api_version = 10
dst_compatible = true
client_only_mod = true
all_clients_require_mod = false
server_filter_tags = {}
icon_atlas = "images/ds_modicon.xml"
icon = "ds_modicon.tex"

configuration_options = {
    {
        name = "DS_PORTAL_DISTANCE",
        label = en_zh({ en = "Portal dodge distance", zh = "传送门闪避距离" }),
        hover = en_zh({
            en = "Trigger distance in front of Shrouden. Choose Do not dodge to disable portal dodging.",
            zh = "在暗影憎恶前方触发闪避的距离。选择不躲避可关闭传送门闪避。",
        }),
        options = {
            { description = en_zh({ en = "Do not dodge", zh = "不躲避" }), data = false },
            { description = "10", data = 10 },
            { description = "11", data = 11 },
            { description = "12", data = 12 },
            { description = "13", data = 13 },
            { description = "14", data = 14 },
            { description = "15", data = 15 },
            { description = "16", data = 16 },
            { description = "17", data = 17 },
            { description = "18", data = 18 },
        },
        default = 12,
    },
    {
        name = "DS_PUDDLE_DISTANCE",
        label = en_zh({ en = "Ichor dodge distance", zh = "恶液追击闪避距离" }),
        hover = en_zh({
            en = "Planar distance from Shrouden that triggers ichor dodging. Choose Do not dodge to disable it.",
            zh = "与暗影憎恶的平面距离小于等于此值时闪避恶液追击。选择不躲避可关闭。",
        }),
        options = {
            { description = en_zh({ en = "Do not dodge", zh = "不躲避" }), data = false },
            { description = "4", data = 4 },
            { description = "4.5", data = 4.5 },
            { description = "5", data = 5 },
            { description = "5.5", data = 5.5 },
            { description = "6", data = 6 },
        },
        default = 4.5,
    },
    {
        name = "DS_LASER_DISTANCE",
        label = en_zh({ en = "Laser dodge distance", zh = "镭射激光闪避距离" }),
        hover = en_zh({
            en = "Planar distance from Shrouden that triggers laser dodging after it lands. Choose Do not dodge to disable it.",
            zh = "暗影憎恶落位后，与其平面距离小于等于此值时闪避镭射激光。选择不躲避可关闭。",
        }),
        options = {
            { description = en_zh({ en = "Do not dodge", zh = "不躲避" }), data = false },
            { description = "6", data = 6 },
            { description = "6.5", data = 6.5 },
            { description = "7", data = 7 },
            { description = "7.5", data = 7.5 },
            { description = "8", data = 8 },
            { description = "8.5", data = 8.5 },
            { description = "9", data = 9 },
        },
        default = 7.5,
    },
    {
        name = "DS_DEBUG_MODE",
        label = en_zh({ en = "Log level", zh = "日志级别" }),
        hover = en_zh({
            en = "Only messages at this level or higher are printed.",
            zh = "仅输出此级别及以上的日志。",
        }),
        options = {
            { description = en_zh({ en = "Trace", zh = "跟踪" }), data = 1 },
            { description = en_zh({ en = "Debug", zh = "调试" }), data = 2 },
            { description = en_zh({ en = "Info", zh = "信息" }), data = 3 },
            { description = en_zh({ en = "Warn", zh = "警告" }), data = 4 },
            { description = en_zh({ en = "Error", zh = "错误" }), data = 5 },
            { description = en_zh({ en = "Fatal", zh = "致命" }), data = 6 },
        },
        default = 3,
    },
}
