# 闪身步客户端骨架设计

用户已确认本方案；仅生成 AGENTS.md，不生成 AGENTS.lua。

## 目标与约束

- 项目名称：英文 Dodge Step，中文“闪身步”。
- 仅客户端 Mod，Lua 5.1；client_only_mod = true，all_clients_require_mod = false。
- 只初始化工程和公共基础设施，不实现闪避、按键操作、界面或其他玩法功能。
- 需要标识模组归属时，文件、模块、资源使用 ds_，公共函数、变量、配置键使用 DS_。
- 引擎约定的入口、元信息字段及目录名称保持原名。
- 保留参考项目的客户端兼容、精简英文注释、双语同步、验证及 Git 协作规范。

## 结构与加载

modmain.lua 只依次导入 main/constants.lua、main/toolutil.lua、main/strings.lua、main/popups.lua、main/postinit.lua 和 main/keybinds.lua。

main/constants.lua 管理 DS_CONFIG、DS_LOG_LEVEL 和 DS_MOD_ID。main/toolutil.lua 提供 DS_Log 与 DS_GetString；这些公共定义写入 GLOBAL 并保留 DS_ 前缀。

按用户追加要求，main/ 和后续 postinit/ 模块先执行 local PLENV = env，再执行 GLOBAL.setfenv(1, GLOBAL)。切换后的模组专用接口通过 PLENV 访问。modmain.lua 保持仅导入，modinfo.lua 使用元信息环境，纯数据字符串文件无需切换环境。

对原版和兼容 Mod 的 Hook 放在 postinit/ 的对应分类，由 main/postinit.lua 显式导入；当前不注册任何 Hook。scripts/ 保存自定义模块，不能与原版 Hook 混用。

anim/、images/、tests/、tools/ 及空分类目录通过 .gitkeep 保留。不复制参考项目的玩法文件、图标、资源或 mod.manifest。

## 双语资源

modinfo.lua 使用独立 en_zh 机制提供名称、说明与日志配置的中英文文案。运行时英文原文位于 strings/common.lua，并写入 STRINGS.DS_MOD；相应 POT 和中文 PO 位于 scripts/languages/。

main/strings.lua 按游戏语言选择中文或英文；中文别名沿用参考模组并补充常见区域代码。只翻译 STRINGS.DS_MOD，加载 PO 后还原翻译器默认语言及临时语言表，避免影响其他模组。

## 验收

使用实际 Lua 5.1 检查全部 Lua 文件语法和模组入口加载；核对元信息及运行时中英文、PO/POT 上下文一致性、日志过滤、DS_ 公共全局导出、无关全局保护及占位模块无 Hook 行为。

离线检查不代表游戏客户端运行验证。未启动游戏时明确保留该验证项。Git 初始化起始分支为 main（尚无提交），初始化分支为 codex/init-client-scaffold，环境约定调整使用 codex/global-environment；未经明确授权不合并。
