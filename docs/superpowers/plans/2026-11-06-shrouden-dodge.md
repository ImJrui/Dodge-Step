# Shrouden Dodge Implementation Plan

**Goal:** 在普通客户端实现 Shrouden 三类危险技能的自动闪避。
**Architecture:** 玩家专属方案组件 + 客户端 Boss 登记 + 纯几何规划 + 异步原版闪现事务。
**Tech Stack:** DST API 10，Lua 5.1，原版玩家动作/RPC，PO/POT。
**Spec:** docs/superpowers/specs/2026-11-06-shrouden-dodge-design.md

## Constraints

使用 DS_ / ds_，保留用户指定 GLOBAL 环境；所有原版 Hook 放在 postinit/，仅在 ThePlayer 上工作。无服务端依赖，不改游戏/参考 Mod。注释英文且每处最多两行；运行时字符串同步英文/POT/中文 PO。

## Tasks

- [x] 写 tests/ds_shroudenplan_spec.lua：前后扇区、忽略高度、技能动画、候选优先与半径/移动距离；先确认缺少实现而失败，再实现 scripts/ds_shroudenplan.lua。
- [x] 写 tests/ds_blink_spec.lua：灵魂与法杖选择、异步鼠标取放、满包不丢物、动作优先与 nil 目标、预测/无预测/房主、确认/超时/取消；再实现 scripts/ds_blink.lua 和公共工具/阈值。
- [x] 写 tests/ds_lifecycle_spec.lua：仅 ThePlayer、Boss 先到、多个 Boss、休眠/唤醒/移除、原回调返回值、停用清理；再实现两个组件和 prefab Hook，接入 main/postinit.lua。
- [x] 更新 modinfo、英文/POT/中文、README、AGENTS，记录方法与限制。
- [x] 执行 Lua 5.1 全文件语法检查、全部回归、加载链/翻译检查和 git diff --check；保留分支 codex/shrouden-dodge，不合并。

## 验证记录（2026-11-06）

- 使用 lupa.lua51.LuaRuntime，实际 _VERSION 为 Lua 5.1；20 个 Lua 文件通过语法检查。
- 47 组离线回归通过：技能几何 9、闪现事务 27、生命周期 8、完整加载与翻译 3。
- 传送回归直接读取并运行游戏 DoAction / DoActionAutoEquip；完整加载回归使用真实 translator.lua。网络、实体、动画和库存回执由离线夹具模拟。
- 回归覆盖原版自动装备、预测/无预测/房主、库存预测忙碌、装备回执、满包和零槽位保护、晚到的取杖请求、持续追击与重试间隔。
- 复查发现的库存预测与同步混淆问题已通过失败用例复现并修复；准备和恢复等待库存及相关容器解除忙碌，装备恢复等待实际回执。
- 复核发现的鼠标原本持杖时恢复武器的动作歧义已修复：通过明确换槽、EquipActiveItem 和取回手杖恢复原状态，新增失败回归后验证通过。
- 英文 Lua / POT / 中文 PO 的 2 个运行时字符串上下文、原文及格式占位符一致；modmain 保持只导入，AGENTS.lua 不存在。
- git diff --check 通过；分支 codex/shrouden-dodge，未提交或合并。
- 未启动游戏，三种技能实战触发、远程服务器接受请求、不同延迟与预测设置以及 UI 显示仍需游戏内验证。
