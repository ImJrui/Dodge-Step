# 闪身步 / Dodge Step

《饥荒联机版》仅客户端 Mod，Lua 5.1。启用后自动为当前玩家管理 Shrouden 闪避方案；其他玩家无需安装，服务器无需安装。

## Shrouden 自动闪避

Boss 生成或进入当前客户端加载范围时，自动启用玩家的 `ds_shrouden` 组件；休眠、移除或离开加载范围时自动停用。玩家重新激活后会重新连接已加载的 Boss，多个 Boss 分别登记。

| 技能 | 触发条件 | 落点优先级 |
| --- | --- | --- |
| 传送门召唤攻击 | punch_pre / punch_loop，玩家进入前方可配置半径（默认 12）、120° 扇形与前向深度 4×tan30°、左右各宽 4 矩形的并集 | 后方 120°、4<半径≤8，先选离 Boss 更近的位置；无合适点时使用备用区域 |
| 眼睛镭射 | optic_blast_pre2 / loop / pre3，Boss 已传到目标附近，平面距离 ≤配置值（默认 7） | 备用区域 |
| 恶液追击 | teleport_loop，平面距离 ≤配置值（默认 4.5） | 备用区域 |

在 Mod 配置中可分别设置三种技能的**闪避触发距离**，选择“不躲避”只关闭对应技能。距离不是每次闪现的移动长度，落点仍按下述规则选择。

| 配置 | 可选值 | 默认值 |
| --- | --- | --- |
| 传送门闪避距离 | 不躲避；10～18，步长 1 | 12 |
| 恶液追击闪避距离 | 不躲避；4～6，步长 0.5 | 4.5 |
| 镭射激光闪避距离 | 不躲避；6～9，步长 0.5 | 7.5 |

未设置或配置值不合法时使用各项默认值。触发边界包含所选距离；落点排除同步使用所选范围。

矩形从 Boss 位置向正前方延伸 4×tan30° ≈ 2.309，左右各宽 4（总宽 8）；远端两个角恰好接到扇形的两侧边界，再与扇形取并集。触发和落点排除使用同一并集判断。

全部距离忽略高度。备用区域以 **Shrouden 为圆心、半径 20**，先选离 Boss 更远的位置；同时要求玩家到落点不超过 36，至少移动 3，并离开当前技能危险区域。

落点与四种 shadowthrall_wings、shadowthrall_hands、shadowthrall_horns、shadowthrall_mouth 至少相距 **4**，与 charliearena_spike 至少相距 **2**。还会排除不可通行地形、地洞、传送禁区和玩家碰撞障碍。普通地面杂物不当作实体目标，避免点到杂物后改变动作。

搜索采用有界极坐标采样：背后半径步长 0.25，备用区域半径步长 0.5，采样弧长间隔不超过 0.75。它不会穷举连续空间；没有采到安全位置时跳过本次传送。

## 闪现方式与物品安全

1. 玩家拥有 soulstealer 标签、携带灵魂并满足原版跳跃条件时，优先灵魂跳跃；已装备橙杖也不会抢占角色跳跃动作。
2. 其余情况查找鼠标、主物品栏、背包及装备栏中的 orangestaff，或 _gem 为 orangegem 且具有客户端 reticule 的 king_cane。不选择仅剩一次及以下使用次数的法杖：orangestaff 剩余耐久必须大于 5%。原版 king_cane 无使用次数耐久，但充能未满或带有 nomagiccast 时不选；同时读取客户端同步充能值，避免冷却标签尚未更新时误选。必要耐久/充能数据尚未同步时等待下一次判断。
3. 提交前一次性验证技能、落点、法杖和存放空间，然后在**同一次更新中**按顺序发送原版“存放鼠标物品 → 从物品栏/背包/装备栏取杖 → 点传送”RPC，不等待每一步的网络回执。初始库存或相关背包忙碌时暂缓整组请求；没有安全落点时不先移动物品。
4. 服务端按原版流程自动装备并施法；房主在同次更新中使用同步库存接口及原版动作。确认实际位移后，等待库存回执、恢复原武器，再把操作所属的鼠标物品放回物品栏。即使传送前就把手杖拿在鼠标上，结束时也会将其存入物品栏。恢复最多重试 5 秒，超时记录 WARN；用户中途更换鼠标物品时不强行覆盖。

