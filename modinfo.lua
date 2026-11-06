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
    en = "Client-only automatic dodging for Shrouden.\n\nPortal summons: if you are in front of the boss within about 14 units, blink behind it.\nOptic blast: when the boss teleports near you to fire its laser, blink away.\nIchor pursuit: when the boss turns into a puddle and closes in, blink away to keep your distance.\n\nWortox uses Soul Hop first; otherwise, use a Lazy Explorer or an orange-gem King's Staff. Avoids dangerous landing spots and restores your previous weapon after dodging.",
    zh = "仅客户端，自动闪避暗影憎恶（Shrouden）的危险技能。\n\n传送门召唤：当你位于 Boss 前方约14距离内时，闪现到 Boss 身后。\n镭射激光：当 Boss 传送到你附近释放激光时，闪现远离 Boss。\n恶液追击：当 Boss 化身恶液并追到你附近时，闪现拉开距离。\n\n沃拓克优先使用灵魂跳跃，其他情况使用懒人手杖或镶嵌橙宝石的国王权杖。自动避开危险落点，闪避后恢复原武器。",
})
author = "TUTU"
version = "0.2.0"
api_version = 10
dst_compatible = true
client_only_mod = true
all_clients_require_mod = false
server_filter_tags = {}
icon_atlas = "images/ds_modicon.xml"
icon = "ds_modicon.tex"

configuration_options = {
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
