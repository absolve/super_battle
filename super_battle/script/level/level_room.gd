class_name LevelRoom
extends Node2D
## 关卡房间基类：一段可以独立加载 / 卸载的地图内容。
##
## 坐标约定（在编辑器里照这个搭房间）：
##   - 根节点原点 = 玩家进入本房间的**入口边**中心；
##   - 内容沿推进方向铺开，长度写在 [member StageData.roomInfo] 里，场景内不重复声明；
##   - [member scrollAxis] 只记录本房间是**按哪个轴搭的**：纵向房间内容朝 local 上方铺，
##     横向房间朝 local 右方铺。关卡用另一个轴时由 [method alignTo] 整间转过去，
##     所以一批房间可以纵向横向通用，不必搭两套。
##
## 美术未到位前，地面与本房间边界由 [method _draw] 画占位色块；掩体用 obstacle 层的
## StaticBody2D，敌人直接摆在场景里（预置怪随房间一起加载，不需要刷怪参数）。
##
## 刚加载时房间是**休眠**的：预置敌人不跑 AI，等玩家进到本房间才激活，
## 否则前方房间的怪会提前扑过来。
##
## 休眠用的是 `process_mode`（状态机是敌人的子节点，只关本体关不掉它）。
## 副作用要记一句：**被冻住的敌人物理体不参与 Area2D 重叠检测，子弹会直接穿过它们** ——
## 前方还没交战的房间本来就不该被打到，所以是可接受行为；
## 但别指望用子弹去试探休眠敌人，探针里要「钉住」敌人请改用 `moveSpeed = 0`。

## 房间 id，用于调试打点（与 [member StageData.roomInfo] 的键一致）。
@export var roomId: String = ""

## 本房间的滚动轴，决定地面往哪边铺。
@export var scrollAxis: BattleCamera.ScrollAxis = BattleCamera.ScrollAxis.VERTICAL

## 占位地面颜色（美术到位后由 TileMap 取代）。
@export var groundColor: Color = Color(0.09, 0.11, 0.15)

## 入口色带颜色：让玩家看得出「跨过了一道房间门」。
@export var entryBandColor: Color = Color(1.0, 1.0, 1.0, 0.06)

## 占位网格线颜色。
@export var gridColor: Color = Color(1.0, 1.0, 1.0, 0.05)

## 沿推进方向的长度（像素），由 [RoomStreamer] 在实例化后写入。
var alongLength: float = 1080.0

## 横向可用宽度（像素），即相机视野的横向尺寸，由 [RoomStreamer] 写入。
var lateralSpan: float = 1920.0

## 房间是否处于激活状态（预置敌人在跑 AI）。
## 初值必须是 true：刚实例化的节点本来就在处理，
## 写成 false 会让 [method setActive] 的幂等判断直接短路，休眠形同虚设。
var isActive: bool = true

## 本房间预置的敌人，休眠 / 激活由这些节点统一控制。
var enemies: Array[Enemy] = []


# ---- 自定义函数放前面 ----

## 由 [RoomStreamer] 在 add_child 之后调用：写入尺寸、收编预置敌人并休眠。
func setup(newAlongLength: float, newLateralSpan: float) -> void:
	alongLength = newAlongLength
	lateralSpan = newLateralSpan
	collectEnemies()
	setActive(false)
	queue_redraw()


## 激活 / 休眠本房间的敌人。
## 被玩家打死的预置怪会从数组里顺手摘掉：它们随 enemy.die() 释放，留着就是悬空引用。
## 开关用 process_mode 而不是 set_physics_process：敌人的行为已经搬进它自己的
## StateMachine 子节点，只关本体不会关掉子节点的 tick；process_mode 会被整棵子树继承。
func setActive(active: bool) -> void:
	if isActive == active:
		return
	isActive = active
	for index in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[index]
		if not is_instance_valid(enemy):
			enemies.remove_at(index)
			continue
		enemy.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


## 沿推进方向的前进单位向量。
func getForwardVector() -> Vector2:
	return BattleCamera.forwardVector(scrollAxis)


## 把整间房对齐到关卡的推进方向。
## 房间是按 [member scrollAxis] 手搭的，关卡是另一个轴时不用重搭：
## 绕入口原点（局部原点）转过去即可，地面、掩体碰撞形状、预置怪位置一起跟着转。
func alignTo(axisForward: Vector2) -> void:
	rotation = getForwardVector().angle_to(axisForward)


## 收集场景里预置的敌人（含嵌套节点），供 [method setActive] 批量开关。
func collectEnemies() -> void:
	enemies.clear()
	for node in find_children("*", "Enemy", true, false):
		var enemy = node as Enemy
		if enemy != null:
			enemies.append(enemy)


## 本房间的四个角（局部坐标，原点在入口边中心）。
func getCorners() -> PackedVector2Array:
	var forward = getForwardVector()
	var lateral = forward.orthogonal()
	var halfSpan = lateralSpan * 0.5
	return PackedVector2Array([
		lateral * -halfSpan,
		lateral * halfSpan,
		lateral * halfSpan + forward * alongLength,
		lateral * -halfSpan + forward * alongLength,
	])


# ---- Godot 内置虚函数放最后 ----

func _draw() -> void:
	# 地面 + 入口色带 + 网格：美术缺席时也要看得出房间的分界和推进方向。
	var forward = getForwardVector()
	var lateral = forward.orthogonal()
	var halfSpan = lateralSpan * 0.5
	var corners = getCorners()
	draw_colored_polygon(corners, groundColor)

	var bandDepth = minf(48.0, alongLength * 0.2)
	draw_colored_polygon(
		PackedVector2Array([
			lateral * -halfSpan,
			lateral * halfSpan,
			lateral * halfSpan + forward * bandDepth,
			lateral * -halfSpan + forward * bandDepth,
		]),
		entryBandColor,
	)
	var along = 128.0
	while along < alongLength:
		draw_line(
			forward * along + lateral * -halfSpan,
			forward * along + lateral * halfSpan,
			gridColor,
			2.0,
		)
		along += 128.0
	# 房间外框：占位阶段的「墙」，让掩体和边界一眼分得开。
	for index in corners.size():
		draw_line(corners[index], corners[(index + 1) % corners.size()], Color(1.0, 1.0, 1.0, 0.08), 3.0)
