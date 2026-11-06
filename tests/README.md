# 闪身步离线回归测试

在项目根目录使用 Lua 5.1 逐个执行：

```text
lua51 tests/ds_shroudenplan_spec.lua
lua51 tests/ds_blink_spec.lua
lua51 tests/ds_lifecycle_spec.lua
lua51 tests/ds_loading_spec.lua
```

默认 lua.exe 若为 5.4，不能运行这些依赖 setfenv 的测试。也可使用 Python 的 lupa.lua51.LuaRuntime 逐个加载；无需向游戏运行环境安装 Python 或测试依赖。

测试默认使用 AGENTS.md 指定的本地游戏脚本目录。安装位置不同可通过 DS_GAME_SCRIPTS 指向 data/databundles/scripts。

- ds_shroudenplan_spec：14 例，覆盖技能动画、当前配置的激光/恶液距离边界、扇形与深度 4×tan30° 矩形并集、衔接及旋转边界、缩短矩形后的备用落点、背后扇环、搜索排序和拒绝仍在危险区的落点。
- ds_blink_spec：41 例，覆盖同次更新时间戳、原版服务端 RPC 顺序、分开处理且无客户端回执、背包/装备槽、房主与无预测客户端、灵魂优先、原武器恢复和鼠标清空、晚到回执、装备来源取消、服务端忙碌拒绝、满包及未知耐久保护。
- ds_lifecycle_spec：8 例，覆盖当前玩家、Boss 先到、多 Boss、休眠/唤醒/移除、原回调参数与返回值、玩家停用/重新激活。
- ds_loading_spec：3 例，覆盖完整入口和 Hook 注册、中英文、未知语言回退、默认翻译环境恢复及 DS_ 全局前缀。

共享夹具 ds_testutil.lua 加载游戏真实 Class；ds_blink_testutil.lua 使用分开的客户端/服务端库存快照，并读取运行原版 networkclientrpc 中的存放、取杖、点传送处理函数，以及 PlayerController:DoAction / DoActionAutoEquip / OnRemoteRightClick。背包实体也区分客户端和服务端，队列与同步时机可单独控制。翻译测试运行原版 translator.lua。

实体、网络传输、库存组件内部和实际位移由夹具模拟；原版处理函数通过测试不代表游戏实战时机或真实网络一定成功。
