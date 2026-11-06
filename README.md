# 闪身步 / Dodge Step

《饥荒联机版》仅客户端 Mod 的初始化工程，运行环境为 Lua 5.1。

当前只提供工程结构、公共配置与日志工具、双语元信息和运行时字符串；尚未实现闪避、按键操作、界面或其他玩法功能。启用后不会注册 Hook、绑定快捷键或启动任务。

## 目录与加载顺序

```text
Dodge-Step/
├── AGENTS.md
├── modinfo.lua
├── modmain.lua
├── main/
│   ├── constants.lua
│   ├── toolutil.lua
│   ├── strings.lua
│   ├── popups.lua
│   ├── postinit.lua
│   └── keybinds.lua
├── postinit/
│   ├── components/
│   ├── prefabs/
│   ├── screens/
│   └── widgets/
├── scripts/
│   ├── components/
│   ├── screens/
│   ├── widgets/
│   └── languages/
│       ├── strings.pot
│       └── ds_chinese_s.po
├── strings/
│   └── common.lua
├── anim/
├── images/
├── tests/
├── tools/
└── docs/
```

modmain.lua 按 constants → toolutil → strings → popups → postinit → keybinds 的顺序导入，入口本身只负责导入。

- main/：初始化与公共基础设施。
- postinit/：原版或兼容 Mod 的 Hook，按目标对象分类。新文件必须显式接入 main/postinit.lua。
- scripts/：自定义组件、Screen、Widget 及其他 require 模块。
- anim/、images/、tests/、tools/：预留目录，通过 .gitkeep 保留。
- docs/：已确认的设计与实施记录。

当前不包含图标、动画、界面或资源清单，不引用不存在的资源。modinfo.lua 的作者字段暂为空，发布前填写。

## 命名与公共工具

需要标识本 Mod 归属时，文件、模块和资源使用 ds_，公共函数、变量及配置键使用 DS_。引擎要求的入口和字段保持原名。

main/ 模块和后续 postinit/ Hook 统一先保存模组环境，再切换到游戏全局环境：

```lua
local PLENV = env
GLOBAL.setfenv(1, GLOBAL)
```

DS_ 公共变量和函数定义在 GLOBAL 中，require 模块可直接使用。模组专用接口通过 PLENV 访问，例如 PLENV.GetModConfigData、PLENV.modimport、PLENV.MODROOT 和 PLENV.LoadPOFile。modmain.lua 保持仅导入，modinfo.lua 和纯数据字符串文件使用各自的加载环境。

```lua
DS_Log("INFO", "State changed")
local display_name = DS_GetString("NAME")
```

DS_CONFIG.DEBUG_MODE 读取配置键 DS_DEBUG_MODE，默认为 INFO（3）。TRACE、DEBUG、INFO、WARN、ERROR、FATAL 对应 1 至 6，仅输出达到阈值的日志。

## 中英文

Mod 名称、说明和日志配置通过 modinfo.lua 的 en_zh 机制提供双语文案。运行时文案存放在 STRINGS.DS_MOD，由 DS_GetString("NAME") 等调用读取；支持点分隔键和 string.format 参数。

新增或修改运行时文案时，同步更新：

1. strings/common.lua 中的英文键和值；
2. scripts/languages/strings.pot 中的完整 STRINGS.DS_MOD.* 上下文及英文原文；
3. scripts/languages/ds_chinese_s.po 中对应的上下文、英文原文和中文译文。

中文游戏语言及其常见别名使用简体中文译文，其他语言回退英文。语言加载只修改本 Mod 的字符串表，并恢复翻译器默认语言和临时表。

## 后续扩展

添加原版 Hook 时，将文件放入对应 postinit/ 分类，再在 main/postinit.lua 显式导入。自定义组件、界面及控件主体放在 scripts/ 对应目录；公共工具及常量分别由 main/toolutil.lua、main/constants.lua 管理。

完整开发与 Git 规范见 AGENTS.md。所有改动保持 Lua 5.1 兼容，禁止修改游戏源码。

## 验证说明

Lua 语法检查必须使用 Lua 5.1 解释器或编译器；本机默认 lua/luac 的版本需要先核对。离线加载检查应覆盖英文、中文、未知语言回退、PO/POT 同步、日志过滤、DS_ 公共全局导出和无关全局保护。

离线检查不等同于游戏内验证。还需在游戏 Mod 菜单及独立客户端检查中英文显示和启用后的正常加载。

2026-11-06 初始化验证：9 个 Lua 文件通过实际 Lua 5.1 语法检查；27 组离线加载场景及 2 个运行时字符串键的 Lua/POT/PO 一致性检查通过。离线语言接入检查使用游戏 translator.lua，覆盖语言回退、日志过滤和命名空间隔离。游戏客户端加载及界面显示尚未验证。详细记录见 docs/superpowers/plans/2026-11-06-client-scaffold.md。
