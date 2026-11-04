class_name BattleCamera
extends Camera2D
## 战斗相机：**跟着玩家走** —— 玩家往前推进，相机才前进；玩家停下，相机也停下。
##
## **滚动方向由关卡决定**（[member scrollAxis]）：纵向 = 画面向上推进（经典竖版，敌人从上方涌入），
## 横向 = 画面向右推进。推进轴永远不后退（[member travelled] 只增不减），横向可以来回跟玩家。
##
## 相机被夹在 [member region] 里（关卡按**已加载房间的并集**每帧写入），所以拍不到还没加载出来的
## 空地。某个轴上的区域比视野短时会退化成**居中**（例如窄巷道房间），两侧对称露出区域外，
## 比单侧卡死更好看。玩家活动范围取 [method getPlayRect]（视野 ∩ 区域），人也走不出房间。

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

## 相机可用区域（世界坐标、轴对齐），由关卡用 [method setRegion] 按已加载房间写入。
var region: Rect2 = Rect2()


# ---- 自定义函数放前面 ----

## 取某个滚动方向对应的前进单位向量（[LevelRoom] 铺地面时也要用，故为静态方法）。
## 纵向 = 画面向上推进（经典竖版，敌人从上方涌入）；横向 = 画面向右推进。
static func forwardVector(axis: ScrollAxis) -> Vector2:
	return Vector2.UP if axis == ScrollAxis.VERTICAL else Vector2.RIGHT


## 垂直于前进方向（关卡横向）的单位向量。
func getLateralVector() -> Vector2:
	return forward.orthogonal()


## 按关卡长度初始化相机并归位到起点。
func setup(levelLength: float) -> void:
	forward = forwardVector(scrollAxis)
	var viewSpan = getForwardSpan()
	startDistance = viewSpan * 0.5
	endDistance = maxf(levelLength - viewSpan * 0.5, startDistance)
	travelLength = endDistance - startDistance
	travelled = 0.0
	position = forward * startDistance
	# 关卡还没上报房间区域前，先按当前视野当区域，等于不夹。
	region = getViewRect()


## 设置相机可用区域（世界矩形）。关卡每帧在房间流之后调用。
func setRegion(worldRegion: Rect2) -> void:
	if worldRegion.size.x <= 0.0 or worldRegion.size.y <= 0.0:
		return
	region = worldRegion


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


## 取当前可见的世界矩形。
func getViewRect() -> Rect2:
	var viewSize = get_viewport_rect().size
	return Rect2(position - viewSize * 0.5, viewSize)


## 玩家实际可活动的世界矩形：视野与可用区域的交集（关卡再按边距内缩）。
## 区域尚未设置（面积为 0）时退回视野，免得把玩家夹死在原地。
func getPlayRect() -> Rect2:
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return getViewRect()
	return getViewRect().intersection(region)


## 可用区域在推进轴上的区间（起点投影, 终点投影）。
func getRegionAlongRange() -> Vector2:
	var a = region.position.dot(forward)
	var b = region.end.dot(forward)
	return Vector2(minf(a, b), maxf(a, b))


## 可用区域在横向上的半宽（房间以横向 0 为中心对称摆放）。
func getRegionLateralHalf() -> float:
	var a = region.position.dot(getLateralVector())
	var b = region.end.dot(getLateralVector())
	return maxf(absf(a), absf(b))


## 把中心投影夹进区域，要求整段视野都不越出区域。
## 区域比视野短时退化为居中：两侧对称露出区域外，比单侧卡死好看得多。
func clampCenter(desired: float, regionMin: float, regionMax: float, viewSpan: float) -> float:
	if regionMax - regionMin <= viewSpan:
		return (regionMin + regionMax) * 0.5
	return clampf(desired, regionMin + viewSpan * 0.5, regionMax - viewSpan * 0.5)


## 续关重开：把相机放回检查点。
## 战斗中相机绝不后退，但「重打这一段」是例外，不然玩家会被留在离检查点很远的地方。
func resetTo(along: float) -> void:
	travelled = clampf(along - startDistance, 0.0, travelLength)
	position = forward * (startDistance + travelled)


## 跟随玩家：推进轴只进不退并提前 [member leadRatio]，横向软跟随；两个轴都夹在 [member region] 内。
## [param frontAlong] 为最靠前**存活**玩家在推进轴上的投影（没有存活玩家时传 -INF，相机保持不动）；
## [param lateralCenter] 为存活玩家在横向上的中心投影。
func advance(frontAlong: float, lateralCenter: float) -> void:
	if frontAlong > -INF:
		var lead = getForwardSpan() * leadRatio
		travelled = clampf(maxf(travelled, frontAlong + lead - startDistance), 0.0, travelLength)
	var alongRange = getRegionAlongRange()
	var alongCenter = clampCenter(
		startDistance + travelled,
		alongRange.x,
		alongRange.y,
		getForwardSpan(),
	)
	var lateralHalf = getLateralSpan() * 0.5
	var lateralOffset = clampCenter(lateralCenter, -getRegionLateralHalf(), getRegionLateralHalf(), getLateralSpan())
	position = forward * alongCenter + getLateralVector() * lateralOffset
