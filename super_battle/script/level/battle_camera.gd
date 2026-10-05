class_name BattleCamera
extends Camera2D
## 战斗相机：沿关卡前进方向**匀速推进**，绝不后退。
##
## **滚动方向由关卡决定**（[member scrollAxis]）：纵向 = 画面向上推进（经典竖版，敌人从上方涌入），
## 横向 = 画面向右推进。相机本身不跟随玩家 —— 关卡节奏是固定的（速度由 [member scrollSpeed] 决定），
## 玩家在屏幕范围内自由走位，走得快只会站到画面最前，不会被敌人甩掉，也不会缩短关卡时长。

enum ScrollAxis {
	VERTICAL,
	HORIZONTAL,
}

## 自动推进速度（像素 / 秒）。关卡节奏由它决定：屏幕匀速前进，玩家在屏内自由走位。
@export var scrollSpeed: float = 90.0

## 滚动方向，在关卡场景里设置。
@export var scrollAxis: ScrollAxis = ScrollAxis.VERTICAL

## 关卡前进方向（单位向量）。纵向滚动时为 [constant Vector2.UP]。
var forward: Vector2 = Vector2.UP

## 相机在前进方向上的起始 / 终止投影距离。
var startDistance: float = 0.0
var endDistance: float = 0.0

## 已推进的距离与总可推进距离。
var travelled: float = 0.0
var travelLength: float = 0.0


# ---- 自定义函数放前面 ----

## 取某个滚动方向对应的前进单位向量。
## 纵向 = 画面向上推进（经典竖版，敌人从上方涌入）；横向 = 画面向右推进。
func getForwardVector(axis: ScrollAxis) -> Vector2:
	return Vector2.UP if axis == ScrollAxis.VERTICAL else Vector2.RIGHT


## 垂直于前进方向（关卡横向）的单位向量。
func getLateralVector() -> Vector2:
	return forward.orthogonal()


## 按关卡长度初始化相机并归位到起点。
func setup(levelLength: float) -> void:
	forward = getForwardVector(scrollAxis)
	var viewSpan = getForwardSpan()
	startDistance = viewSpan * 0.5
	endDistance = maxf(levelLength - viewSpan * 0.5, startDistance)
	travelLength = endDistance - startDistance
	travelled = 0.0
	position = forward * startDistance


## 画面在前进方向上的尺寸（纵向滚动 = 视口高，横向滚动 = 视口宽）。
func getForwardSpan() -> float:
	var viewSize = get_viewport_rect().size
	return viewSize.y if scrollAxis == ScrollAxis.VERTICAL else viewSize.x


## 画面在横向的尺寸（垂直于前进方向）。
func getLateralSpan() -> float:
	var viewSize = get_viewport_rect().size
	return viewSize.x if scrollAxis == ScrollAxis.VERTICAL else viewSize.y


## 关卡推进进度（0 = 起点，1 = 终点）。
func getProgress() -> float:
	if travelLength <= 0.0:
		return 1.0
	return clampf(travelled / travelLength, 0.0, 1.0)


## 取当前可见的世界矩形，供限制玩家活动范围与计算刷怪点。
func getViewRect() -> Rect2:
	var viewSize = get_viewport_rect().size
	return Rect2(position - viewSize * 0.5, viewSize)


## 每帧匀速推进。相机**不跟随玩家**：玩家被限制在屏内走位，
## 因此「冲得快」只会让你站到画面最前，不会缩短关卡时长，也不会把敌人甩到身后。
func advance(delta: float) -> void:
	travelled = clampf(travelled + scrollSpeed * delta, 0.0, travelLength)
	position = forward * (startDistance + travelled)
