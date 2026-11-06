# Client Scaffold Implementation Plan

> **For agentic workers:** Execute this approved scaffold plan inline, task by task, and use superpowers:verification-before-completion before reporting completion. No delegation is required.

**Goal:** 初始化“闪身步 / Dodge Step”的仅客户端模组骨架和协作规范，不包含具体玩法功能。

**Architecture:** modmain.lua 仅按顺序导入 main/ 模块；公共配置和工具保存在 GLOBAL，原版 Hook 统一放入 postinit/；运行模块先保存 PLENV 再切换环境。运行时文案使用 STRINGS.DS_MOD，并由英文 Lua、POT 和中文 PO 同步维护。

**Tech Stack:** Don't Starve Together API 10，Lua 5.1，gettext PO/POT，Git。

**Spec:** docs/superpowers/specs/2026-11-06-client-scaffold-design.md

## Global Constraints

- 项目名称：英文 Dodge Step，中文“闪身步”。
- 仅客户端 Mod，Lua 5.1；client_only_mod = true，all_clients_require_mod = false。
- 只初始化工程和公共基础设施，不实现闪避、按键操作、界面或其他玩法功能。
- 需要标识模组归属时，文件、模块、资源使用 ds_，公共函数、变量、配置键使用 DS_。
- 引擎约定的入口、元信息字段及目录名称保持原名。
- 仅生成 AGENTS.md，不生成 AGENTS.lua。

## Task 1: 初始化目录、加载链和公共基础设施

**Files:** modinfo.lua、modmain.lua、main/{constants,toolutil,strings,popups,postinit,keybinds}.lua、strings/common.lua、scripts/languages/{strings.pot,ds_chinese_s.po}；postinit/{components,prefabs,screens,widgets}/、scripts/{components,screens,widgets}/、anim/、images/、tests/、tools/。

**Interfaces:** PLENV.GetModConfigData("DS_DEBUG_MODE") 提供日志阈值；DS_CONFIG.DEBUG_MODE、DS_LOG_LEVEL、DS_MOD_ID 提供公共配置。DS_Log(level, ...) 过滤并输出日志；DS_GetString(key, ...) 获取相对 STRINGS.DS_MOD 的点分隔键，并按需使用 string.format。

- [x] 检查目录为空，获用户同意后执行 git init -b main，再创建 codex/init-client-scaffold 分支。
- [x] 创建入口与基础模块；日志默认 INFO，非法配置回退 INFO，不注册任何 Hook、任务、按键或界面。
- [x] 创建英文 NAME、DESCRIPTION 及同上下文 POT/中文 PO，接入只处理自身命名空间的语言加载。
- [x] 为所有空分类目录加入 .gitkeep；不引用不存在的资源。
- [x] 使用临时 Lua 5.1 环境执行语法及加载验证，读取实际游戏翻译器验证 PO 接入；不修改游戏或参考模组。

## Task 2: 规范、说明及完成核验

**Files:** AGENTS.md、README.md、.gitignore、本设计和实施记录。

**Interfaces:** AGENTS.md 将参考项目通用要求适配为 DS_ / ds_ 命名和本项目路径；README.md 解释加载链、语言资源和后续扩展位置。

- [x] 写入完整协作规范，保留禁止修改游戏源码、Lua 5.1、英文短注释、客户端可用性、双语同步及分支合并约束。
- [x] 说明当前为无玩法骨架、仅日志配置、无图标资源；记录新增 Hook 的显式接入方式。
- [x] 核对全部要求、目录、前缀、翻译上下文和 Git 状态，更新本计划完成标记。
- [x] 汇报静态及离线验证证据，明确游戏内验证尚未执行；保留主题分支，未经授权不合并。

## 初始化验证记录（环境约定调整前，2026-11-06）

- 临时环境使用 lupa.lua51.LuaRuntime，确认 _VERSION 为 Lua 5.1。
- 9 个 Lua 文件通过 Lua 5.1 语法检查。
- 目录、仅导入入口、空 Hook 分类及仅存在 AGENTS.md 的结构检查通过。
- 2 个运行时字符串键在英文 Lua、POT、中文 PO 中的上下文及英文原文一致，占位符检查通过。
- 27 组离线加载场景通过，覆盖 12 个中文语言别名、英文和未知/未指定语言回退、6 个日志级别、非法配置回退及未设置翻译器默认语言的场景。
- 离线环境模拟游戏模组沙箱；中文 PO 解析直接使用游戏 translator.lua，验证原有字符串、翻译器状态及游戏全局命名空间不被覆盖。
- git diff --check 通过；游戏客户端加载及界面显示尚未验证。
- 起始分支 main 尚无提交，当前分支 codex/init-client-scaffold；本次未提交或合并。

## Task 3: 按用户指定方式使用全局环境

**Files:** main/{constants,toolutil,strings,popups,postinit,keybinds}.lua、AGENTS.md、README.md、本设计和实施记录。

**Interfaces:** 运行模块先保存 local PLENV = env，再执行 GLOBAL.setfenv(1, GLOBAL)；DS_ 公共定义写入 GLOBAL，模组专用接口通过 PLENV 访问。

- [x] 从 codex/init-client-scaffold 创建 codex/global-environment，保留已有工程文件及用户改动。
- [x] 调整离线验证的环境契约，确认旧实现未导出 DS_CONFIG 到 GLOBAL。
- [x] 为六个 main/ 模块加入统一环境开头，改用 PLENV 访问模组 API；modmain.lua 继续仅导入。
- [x] 同步 AGENTS.md、README.md 和设计说明中的环境约定。
- [x] 使用实际 Lua 5.1 重新验证语法、全局导出、模块环境、翻译及加载链；核对文件范围和 Git 状态。

### 全局环境调整验证（2026-11-06）

- 9 个 Lua 文件通过实际 Lua 5.1 语法检查，27 组离线加载场景通过。
- 六个 main/ 模块均通过 getfenv 确认运行在 GLOBAL；DS_CONFIG、DS_LOG_LEVEL、DS_MOD_ID、DS_Log、DS_GetString 正确导出至 GLOBAL。
- 模组专用 API 通过 PLENV 访问；未覆盖 CONFIG、LOG_LEVEL 等无关全局名称。
- 英文、中文、语言回退、日志过滤、格式化、PO/POT 同步及翻译器状态恢复检查通过；modmain.lua 保持仅导入。
- git diff --check 通过；游戏客户端加载及界面显示尚未验证。
- 本次起始分支 codex/init-client-scaffold，当前分支 codex/global-environment；已有工程内容完整保留，未提交或合并。
