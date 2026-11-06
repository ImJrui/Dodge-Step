# 闪身步宣传动图

`ds_dodge_step.gif` 为 960 × 960、25 fps、6.4 秒的无限循环动图；`ds_dodge_step.png` 为同尺寸静态预览。

画面顺序：Wortox 在左侧持亮茄剑；Shrouden 在右侧朝左施放传送门召唤；Wortox 通过灵魂跳跃落到 Shrouden 的背后，召唤出的暗影随从扑向原位置。背景与标题为离线合成。上方标题采用原创手绘 A「破风疾闪」方案，使用橙黄色渐变、刀锋笔画、断笔与速度拖尾，不显示英文副标题和底部说明文字。字形源文件和透明图层保存在 `custom-titles/`。

场景增加 Charlie Boss 竞技场风格的动态装饰：原版斜向紫红光束、淡粉碎光、额外闪烁星芒和少量红色余烬。主要光束位于角色后方，标题区域不叠加粒子；粒子轨迹和星芒闪烁为离线合成。

角色、武器与技能来自本机游戏资源：

- `anim/dynamic/wortox.dyn` 和 `databundles/anim_dynamic.zip` 中的 Wortox build。
- `anim/player_idles.zip`、`anim/wortox_portal.zip`。
- `anim/sword_lunarplant.zip`。
- `anim/shrouden_build.zip`、`anim/shrouden_basic.zip`、`anim/shrouden_actions.zip`、`anim/shrouden_voidcloth.zip`。
- `anim/shadow_thrall_hands.zip`。
- `anim/charlie_arena_light_ray.zip`，按原版单独显示光束层。
- `fx/debris.tex` 用于淡粉碎光；余烬颜色、漂浮和淡入淡出参考 `prefabs/charlie_boss_trial.lua`。

本目录为宣传媒体，不接入 Mod 运行时，也不是游戏内功能验证录像。制作过程仅按需读取游戏资源，未写入游戏源码或资源目录。
