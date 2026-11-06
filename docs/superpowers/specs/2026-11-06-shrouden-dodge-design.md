# Shrouden 自动闪避设计

## 用户要求与约定

- 仅当前玩家挂载 ds_bossprefab 格式组件；当前为 ds_shrouden，提供 Enable / Disable。
- Boss 进入客户端加载范围或生成时启用，休眠、离开范围或移除时停用；处理先出现 Boss、后激活玩家的顺序。
- main/ 和 postinit/ 使用 local PLENV = env 与 GLOBAL.setfenv(1, GLOBAL)；modmain 只导入。
- 不访问 Boss 服务端 sg、combat、timer 等字段，不修改原版文件，不增加服务端 Mod RPC。

## 技能与几何

- punch_pre / punch_loop：前方半径 12、±60° 扇形，与前向深度 4×tan30°（约 2.309）、左右各宽 4 的矩形的并集内触发；矩形从 Boss 位置开始，远端两角接到扇形两侧边界。触发和落点排除复用同一并集判断。
- 首选落点：Boss 后方 ±60° 且 4<r≤8，按半径从小到大搜索。
- optic_blast_pre2 / optic_blast_loop / optic_blast_pre3：Boss 已落位，平面距离 ≤6.5 时触发；不在起飞 pre1 阶段误判。
- teleport_loop：恶液形态，平面距离 ≤4.5 时触发。
- 备用区域以 Boss 为圆心 r≤20，按半径从大到小搜索；限制玩家到落点 ≤36，至少移动 3，并排除仍位于当前技能危险区的落点。
- 使用有界极坐标采样，首选半径步长 0.25，备用 0.5，角度间距对应弧长不超过 0.75；不是连续空间的数学穷举。
- shadowthrall_wings / hands / horns / mouth 与落点至少相距 4，charliearena_spike 至少 1.2；无论归属均避让。
- 读取客户端 Map 通行、地洞和传送许可；快照筛掉有玩家碰撞的实体，普通地面物品不当作障碍。

## 模块边界

- scripts/ds_shroudenplan.lua：纯技能/几何判断，接受候选验证回调。
- scripts/ds_blink.lua：整组物品及空间预检、同次更新连续提交原版 RPC、位移确认、等待回执及鼠标清空。
- scripts/components/ds_shrouden.lua：遍历登记 Boss，控制闪避与重试间隔，停用时取消准备和清理工具。
- scripts/components/ds_bosswatcher.lua：低频核对已登记且未休眠 Boss，创建/启停方案；不遍历全部实体。
- postinit/prefabs/player.lua 与 shrouden.lua：玩家生命周期和 Boss 登记，保留原 OnEntityWake / OnEntitySleep。
- main/constants.lua 与 main/toolutil.lua：公共阈值、登记和候选环境检查。

## 传送事务

优先 soulstealer 且携带灵魂并可灵魂跳跃的玩家。使用角色专用点动作/RPC，避免已装备橙杖抢占。其余查找 orangestaff 或客户端 _gem 为 orangegem 且具有 reticule 的 king_cane，排除 nomagiccast、冷却未完成及剩余使用次数≤1的法杖；orangestaff 同步耐久需大于 5%，原版 king_cane 无耐久次数限制但需充能完成。必要同步数据未到时暂不选择，施法提交前再次检查。

先验证初始库存/相关背包不忙碌、鼠标物品存放槽、法杖来源、原装备和结束后物品的空间；在同次更新中顺序提交原版存放、取杖和 BLINK RPC，不逐步等待客户端回执，也不修改本地预测或 busy 标记。库存、背包和装备槽均检查。空间不足或没有安全落点时不提交任何半组操作，不使用可能丢物的 ReturnActiveItem。

施法不使用真实鼠标位置/目标，传送杖右键请求的实体目标为 nil；灵魂跳跃使用 ControllerAltActionButtonPoint 的 isspecial 路径。远程客户端不依赖本地移动预测回调，服务端按原版判断、自动装备和执行；房主直接在同次更新中调用原版库存及控制器接口。提交后检查实际平面位移，未确认不报告成功；超时后有限重试。完成或取消后等待迟到的库存回执，先恢复原武器，再把操作所属鼠标物品存入物品栏；传送前鼠标持杖也不回到鼠标。恢复最多 5 秒，不能覆盖用户更换的无关物品，不能以丢弃物品收尾，超时记录 WARN。同帧提交不代表服务器同帧完成位移。

## 验证

Lua 5.1 离线回归覆盖角度与距离边界、背后环形差集和搜索优先级、禁区、地形、灵魂优先、取放与网络延迟、满包、杂物 nil 目标、预测/无预测/房主、重试与生命周期清理。游戏内必须另行验证攻击动画、实际 RPC 与 UI，同步说明未执行项。
