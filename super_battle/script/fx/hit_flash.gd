class_name HitFlash
extends Node
## 命中闪烁：受击瞬间把目标染成高亮色，再在时长内淡回原色。
##
## 打击感里目前只做这一件事；顿帧、击退、震屏、粒子留给后续（dev_plan M3）。
## 玩家与敌人各挂一个本节点，用 [member targets] 指定要染色的节点：
##   - 敌人：染 [code]Body[/code] 的 [code]color[/code]（占位色块本身就是红的，染白看得出来）；
##   - 玩家：染根节点的 [code]modulate[/code] —— 玩家的槽位色就压在 modulate 上，
##     只改子件的 color 会被再乘一次，闪白完全看不出来。
##
## 基色每次 [method flash] 时**重新取**，不在 `_ready` 里缓存：
## 玩家的 modulate 会在 `setup()` 里被改成槽位色，缓存 _ready 的白会把颜色洗掉；
## 无敌闪烁改的是 modulate 的透明度，同理不该被覆盖成旧值。

## 要染色的节点路径（**相对本节点**）：本节点挂在单位根下，所以同级子节点要写
## [code]../Body[/code]，单位根本身写 [code]..[/code]。
@export var targets: Array[NodePath] = []

## 闪白时长（秒）。
@export var duration: float = 0.12

## 高亮色。
@export var flashColor: Color = Color(1, 1, 1, 1)

## 闪烁剩余时长（秒），0 表示没在闪。
var timeLeft: float = 0.0

## 染色目标节点。
var items: Array[CanvasItem] = []

## 与 items 一一对应：各目标用哪个颜色属性、以及本轮闪烁的基色。
var propertyNames: Array[StringName] = []
var baseColors: Array[Color] = []


# ---- 自定义函数放前面 ----

## 开始一次闪烁。正在闪时再调用就是重新计时，不做叠加。
func flash() -> void:
	if items.is_empty():
		return
	timeLeft = duration
	baseColors.clear()
	for index in items.size():
		var item = items[index]

		baseColors.append(item.get(propertyNames[index]))
		item.set(propertyNames[index], flashColor)


## 该节点该染哪个属性：Polygon2D / Sprite2D 有自己的 color，
## 角色根节点这类只有 modulate。
func colorPropertyOf(item: CanvasItem) -> StringName:
	return &"color" if "color" in item else &"modulate"


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	for targetPath in targets:
		var item = get_node_or_null(targetPath) as CanvasItem
		if item == null:
			push_warning("HitFlash: 找不到染色目标 %s" % targetPath)
			continue
		items.append(item)
		propertyNames.append(colorPropertyOf(item))


## 淡回原色放在物理帧里：与单位同一节拍推进，`--headless` 下也一定有步长
## （纯 `_process` 在无渲染的批量测试里不驱动，会把闪烁卡在最亮的一帧）。
func _physics_process(delta: float) -> void:
	if timeLeft <= 0.0:
		return
	timeLeft = maxf(timeLeft - delta, 0.0)
	var backRatio: float = 1.0 - timeLeft / maxf(duration, 0.001)

	for index in items.size():
		items[index].set(propertyNames[index], flashColor.lerp(baseColors[index], backRatio))
