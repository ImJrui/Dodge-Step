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

- ds_shroudenplan_spec：9 例，覆盖技能动画、平面距离、朝向边界、背后扇环、搜索排序和拒绝仍在危险区的落点。
- ds_blink_spec：27 例，覆盖灵魂优先、两种法杖、主库存/背包/装备、鼠标存放、满包保护、危险实体/地形、预测与无预测/房主、实际位移确认、超时、取消恢复、库存预测忙碌及装备回执、零物品槽保护。
- ds_lifecycle_spec：8 例，覆盖当前玩家、Boss 先到、多 Boss、休眠/唤醒/移除、原回调参数与返回值、玩家停用/重新激活。
- ds_loading_spec：3 例，覆盖完整入口和 Hook 注册、中英文、未知语言回退、默认翻译环境恢复及 DS_ 全局前缀。

共享夹具 ds_testutil.lua 加载游戏真实 Class；传送测试读取并运行原版 PlayerController:DoAction / DoActionAutoEquip，翻译测试读取并运行原版 translator.lua。实体、动作预览、网络和库存同步由离线夹具模拟；这些检查不能证明游戏实战反应时机或远程服务器实际接受请求。
