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
    en = "Client-only mod scaffold. No gameplay features are enabled.",
    zh = "仅客户端模组骨架，尚未启用任何玩法功能。",
})
author = ""
version = "0.1.0"
api_version = 10
dst_compatible = true
client_only_mod = true
all_clients_require_mod = false
server_filter_tags = {}

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
