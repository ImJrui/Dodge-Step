local T = dofile("tests/ds_testutil.lua")
local scripts = os.getenv("DS_GAME_SCRIPTS")
    or "F:/SteamLibrary/steamapps/common/Don't Starve Together/data/databundles/scripts"
package.path = scripts .. "/?.lua;" .. package.path
package.loaded.util = true
resolvefilepath = function(file) return file end
require("translator")
kleiloadlua = loadfile
TheNet = { IsDedicated = function() return false end }
ThePlayer = nil

local function load(locale)
    local previous = { SENTINEL = "preserved" }
    STRINGS = { OTHER_MOD = { NAME = "untouched" } }
    LanguageTranslator.defaultlang = "original"
    LanguageTranslator.languages = { original = {}, ds_dodge_step_chinese_s = previous }
    LOC = { GetLocaleCode = function() return locale end }
    local imports, hooks = {}, {}
    local scope = { GLOBAL = _G, MODROOT = "./", require = require,
        GetModConfigData = function() return 3 end,
        LoadPOFile = function(file, lang) LanguageTranslator:LoadPOFile(file, lang) end,
        AddPlayerPostInit = function(fn) hooks.player = fn end,
        AddPrefabPostInit = function(prefab, fn) hooks[prefab] = fn end,
    }
    scope.env = scope
    scope.modimport = function(relative)
        imports[#imports + 1] = relative
        local chunk = assert(loadfile(relative))
        setfenv(chunk, scope)
        chunk()
    end
    local known = {}
    for key in pairs(_G) do known[key] = true end
    local chunk = assert(loadfile("modmain.lua"))
    setfenv(chunk, scope)
    chunk()
    T.eq(#imports, 8)
    T.eq(imports[1], "main/constants.lua")
    T.eq(imports[6], "postinit/prefabs/player.lua")
    T.eq(imports[7], "postinit/prefabs/shrouden.lua")
    assert(hooks.player and hooks.shrouden)
    assert(type(DS_Log) == "function" and getfenv(DS_Log) == _G)
    assert(type(DS_BuildLandingValidator) == "function")
    T.eq(LanguageTranslator.defaultlang, "original")
    T.eq(LanguageTranslator.languages.ds_dodge_step_chinese_s, previous)
    T.eq(STRINGS.OTHER_MOD.NAME, "untouched")
    for key in pairs(_G) do
        assert(known[key] or tostring(key):sub(1, 3) == "DS_", "unprefixed global leak: " .. key)
    end
    local metadata = { locale = locale }
    setfenv(assert(loadfile("modinfo.lua")), metadata)()
    T.eq(metadata.name, STRINGS.DS_MOD.NAME)
    T.eq(metadata.description, STRINGS.DS_MOD.DESCRIPTION)
    T.eq(metadata.client_only_mod, true)
    T.eq(metadata.all_clients_require_mod, false)
    T.eq(metadata.api_version, 10)
    T.eq(metadata.version, "0.2.0")
    return metadata
end
T.test("complete English load chain registers player and boss hooks", function()
    T.eq(load("en").name, "Dodge Step")
end)
T.test("complete Chinese load restores original translation context", function()
    T.eq(load("zh").name, "闪身步")
end)
T.test("unknown language falls back to English metadata and runtime strings", function()
    T.eq(load("fr").name, "Dodge Step")
end)
T.summary()
