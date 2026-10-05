class_name BattleCamera
extends Camera2D
## 战斗相机：**跟着玩家走** —— 玩家往前推进，相机才前进；玩家停下，相机也停下。
##
## **滚动方向由关卡决定**（[member scrollAxis]）：纵向 = 画面向上推进（经典竖版，敌人从上方涌入），
## 横向 = 画面向右推进。相机永远不后退（[member travelled] 只增不减）。

enum ScrollAxis {
	VERTICAL,
	HORIZONTAL,
}

## 相机中心停在玩家**前方**（前进方向）的比例 × 画面长度。
## 0.3 = 相机中心在玩家前方 30% 画面长度处，于是玩家位于画面**后方约 20%** 处、前方留出 80% 视野。
@export var leadRatio: float = 0.3

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


## 跟随最靠前的玩家推进（相机只前进不后退）。
## [param frontAlong] 为最靠前**存活**玩家在前进方向上的投影；没有存活玩家时传 -INF，相机保持不动。
## 相机中心停在玩家前方 [code]getForwardSpan() * leadRatio[/code] 处，
## 于是玩家位于画面后方约 20% 处、前方留出大部分视野。
func advance(_delta: float, frontAlong: float) -> void:
	if frontAlong > -INF:
		var lead = getForwardSpan() * leadRatio
		travelled = clampf(maxf(travelled, frontAlong + lead - startDistance), 0.0, travelLength)
	position = forward * (startDistance + travelled)
