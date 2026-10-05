# super_battle 代码设计规范（Code Design Guidelines）

> 本文档是本项目的**唯一编码规范**：手写代码、AI 生成代码、代码审查一律以它为准。
> 目的是让不同时间、不同人（或不同 AI）写出来的代码风格保持一致，降低阅读与维护成本。

| 项目 | 内容 |
| --- | --- |
| 适用项目 | super_battle（Godot 4.7，GDScript） |
| 文档版本 | v1.0 |
| 更新日期 | 2026-10-05 |
| 主要依据 | Godot 官方《GDScript style guide》《Static typing in GDScript》+ 本项目既定约定 |

> ⚠️ **务必注意**：文中标注「**本项目约定**」的条目，是对 Godot 官方风格的**有意偏离**。
> 生成或审查代码时**不要**按官方默认风格去“纠正”它（例如把 camelCase 改回 snake_case、把内置虚函数挪到文件开头、把显式类型改成 `:=`），否则会破坏全文一致性。

---

## 目录

- [0. 强制规则速查（写代码前必读）](#0-强制规则速查写代码前必读)
- [1. 格式规范](#1-格式规范)
- [2. 命名规范](#2-命名规范)
- [3. 类型与静态类型](#3-类型与静态类型)
- [4. 文档注释](#4-文档注释)
- [5. 代码顺序](#5-代码顺序)
- [6. 项目架构设计](#6-项目架构设计)
- [7. Godot 最佳实践](#7-godot-最佳实践)
- [8. 提交前审查清单](#8-提交前审查清单)

---

## 0. 强制规则速查（写代码前必读）

> 下面 10 条是最容易“跑偏”的地方，生成代码前先过一遍。

| # | 规则 | 备注 |
| --- | --- | --- |
| 1 | 函数、变量用 **camelCase** | 官方是 snake_case，**本项目不用** |
| 2 | 常量用 **CONSTANT_CASE**，类名 / 枚举名用 **PascalCase** | 见 §2 |
| 3 | 不得占用 Godot 内置名 | 如 `position` / `scale` / `name` / `visible` / `get` / `set` |
| 4 | 顺序：`@onready` → `_ready` → 自定义函数 → **其它内置虚函数放最后** | 本项目约定，与官方相反 |
| 5 | 成员 / 参数 / 返回值**显式声明类型** | 局部变量可省略类型；不用 `:=` 推断 |
| 6 | 场景能设的属性在**编辑器 Inspector** 里设 | 不要全塞进代码 |
| 7 | 可复用功能先做**基础场景 + 基础脚本** | 子类只覆盖差异 |
| 8 | 缩进 **Tab**、行宽 ≤ 100、UTF-8 无 BOM、LF 换行 | 见 §1.1 |
| 9 | 注释符号后**必须一个空格**：`# 文字`、`## 文字` | 被注释掉的代码除外：`#print(...)` |
| 10 | 玩家可见文案一律走 `tr()` + `lang/language.csv` | 不硬编码中文 / 英文 |

---

## 1. 格式规范

### 1.1 文件与编码

- 换行用 **LF**（`\n`），不要 CRLF / CR。
- 文件结尾保留**一个**换行。
- 编码 **UTF-8，无 BOM**。
- 缩进用 **Tab**，不用空格。
- 保存前用编辑器格式化：脚本编辑器内 `Ctrl + Alt + L`。

### 1.2 缩进

- 每个代码块比外层多一级缩进。
- 换行的**连续行**用**两级**缩进，以便与普通代码块区分。
- **例外**：数组、字典、枚举的续行只用**一级**缩进。

```gdscript
# 好：普通连续行用 2 级缩进
effect.interpolate_property(sprite, "transform/scale",
		sprite.get_scale(), Vector2(2.0, 2.0), 0.3,
		Tween.TRANS_QUAD, Tween.EASE_OUT)

# 好：数组 / 字典 / 枚举用 1 级缩进
var party = [
	"Godot",
	"Godette",
]
```

### 1.3 空行

- 函数之间、类定义之间空**两行**；函数内部用**一行**分隔逻辑段落。
- 成员声明块内部（signal / enum / const / export / var / @onready）不强制空行。

### 1.4 行宽

- 单行**不超过 100 字符**，尽量控制在 80 以内（便于并排看代码）。

### 1.5 一行一语句

```gdscript
# 好
if position.x > width:
	position.x = 0

# 坏
if position.x > width: position.x = 0
```

唯一例外是三元表达式：

```gdscript
nextState = "idle" if is_on_floor() else "fall"
```

### 1.6 多行语句排版

长条件、长表达式用**括号**换行（优于反斜杠），并把 `and` / `or` 放在**续行行首**。

```gdscript
var quadrant = (
		"northeast" if angleDegrees <= 90
		else "southeast" if angleDegrees <= 180
		else "northwest"
)

if (
		position.x > 200 and position.x < 400
		and position.y > 300 and position.y < 400
):
	pass
```

### 1.7 不要多余的括号

```gdscript
# 好
if is_colliding():
	queue_free()

# 坏
if (is_colliding()):
	queue_free()
```

### 1.8 布尔运算符

用 `and` / `or` / `not`，不要 `&&` / `||` / `!`。

### 1.9 注释

- 普通注释用 `#`、文档注释用 `##`，符号后**必须跟一个空格**。
- 被注释掉的**代码不加空格**：`#print("disabled")`。
- 区域注释 `#region` / `#endregion` 顶格写，**不加**空格。
- 优先把注释写在**独立一行**；行尾注释只用于很短的说明。
- 注释用中文，说明**为什么**这么做，而不是复述代码在做什么。

### 1.10 空白 / 引号 / 数字

- 运算符两侧、逗号后各留一个空格；不要为“对齐”加多余空格。
- 单行字典 `{ key = "value" }` 花括号内侧各留一个空格，以便与数组区分。
- 字符串默认用**双引号**；仅当能减少转义时才用单引号。
- 浮点数不省略前后 0：写 `0.234`、`13.0`（不写 `.234`、`13.`）。
- 十六进制用小写：`0xfb8c0b`。
- 大数字用下划线分隔：`1_234_567_890`（小于 100 万的数一般不必）。

### 1.11 尾随逗号

多行数组 / 字典 / 枚举的最后一项**加尾随逗号**（便于 diff 与增删条目）；单行列表**不加**。

```gdscript
# 好（多行，带尾随逗号）
var array = [
	1,
	2,
	3,
]

# 好（单行，不带）
var array = [1, 2, 3]
```

---

## 2. 命名规范

### 2.1 总表

| 对象 | 本项目约定 | 示例 | 来源 |
| --- | --- | --- | --- |
| 函数 | **camelCase** | `func loadLevel()` | 本项目约定（官方为 snake_case） |
| 变量 | **camelCase** | `var playerHud` | 本项目约定（官方为 snake_case） |
| 私有函数 / 变量 | **camelCase，不加 `_` 前缀** | `var spawnCooldown`、`func onEnemyEscaped()` | 本项目约定（官方为 `_snake_case`） |
| 常量 | **CONSTANT_CASE** | `const MAX_PLAYERS = 4` | 官方 |
| 类名 `class_name` | **PascalCase** | `class_name PlayerCharacter` | 官方 |
| 节点名 | **PascalCase** | `PlayerHud`、`BattleCamera` | 官方（新建场景尽量照此） |
| 枚举名 | **PascalCase，单数** | `enum WeaponType` | 官方 |
| 枚举成员 | **CONSTANT_CASE** | `WeaponType.PISTOL` | 官方 |
| 信号 | **camelCase，过去式** | `signal enemyDied` | 官方过去式 + 本项目 camelCase |
| Autoload 单例 | **PascalCase** | `Game`、`InputManager` | 官方 |
| 脚本 / 场景文件名 | **snake_case** | `base_level.gd`、`player_hud.tscn` | 官方（避免跨平台大小写问题） |
| InputMap 动作 | **snake_case，`pN_` 前缀** | `p1_move_up`、`p2_fire` | 见 §6.9 |

> **例外**：**Godot 引擎回调必须保留 `_` 前缀**（`_ready`、`_process`、`_physics_process`、`_input`、`_unhandled_input`、`_draw`、`_notification`、`_enter_tree`、`_init` 等），它们是引擎按名字调用的，改名会失效。

### 2.2 禁止占用 Godot 内置名（本项目约定，强制）

自定义变量 / 函数**不得**与 Godot 内置属性、方法、常量、信号重名，否则会产生遮蔽（shadowing）警告，严重时导致运行期行为异常。

常见必须避开的名称（非完整清单）：

- **节点通用属性**：`name`、`owner`、`process_mode`、`scene_file_path`
- **`Node2D` / `Node3D` 变换与显示**：`position`、`global_position`、`rotation`、`scale`、`skew`、`transform`、`z_index`、`visible`、`modulate`
- **`Control`**：`size`、`pivot_offset`、`focus_mode`、`theme`
- **`CollisionObject2D`**：`collision_layer`、`collision_mask`
- **常见方法**：`get`、`set`、`connect`、`call`、`free`、`queue_free`、`duplicate`、`to_string`
- **全局函数**：`abs`、`min`、`max`、`clamp`、`lerp`、`randf`、`randi`、`print`、`range`、`sign`、`snapped`

> 拿不准就去 Godot 类文档里搜同名项；编辑器出现 “shadowed variable” 警告即说明已踩线。
>
> 例：本项目把「收尾 / 补间」类函数命名为 `fadeTo`、把「刷怪冷却」命名为 `spawnCooldown`，
> 都是为了避开 `tween`、`timer` 之类的内置名。

---

## 3. 类型与静态类型

### 3.1 所有声明都写显式类型（本项目约定）

> 官方风格是「能推断就用 `:=`」，**本项目相反**：为了可读性与统一，**成员变量、函数参数、返回值**一律写显式类型，不使用 `:=` 推断。
>
> **例外**：函数内部的**局部变量**可以不写类型（如 `var count = 0`），就近声明即可。

```gdscript
# 好
@export var moveSpeed: float = 280.0
var hp: int = 100
var players: Array[PlayerCharacter] = []
var weapon: Dictionary = {}

const MAX_PLAYERS: int = 4

func heal(amount: int) -> void:
	pass

func getMoveVector(playerIndex: int) -> Vector2:
	return Vector2.ZERO
```

```gdscript
# 坏：用 := 或干脆不写类型
@export var moveSpeed := 280.0
var hp = 100
func heal(amount):
	pass
```

### 3.2 具体类型标注

- 变量 / 参数 / 返回值：`名字: 类型`；返回类型用 `-> 类型`。
- 数组元素类型：`Array[PlayerCharacter]`；字典键值类型：`Dictionary[String, int]`。
  **不支持嵌套**，如 `Array[Array[int]]` 是非法的。
- 即使不打算做泛型约束，成员变量也至少写 `Array` / `Dictionary`，不要留裸 `var`（局部变量除外）。
- `get_node()` 无法被推断类型，必须显式声明：

```gdscript
@onready var healthBar: ProgressBar = $HealthBar
```

### 3.3 空值安全

- 用 `as` 强转会**静默变 `null`**：拿到结果后必须判空再使用。
- 需要暴露错误时，用 `is` / `is not` + `push_error()`，比 `as` 更安全。

```gdscript
var player = body as PlayerCharacter # 局部变量，可以不写类型
if player == null:
	return
player.takeDamage(10)
```

### 3.4 建议开启的警告

「项目设置 → Debug → GDScript」（需开启高级设置）中启用：
`UNTYPED_DECLARATION`、`INFERRED_DECLARATION` 以及 `UNSAFE_*` 系列，让编辑器帮忙盯住类型问题。

---

## 4. 文档注释

### 4.1 写法

- 文档注释用 `##`，写在**被说明成员的正上方**。
- 推荐分三块：**脚本类概述 / 脚本类详细描述 / 教程与特殊标记**，块与块之间用一行空的 `##` 分隔。
- 普通块内注释用 `#`；只有会被导出到文档的内容才用 `##`。

```gdscript
class_name PlayerCharacter
extends CharacterBody2D
## 玩家角色：4 人共用的基础控制器。
##
## 差异全部来自数据表（[member Game.characterInfo] / [member Game.weaponInfo]），
## 本脚本不写任何「某个角色 / 某把枪」的分支。
##
## @tutorial: https://example.com/player
## @experimental
```

### 4.2 特殊标记

特殊标记须写在文本行开头（可含前导空格），以 `@` 开头，后接标记名。

| 用途 | 标记 |
| --- | --- |
| 概述 | 无标记，位于文档开头部分 |
| 描述 | 无标记，用一行空的文档注释行与概述隔开 |
| 文字教程 | `@tutorial: https://example.com` 或 `@tutorial(标题写在此处): https://example.com` |
| 已弃用 | `@deprecated` / `@deprecated: 请改用 [AnotherClass]。` |
| 实验性 | `@experimental` / `@experimental: 该类不稳定` |

### 4.3 交叉引用

文档注释内用 BBCode 引用其它符号，方便在编辑器里跳转：
`[method takeDamage]`、`[member hp]`、`[signal enemyDied]`、`[PlayerCharacter]`、`[b]粗体[/b]`。

---

## 5. 代码顺序

### 5.1 脚本内顺序（本项目约定）

> **本项目约定**：自定义函数放**前面**，Godot 内置虚函数放**末尾**。
> 这与官方推荐（`_init` / `_ready` 在最前）**正好相反**——生成代码时不要“纠正”它。

约定顺序：

```text
01. @tool / @icon / @static_unload
02. class_name
03. extends
04. ## 类文档注释
05. signals
06. enums
07. constants
08. @export 变量
09. 普通成员变量（public 在前，private 在后；private 不加 `_` 前缀）
10. @onready 变量
11. _ready()（或初始化函数）
12. 自定义函数（public 在前，private 在后）
13. 其它 Godot 内置虚函数 / 回调（放最后）：
      _init / _enter_tree / _process / _physics_process /
      _input / _unhandled_input / _draw / _notification ……
14. 内部类（inner class）
```

示例：

```gdscript
class_name Enemy
extends CharacterBody2D
## 敌人基类。

signal enemyDied(scoreReward: int, killerIndex: int)

const CONTACT_CHECK_INTERVAL: float = 0.1

@export var maxHp: int = 40
@export var moveSpeed: float = 110.0

var hp: int = 0

@onready var contactArea: Area2D = $ContactArea

func _ready() -> void:
	add_to_group("enemy")
	hp = maxHp

# ---- 自定义函数放前面 ----
func takeDamage(amount: int, sourcePlayer: int = -1) -> void:
	hp -= amount
	if hp <= 0:
		die()


func die() -> void:
	enemyDied.emit(0, -1)
	queue_free()


# ---- Godot 内置虚函数放最后 ----

func _physics_process(delta: float) -> void:
	pass
```

### 5.2 成员变量与局部变量

- 只在单个方法里用到的值，**不要**提成成员变量，就写成局部变量。
- 局部变量**就近声明**，靠近首次使用处。
- `@onready` 只用于缓存节点引用（它在 `_ready` 之前求值），不要在 `_init` 里用 `$路径`。

---

## 6. 项目架构设计

### 6.1 目录结构

```text
super_battle/                  # Godot 工程根（含 project.godot）
├── autoload/                  # 全局单例（Autoload）
│   ├── game.gd                # Game：全局状态 + 角色 / 武器数据表
│   ├── user_data.gd           # UserData：本地存档（ConfigFile）
│   ├── stage_data.gd          # StageData：关卡表 + 敌人场景表
│   ├── input_manager.gd       # InputManager：注册 4 名玩家的 InputMap 动作
│   ├── sound_manage.gd/.tscn  # SoundManage：BGM + SFX 播放池
│   └── scene_transition.gd/.tscn  # SceneTransition：淡入淡出切场景
├── script/                    # 脚本，按职能分子目录
│   ├── player/ enemy/ bullet/ level/ ui/ menu/ pickups/ fx/
│   └── *.gd                   # 跨模块的独立脚本放根部
├── scene/                     # 场景，按类别分子目录
│   ├── player/ enemy/ bullet/ level/ ui/ pickups/ fx/
│   └── *.tscn                 # 被多类共用的基础 / 公共场景放根部
├── shader/                    # .gdshader
├── lang/                      # language.csv + 生成的 .translation
├── theme/  font/  sprite/  sound/   # 资源
├── addons/                    # 第三方插件
└── tools/                     # 临时探针 / 开发用脚本（不进正式构建）
```

规则：

1. **新文件放对应类别的子目录**；移动 / 改名文件后必须同步更新所有引用
   （`preload`、`.tscn` 的 `[ext_resource path]`、`project.godot` 的 autoload、`uid://`、代码里写死的场景路径）。
2. 只有被多个类别共用的基础场景 / 脚本才留在 `scene/`、`script/` 根部。
3. 场景名与脚本名对应（`player_character.tscn` ↔ `player_character.gd`），便于查找。

### 6.2 复用：基础场景 + 基础脚本（本项目约定）

> 出现可复用的功能时，**先做一份基础场景 + 基础脚本**，后续同类对象继承 / 实例化它，只覆盖差异。

- 已有范例：
  - 玩家：`scene/player/player_character.tscn` + `script/player/player_character.gd`（4 名玩家共用同一场景）。
  - 敌人：`scene/enemy/grunt.tscn` + `script/enemy/enemy.gd`；新敌人用**继承场景**改 Inspector 数值。
  - 子弹：`scene/bullet/bullet.tscn`（玩家弹）/ `enemy_bullet.tscn`（敌方弹）+ `script/bullet/bullet.gd`。
  - 关卡：`scene/level/base_level.tscn` + `script/level/base_level.gd`，子关卡 `level_1.tscn` 只改 `levelNumber`。
  - UI 面板：`open()` / `close()` + `signal xxxRequested` 的统一面板模式（见 `pause_menu.gd`）。
- 做法：
  - 子场景用**继承场景**（Inherit Scene）或直接实例化基础场景；
  - **数值差异优先在子场景的 Inspector 里改**，不要在子脚本里重新赋值；
  - 只有**行为差异**才在子脚本里覆盖方法。
- 新增敌人 / 武器时，记得同步登记数据表（`StageData.enemyScenes`、`Game.weaponInfo`），做到“只加数据、不加逻辑”。

### 6.3 节点与属性设置（本项目约定）

> 在场景里添加节点时，属性**尽量在编辑器 Inspector 里直接设置**，不要全用代码赋值。

- 位置、尺寸、颜色、层级、碰撞层、锚点、主题等**静态属性** → Inspector。
- 只有**运行期才确定**的值才在代码里设置。
- 好处：所见即所得、代码更短，并避免“代码赋值覆盖场景配置”这类问题。

```gdscript
# 好：静态属性都在场景里设好，代码只做运行期逻辑
func _ready() -> void:
	pass

# 坏：把本该在场景里设的静态属性硬编码进代码
func _ready() -> void:
	position = Vector2(540, 960)
	modulate = Color.RED
	collision_layer = 1
```

> **⚠️ 场景资源文件里不能写注释。** `.tscn` / `.tres` 是 Godot 的**文本资源格式**，
> 它**不支持 `#` 注释** —— 写了会让整个资源报 `Parse Error: Parse error.`（带行号），
> 场景直接加载失败。要给某个属性留说明，写到**脚本的 `##` 文档注释**、
> `code_design.md` / `feature_design.md`，或提交信息里。

### 6.4 单例（Autoload）

- 跨场景共享的状态与事件放在 `autoload/`，用 **PascalCase** 命名，全局直接访问
  （`Game`、`UserData`、`StageData`、`InputManager`、`SoundManage`、`SceneTransition`）。
- 单例之间不要强耦合；对外用 `signal` 暴露事件，其它系统监听而非直接调用。
- 加载顺序即 `project.godot` 里 `[autoload]` 的先后：**被依赖者在前**
  （`Game` → `UserData` → `StageData` → `InputManager` → `SoundManage` → `SceneTransition`），
  否则 `_ready` 里访问别的单例会拿到 `null`。
- 注意：**Autoload 的枚举值不是编译期常量**，所以用它做 key 的表只能写 `var`，不能写 `const`
  （在单例自己的脚本内部写 `const` 引用自身枚举是允许的）。

### 6.5 数据与逻辑分离

- 数值、角色表、武器表、关卡配置等**数据**集中声明（字典 / `Resource`），逻辑只读数据，不硬编码分支。
- 目标：**新增条目只加数据、不改逻辑**（如往 `Game.weaponInfo` 加一条即多一把武器）。
- 面板 UI 统一采用「数据层字典 → 显示层只认字典」的写法（见 `character_slot.gd`）。

### 6.6 信号驱动

- 模块间通信优先用 `signal`，少用直接引用。
- 信号名用**过去式 + camelCase**：`enemyDied`、`weaponChanged`、`levelCleared`。
- 在 `_ready()` 里连接；连接到节点的信号会在节点释放时自动断开，无需手动 `disconnect`。
- 自定义信号要显式声明，参数尽量带类型注解。

### 6.7 分组与物理层

- 同类对象入组（`player`、`enemy`、`playerBullet`、`enemyBullet`、`pickup`），方便批量查找。
- 物理层严格按 `project.godot` 里 `layer_names` 的定义使用，不要凭记忆写数字。

| 层 | 名称 | 位值 | 用途 |
| --- | --- | --- | --- |
| 1 | player | 1 | 玩家碰撞体 |
| 2 | enemy | 2 | 敌人碰撞体 / 接触判定 |
| 3 | playerBullet | 4 | 玩家子弹 |
| 4 | enemyBullet | 8 | 敌方子弹 |
| 5 | pickup | 16 | 补给掉落 |
| 6 | obstacle | 32 | 地形障碍 |

> 常用组合：玩家 `layer=1 mask=32`；敌人 `layer=2 mask=32`；
> 玩家子弹 `layer=4 mask=2`；敌方子弹 `layer=8 mask=1`；补给 `layer=16 mask=1`。

### 6.8 国际化

- 所有玩家可见文案用 `tr("key")`，文案集中在 `lang/language.csv`。
- CSV 首列固定为 `keys`，其后每个语言一列（`en`、`zh`），导入后生成 `lang/language.<locale>.translation`。
- 新增文案要**同时补全所有语言列**；不要漏 `en` 造成回退成 key。
- **不要**把翻译结果缓存到成员变量（切换语言不会重载场景，缓存会变旧）。

### 6.9 4 人本地输入（本项目约定）

- 输入动作在**运行时**由 [autoload/input_manager.gd](super_battle/autoload/input_manager.gd) 注册，
  命名统一为 `p<玩家序号>_<动作>`：`p1_move_up`、`p1_fire`、`p3_bomb`、`p4_start`……
  **不要**把这些动作手写进 `project.godot`（几十条 `InputEvent` 难以维护、无法自定义按键）。
- 玩家序号是 **0~3 的槽位**，界面上显示为 `P1~P4`，两者相差 1，转换只允许出现在 UI 文本里。
- 手柄按**设备号**分派：`device 0` → 1 号玩家……`device 3` → 4 号玩家。
- 取输入一律走 `InputManager.getMoveVector()` / `isFirePressed()` 等封装，**不要**在玩法脚本里手拼动作名字符串。
- 玩家槽位配色统一用 `Game.PLAYER_COLORS`，HUD、角色描边、复活点标记共用，不要各写一份。

---

## 7. Godot 最佳实践

### 7.1 节点引用

- 用 `@onready` + `$路径` 缓存节点引用，不要在 `_process` 里反复 `get_node()`。
- `$路径` 只在父节点**已就绪**（`_ready` 之后）时才可用，`_init` 里不能用。

### 7.2 生命周期与性能

- 不需要每帧更新的节点，用 `set_process(false)` / `set_physics_process(false)` 关掉回调。
- 移动 / 动画优先用 `Tween`、`AnimationPlayer`，少在 `_process` 里手写插值。
- 计时用 `Timer` 节点或 `await get_tree().create_timer(秒).timeout`，少用自增计数。
- `_process` / `_physics_process` 里避免分配对象（新建 `Vector2(...)`、数组、拼接字符串）。
- 大量子弹 / 敌人用**对象池**，不要频繁 `instantiate` / `queue_free`（本项目子弹目前是直接实例化，
  数量大起来后要换池化）。

### 7.3 资源加载

- 固定路径的资源用 `preload()`（编译期加载，路径写错立即报错）。
- 只有运行期才知道路径的才用 `load()`（如按 id 从数据表查场景）。
- 频繁复用的场景 / 资源缓存到常量或成员变量，不要每次使用都 `load`。
- 节点引用一律用 `$` / `get_node()`，不要把路径字符串散落在逻辑里。

### 7.4 信号连接

```gdscript
func _ready() -> void:
	resumeButton.pressed.connect(onResumePressed)
	Game.scoreChanged.connect(onScoreChanged)
```

- 优先在代码里 `.connect()`（便于检索），或使用编辑器「节点 → 信号」面板连接。
- 回调命名统一 `onXxxYyy`（camelCase，不加 `_` 前缀）。
- ⚠️ 若在**编辑器**里连的信号，方法名写死在 `.tscn` 的 `[connection ... method=...]` 里，改名时必须一起改。

### 7.5 安全与健壮性

- 对象可能已被释放时，先用 `is_instance_valid(node)` 判断再访问。
- 节点 `free()` 之后读取它的成员**不会报错，但会静默变 `null`**；需要的数据必须在 `free()` **之前**取出（`Resource` 是引用计数，取出后仍有效）。
- `await` 之后要确认目标仍然有效，再继续操作。
- 释放节点用 `queue_free()`，不要直接 `free()`（除非确定当帧不再使用）。
- 需要下一帧再执行用 `call_deferred()`。
- 暂停：`get_tree().paused = true` 只对 `PROCESS_MODE_PAUSABLE` 生效；暂停菜单自身必须在场景里把
  `process_mode` 设为 `ALWAYS`，否则暂停后它也不再收输入（见 `pause_menu.tscn`）。

---

## 8. 提交前审查清单

- [ ] 命名：函数 / 变量 camelCase，常量 CONSTANT_CASE，类 / 枚举 PascalCase，信号过去式。
- [ ] 没有与 Godot 内置名（属性 / 方法 / 全局函数）重名。
- [ ] 成员变量 / 参数 / 返回值类型全部显式声明；无 `:=` 推断、无裸 `var`（局部变量可省略类型）。
- [ ] 私有成员不加 `_` 前缀；Godot 引擎回调保留 `_`。
- [ ] 脚本顺序：`@onready` → `_ready` → 自定义函数 → 其它内置虚函数放最后。
- [ ] 静态属性都在场景 Inspector 里设置，没有堆在代码里。
- [ ] 可复用逻辑已抽成「基础场景 + 基础脚本」，没有重复造轮子。
- [ ] Tab 缩进、行宽 ≤ 100、UTF-8 无 BOM、LF 换行。
- [ ] 文案走 `tr()`，并已加入 `lang/language.csv`（所有语言列都补齐）。
- [ ] 模块间用信号通信；信号在 `_ready` 中连接。
- [ ] 无 `get_node()` 出现在 `_process`；无用回调已 `set_process(false)`。
- [ ] 节点释放 / `await` 之后访问做了有效性判断。
- [ ] 输入只走 `InputManager` 封装；没有手拼 `pN_xxx` 动作名。
- [ ] 移动或改名文件后，所有引用（`preload` / `.tscn` / autoload / 数据表里的路径）已同步更新。
- [ ] `.tscn` / `.tres` 里**没有 `#` 注释**（Godot 文本资源不支持注释，会 Parse Error）。
- [ ] 跑一遍 `Godot --headless --path super_battle --quit-after 240`，控制台**无 ERROR / WARNING**。
