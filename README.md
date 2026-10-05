# super_battle

一款用 **Godot 4.7**（GL Compatibility 渲染后端）制作的 **俯视角清版射击游戏**，
画面 **1920 × 1080**，关卡可**纵向或横向**推进；支持 **本地最多 4 人同屏**，
玩法参考 NES 时代的《古巴英雄》《赤色要塞》。

> **2049 年，外星种族「赛瑟兰」以拟态潜伏并控制了榕城（原型福州）。**
> 军方启动「烛龙计划」，4 名超级战士深入榕城六区，逐区夺回城市，最后在鼓楼区与主脑决战。

> **项目状态：M0（基础工程框架）已完成并可运行；系统与内容设计已完成；下一步进入 M1（战役流程与数据重构）。**
> 已实现：标题 → 选人 → 战斗关卡的完整主循环、4 人独立输入、8 方向移动射击、敌人与子弹、
> 纵向 / 横向推进相机、通关 / 阵亡判定、四角玩家 HUD、暂停菜单、本地存档、i18n。
> 待实现（详见 [dev_plan.md](dev_plan.md)）：六区战役流程、武器拾取、载具、Boss 战、
> 24 小关、打击感、音效、AAP-64 像素素材。

## 目录结构

```text
super_battle/            # 仓库根目录：只放文档与配置
├── README.md            # 本文件
├── story_design.md      # 剧情与世界观（外星拟态入侵榕城、4 名超级战士）
├── level_design.md      # 关卡设计（6 大关 = 福州 6 区、24 小关、6 个 Boss）
├── feature_design.md    # 玩法与系统设计（武器 / 载具 / 敌人 / 难度 / 打击感）
├── art_style.md         # 美术风格与 AAP-64 调色板
├── code_design.md       # 代码设计规范（唯一编码规范，写代码前必读）
├── dev_plan.md          # 开发计划（M0~M12 里程碑与任务清单）
└── super_battle/        # Godot 工程本体（用 Godot 4.7 打开这个目录）
    ├── project.godot
    ├── autoload/        # 全局单例：Game / UserData / StageData / InputManager / SoundManage / SceneTransition
    ├── script/          # 脚本，按职能分子目录：player enemy bullet level ui menu pickups fx
    ├── scene/           # 场景，按类别分子目录：player enemy bullet level ui pickups fx
    ├── lang/            # language.csv（i18n 文案，导入后生成 .translation）
    ├── sprite/ sound/ theme/ font/ shader/   # 资源
    ├── addons/          # 第三方插件
    └── tools/           # 临时探针 / 开发脚本（不进正式构建）
```

## 设计速览

| 项 | 内容 |
| --- | --- |
| 城市 | 榕城（原型福州），**6 大关对应福州 6 区** |
| 进攻顺序 | **固定顺序**：马尾 → 长乐 → 仓山 → 台江 → 晋安 → 鼓楼（玩家不需要选择路线） |
| 六大关 | ①马尾（船政残骸）· ②长乐（空港坠落）· ③仓山（千面校园）· ④台江（钢铁中枢）· ⑤晋安（鼓山孵化林）· ⑥鼓楼（渊心） |
| 关卡结构 | 每大关 **4 小关** = 3 推进关 + 1 Boss 关；单大关 13~20 分钟 |
| 推进方式 | 关卡可**纵向**（画面向上推进）或**横向**（画面向右推进），由关卡数据决定 |
| 超级战士 | 锋刃·陆铮（男）· 铁砧·韩铁（男）· 雷管·周牧（男）· 银针·沈晴（女） |
| 特色机制 | **拟态**：敌人可伪装成平民，需相位扫描识破；误伤平民只扣分不判负 |
| 武器 | 靠**地面拾取**，14 种枪械 + 投掷物；打空自动退回无限弹药的手枪 |
| 载具 | 7 种（吉普 / 装甲车 / 坦克 / 直升机 / 摩托 / 炮艇 / 缴获机甲） |
| 难度 | 只随进度与人数变化；**失败不会提高难度** |
| 性命 / 续关 | 每人 **2 条命**；全员命尽 → 「是否继续游戏」画面，**无限续关**（不提高难度） |
| 配色 | Aseprite 内置 **AAP-64**（64 色），像素风、俯视角、4 px 网格；画面固定 **1920 × 1080** |

详细设计见 [story_design.md](story_design.md)、[level_design.md](level_design.md)、[feature_design.md](feature_design.md)、[art_style.md](art_style.md)。

## 运行

1. 用 **Godot 4.7** 打开 `super_battle/`（即含 `project.godot` 的目录）。
2. 首次打开会自动导入资源（生成本地 `lang/*.translation`、`.import` 等）。
3. 按 `F5` 运行，主场景是 `scene/ui/title.tscn`。

命令行导入 / 冒烟运行：

```bash
"/path/to/Godot 4.7" --headless --path super_battle --import
"/path/to/Godot 4.7" --headless --path super_battle --quit-after 240
```

## 操作（默认键位）

| 玩家 | 移动 | 开火 | 必杀 | 开始 / 暂停 |
| --- | --- | --- | --- | --- |
| P1 | `W A S D` | `G` | `H` | `Enter` |
| P2 | `↑ ↓ ← →` | 小键盘 `1` | 小键盘 `2` | 小键盘 `0` |
| P3 | `I J K L` | `U` | `O` | `P` |
| P4 | 小键盘 `8 4 5 6` | 小键盘 `7` | 小键盘 `9` | 小键盘 `3` |

手柄：1~4 号手柄分别对应 1~4 号玩家，左摇杆移动，`A` 开火、`X` 必杀、`Start` 暂停 / 开始。

按键映射集中在 [autoload/input_manager.gd](super_battle/autoload/input_manager.gd) 的常量表里，改键只改数据。

## 关键约定

- 所有手写代码、AI 生成代码、代码审查一律以 **[code_design.md](code_design.md)** 为准。
- 函数 / 变量用 `camelCase`，常量用 `CONSTANT_CASE`，类名 / 枚举名用 `PascalCase`，脚本 / 场景文件名用 `snake_case`。
- 成员 / 参数 / 返回值显式声明类型；私有成员不加 `_` 前缀（引擎回调保留 `_`）。
- 脚本顺序：`@onready` → `_ready` → 自定义函数 → **其它内置虚函数放最后**。
- 静态属性在 **编辑器 Inspector** 里设；可复用逻辑做成「基础场景 + 基础脚本」。
- 玩家可见文案一律走 `tr()` + `lang/language.csv`。

