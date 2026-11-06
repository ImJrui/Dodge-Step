# 闪身步 / Dodge Step

《饥荒联机版》仅客户端 Mod，Lua 5.1。启用后自动为当前玩家管理 Shrouden 闪避方案；其他玩家无需安装，服务器无需安装。

## Shrouden 自动闪避

Boss 生成或进入当前客户端加载范围时，自动启用玩家的 `ds_shrouden` 组件；休眠、移除或离开加载范围时自动停用。玩家重新激活后会重新连接已加载的 Boss，多个 Boss 分别登记。

| 技能 | 触发条件 | 落点优先级 |
| --- | --- | --- |
| 传送门召唤攻击 | punch_pre / punch_loop，玩家在前方 120°、距离 ≤12 | 后方 120°、4<半径≤8，先选离 Boss 更近的位置；无合适点时使用备用区域 |
| 眼睛镭射 | optic_blast_pre2 / loop / pre3，Boss 已传到目标附近，平面距离 ≤6 | 备用区域 |
| 恶液追击 | teleport_loop，平面距离 ≤4 | 备用区域 |

全部距离忽略高度。备用区域以 **Shrouden 为圆心、半径 20**，先选离 Boss 更远的位置；同时要求玩家到落点不超过 36，至少移动 3，并离开当前技能危险区域。

落点与四种 shadowthrall_wings、shadowthrall_hands、shadowthrall_horns、shadowthrall_mouth 至少相距 **4**，与 charliearena_spike 至少相距 **1.2**。还会排除不可通行地形、地洞、传送禁区和玩家碰撞障碍。普通地面杂物不当作实体目标，避免点到杂物后改变动作。

搜索采用有界极坐标采样：背后半径步长 0.25，备用区域半径步长 0.5，采样弧长间隔不超过 0.75。它不会穷举连续空间；没有采到安全位置时跳过本次传送。

## 闪现方式与物品安全

1. 玩家拥有 soulstealer 标签、携带灵魂并满足原版跳跃条件时，优先灵魂跳跃；已装备橙杖也不会抢占角色跳跃动作。
2. 其余情况查找鼠标、主物品栏、背包及装备栏中的 orangestaff，或 _gem 为 orangegem 且具有客户端 reticule 的 king_cane。冷却中的 nomagiccast 物品不使用。
3. 先将鼠标原物品存入明确的可用空槽，等待同步；再将法杖拿到鼠标，重检技能、落点与物品，执行原版 BLINK。库存及背包的预测忙碌期间暂停后续操作，不将预测变化当作同步完成。
4. 适配施法自动装备。传送后尽量归还法杖原槽或原装备位置、恢复先前手持物；归还最多重试两秒，用户更换鼠标物品时停止恢复。

背包满、没有资源、玩家忙碌或输入界面阻止操作、地形没有安全落点时不会强行传送。使用法杖若会使原装备因缺少空间而掉落，也会放弃。未确认实际位移的请求按超时处理，再按间隔重新判断。

组件不修改服务端状态，不提供无消耗瞬移，也不会绕过原版动作限制；能否完成仍取决于服务器验证、动画和网络同步。

## 目录与开发约定

- modmain.lua：仅按顺序导入 main/ 模块。
- main/constants.lua：DS_CONFIG、DS_LOG_LEVEL、DS_DODGE、DS_SHROUDEN、DS_BOSS_REGISTRY。
- main/toolutil.lua：DS_Log、DS_GetString、Boss 登记、法杖/空槽查询、落点环境验证。
- main/postinit.lua：显式导入 postinit/prefabs/player.lua 和 shrouden.lua。
- scripts/components/ds_bosswatcher.lua：只在 ThePlayer 上运行，0.25 秒核对登记表。
- scripts/components/ds_shrouden.lua：方案提供 Enable / Disable，危险技能检查间隔约两帧。
- scripts/ds_shroudenplan.lua：动画、扇区与落点排序；不提交动作。
- scripts/ds_blink.lua：异步传送事务、原版动作/RPC、位移确认与清理。
- strings/、scripts/languages/：英文原文、POT 和中文 PO。
- tests/：Lua 5.1 离线回归；docs/：设计、实施记录。
- scripts/screens/、scripts/widgets/、anim/、images/、tools/：预留目录。

main/ 和 postinit/ 统一使用用户约定的环境开头：

```lua
local PLENV = env
GLOBAL.setfenv(1, GLOBAL)
```

DS_ 公共定义写入 GLOBAL，模组专用 API 通过 PLENV 访问。未来 Boss 组件使用 ds_bossprefab，Hook 放在 postinit/ 对应目录并显式接入。完整规范见 AGENTS.md。

## 语言与日志

中文名称为“闪身步”，英文为 Dodge Step。元信息通过 modinfo.lua 的 en_zh 提供双语，运行时文案使用 STRINGS.DS_MOD / DS_GetString；新增文案同步维护 strings/common.lua、strings.pot 和 ds_chinese_s.po。

日志配置 DS_DEBUG_MODE 默认 INFO（3），支持 TRACE、DEBUG、INFO、WARN、ERROR、FATAL。DEBUG 可查看缺少资源、库存不足、无落点或请求超时等失败原因；正常日志仅记录启停及确认成功。

## 离线验证与游戏内验证

在工程根目录使用实际 Lua 5.1 运行：

```text
lua51 tests/ds_shroudenplan_spec.lua
lua51 tests/ds_blink_spec.lua
lua51 tests/ds_lifecycle_spec.lua
lua51 tests/ds_loading_spec.lua
```

将 lua51 替换为实际解释器；默认 lua/luac 可能是 Lua 5.4，不能代替 Lua 5.1 检查。测试使用游戏 Class、原版控制器动作函数和翻译器，默认游戏脚本路径沿用 AGENTS.md；其他安装位置可设置 DS_GAME_SCRIPTS 环境变量。

也可使用 Python 的 lupa.lua51.LuaRuntime 加载测试。测试模拟网络、库存同步和角色实体，不能代替实际客户端运行。

游戏内仍需验证：三种技能的识别和反应时机、普通远程客户端的移动预测开关、灵魂与两种法杖、满包及地面杂物、多 Boss／离开再进入范围、幽灵与重连、中英文 Mod 菜单显示。作者字段尚为空，发布前填写。

2026-11-06 离线验证：20 个 Lua 文件通过 Lua 5.1 语法检查，47 组回归通过，双语资源一致性及 git diff --check 通过。普通远程客户端实战和游戏内 UI 尚未验证。