背包满、没有资源、玩家忙碌或输入界面阻止操作、地形没有安全落点时不会强行传送。使用法杖若会使原装备因缺少空间而掉落，也会放弃。未确认实际位移的请求按超时处理，再按间隔重新判断。

同帧指客户端在一次更新中连续提交请求，不保证服务端同帧完成实际位移；原版施法动画、服务器验证和网络传输仍然存在。本 Mod 不提供无消耗瞬移，不修改原版库存忙碌标记，也不增加服务端 RPC。

## Mod 图标

Mod 菜单图标使用当前静态预览 `docs/media/ds_dodge_step.png`，包含 A「破风疾闪」手绘标题、斜向光束和星光。完整构图转换为 1024×1024 的 BC3 纹理并生成 mipmaps，由 `modinfo.lua` 的 `icon_atlas` / `icon` 引用 `images/ds_modicon.xml` / `ds_modicon.tex`。

更新预览后，在项目根目录执行 `python tools/ds_build_modicon.py` 重新生成。离线构建需要 Python、Pillow 和 Klei Mod Tools 的 `TextureConverter.exe`；工具默认查找同一 Steam common 目录下的安装，也可通过 `--converter` 指定路径。游戏运行不依赖这些开发工具。

## 目录与开发约定

- modmain.lua：仅按顺序导入 main/ 模块。
- main/constants.lua：配置读取与校验、DS_CONFIG、DS_LOG_LEVEL、DS_DODGE、DS_SHROUDEN、DS_STAFF、DS_BOSS_REGISTRY。
- main/toolutil.lua：DS_Log、DS_GetString、Boss 登记、法杖/空槽查询、落点环境验证。
- main/postinit.lua：显式导入 postinit/prefabs/player.lua 和 shrouden.lua。
- scripts/components/ds_bosswatcher.lua：只在 ThePlayer 上运行，0.25 秒核对登记表。
- scripts/components/ds_shrouden.lua：方案提供 Enable / Disable，危险技能检查间隔约两帧。
- scripts/ds_shroudenplan.lua：动画、扇区与落点排序；不提交动作。
- scripts/ds_blink.lua：异步传送事务、原版动作/RPC、位移确认与清理。
- strings/、scripts/languages/：英文原文、POT 和中文 PO。
- tests/：Lua 5.1 离线回归；docs/：设计、实施记录。
- images/ds_modicon.tex、images/ds_modicon.xml：Mod 菜单图标和图集。
- tools/ds_build_modicon.py：从静态预览重新生成图标。
- scripts/screens/、scripts/widgets/、anim/：预留目录。

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
lua51 tests/ds_config_spec.lua
lua51 tests/ds_shroudenplan_spec.lua
lua51 tests/ds_blink_spec.lua
lua51 tests/ds_lifecycle_spec.lua
lua51 tests/ds_loading_spec.lua
```

将 lua51 替换为实际解释器；默认 lua/luac 可能是 Lua 5.4，不能代替 Lua 5.1 检查。测试使用游戏 Class、原版控制器动作函数和翻译器，默认游戏脚本路径沿用 AGENTS.md；其他安装位置可设置 DS_GAME_SCRIPTS 环境变量。

也可使用 Python 的 lupa.lua51.LuaRuntime 加载测试。测试模拟网络、库存同步和角色实体，不能代替实际客户端运行。

游戏内仍需验证：三项配置的全部档位、独立关闭和中英文菜单，三种技能的识别和反应时机、普通远程客户端的移动预测开关、灵魂与两种法杖、满包及地面杂物、多 Boss／离开再进入范围、幽灵与重连、中英文 Mod 菜单显示。作者：TUTU。Mod 菜单以中英文简要介绍支持闪避的技能和闪避方式。

2026-11-06 离线验证：21 个 Lua 文件通过 Lua 5.1 语法检查，66 组回归通过，双语资源一致性及 git diff --check 通过。普通远程客户端实战和游戏内 UI 尚未验证。

2026-11-07 距离配置离线验证：22 个 Lua 文件通过 Lua 5.1 语法检查，80 组回归通过（新增配置回归 14 组），中英文元信息与 PO/POT 一致性及 git diff --check 通过。三项配置在普通远程客户端中的触发距离、独立关闭和游戏内菜单显示仍待实测。
