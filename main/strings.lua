local PLENV = env
GLOBAL.setfenv(1, GLOBAL)

local loader = kleiloadlua(PLENV.MODROOT .. "strings/common.lua")
if type(loader) ~= "function" then
    error("Could not load strings/common.lua: " .. tostring(loader))
end
setfenv(loader, PLENV)
local english = loader()
assert(type(english) == "table", "strings/common.lua must return a table")
STRINGS.DS_MOD = english

local chinese_locales = {
    zh = true, zhr = true, zht = true,
    ch = true, chs = true, cht = true, sc = true, tc = true,
    zh_cn = true, zh_tw = true, ["zh-cn"] = true, ["zh-tw"] = true,
}
local locale = LOC.GetLocaleCode()
if not chinese_locales[locale] then
    return
end

require("translator")
local translator = LanguageTranslator
local language = DS_MOD_ID .. "_chinese_s"
local previous_language = translator.defaultlang
local previous_strings = translator.languages[language]
PLENV.LoadPOFile(PLENV.MODROOT .. "scripts/languages/ds_chinese_s.po", language)
translator.defaultlang = previous_language

local function translate(strings, context)
    for key, value in pairs(strings) do
        local path = context .. "." .. key
        if type(value) == "table" then
            translate(value, path)
        else
            local translated = translator:GetTranslatedString(path, language)
            if translated ~= nil and translated ~= "" then
                strings[key] = translated
            end
        end
    end
end

translate(STRINGS.DS_MOD, "STRINGS.DS_MOD")
translator.languages[language] = previous_strings
