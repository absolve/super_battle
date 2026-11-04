class_name RoomStreamer
extends Node2D
## 房间流式加载器：把关卡拆成的一串房间按需加载 / 卸载。
##
## 房间沿推进方向首尾相接，本脚本按 [member StageData.roomInfo] 里的长度算出每个房间入口
## 在推进轴上的投影，然后只维护一个**加载窗口**：
##   - 焦点前方 [member loadAhead] 以内的房间实例化；
##   - 焦点后方超出 [member unloadBehind] 的房间整棵释放（预置怪随之消失）；
##   - 再往前 [member preloadCount] 间用线程预载场景资源，避免进房间那一刻卡帧。
##
## 窗口之外既不实例化也不占内存，所以关卡地图可以做得很长，而不是「一下子加载整张图」。
## 只有玩家当前所在（以及刚离开、还在视野里的那间）房间的预置敌人在跑 AI。

## 玩家进入某个房间时发出；关卡可据此挂检查点、音效或事件。
signal roomEntered(index: int, roomId: String)

## 前方多远就实例化（像素）。要大于半个视野，保证房间在进画之前就位。
@export var loadAhead: float = 1600.0

## 后方多远就卸载（像素）。
@export var unloadBehind: float = 900.0

## 实例化窗口之外再预载几间房的场景资源。
@export var preloadCount: int = 3

## 房间 id 清单（按推进顺序），由 [method setup] 从关卡表读入。
var roomIds: Array[String] = []

## 下标 -> 房间入口在推进轴上的投影距离。
var roomStarts: Array[float] = []

## 下标 -> 房间沿推进轴的长度。
var roomLengths: Array[float] = []

## 下标 -> 房间横向可用宽度（数据表没配的按相机视野宽铺满）。
var roomLateralSpans: Array[float] = []

## 房间链总长，即关卡长度。
var totalLength: float = 0.0

## 推进方向（由关卡的滚动轴决定）。
var forward: Vector2 = Vector2.UP

## 相机视野的横向尺寸，作为「房间没声明宽度」时的铺满值。
var lateralSpan: float = 1920.0

## 已加载房间在推进轴上的并集区间（相机与玩家的可活动范围据此夹取）。
var loadedAlongMin: float = 0.0
var loadedAlongMax: float = 0.0

## 已加载房间里最宽那间的半宽（横向并集半径）。
var loadedLateralHalf: float = 960.0

## 焦点（相机中心）在推进轴上的投影。
var focusAlong: float = 0.0

## 玩家当前所在房间的下标。
var activeIndex: int = -1

## 已经广播过 roomEntered 的下标，防止重复触发。
var enteredIndex: int = -1

## 下标 -> 已实例化的房间。
var loadedRooms: Dictionary[int, LevelRoom] = {}

## 场景路径 -> 已加载好的场景资源（重复房间共用一份）。
var sceneCache: Dictionary[String, PackedScene] = {}

## 正在线程加载的场景路径。
var pendingPaths: Dictionary[String, bool] = {}

## 线程加载失败的路径：不再重复请求，实例化时同步兜底一次。
var failedPaths: Dictionary[String, bool] = {}


# ---- 自定义函数放前面 ----

## 用房间清单建链，算出总长与各房间起点。实例化交给后续的 [method stream]。
func setup(roomIdList: Array[String], scrollForward: Vector2, scrollLateralSpan: float) -> void:
	roomIds = roomIdList
	forward = scrollForward
	lateralSpan = scrollLateralSpan
	roomStarts.clear()
	roomLengths.clear()
	roomLateralSpans.clear()
	totalLength = 0.0
	activeIndex = -1
	enteredIndex = -1
	for index in roomIds.size():
		roomStarts.append(totalLength)
		var length = StageData.getRoomLength(roomIds[index])
		var wantedWidth = StageData.getRoomLateralLength(roomIds[index])

		roomLengths.append(length)
		roomLateralSpans.append(wantedWidth if wantedWidth > 0.0 else lateralSpan)
		totalLength += length
	# 开局就落在加载窗口里的房间直接同步取资源：线程加载最快也要几帧才回货，
	# 否则玩家出生第一眼看到的是空地图。
	for index in roomIds.size():
		if roomStarts[index] > loadAhead:
			break
		loadAndCache(StageData.getRoomScenePath(roomIds[index]))
	refreshLoadedExtent()


## 每帧推进流式窗口；[param focus] 是相机中心在推进轴上的投影。
func stream(focus: float) -> void:
	focusAlong = focus
	pollPreloads()
	syncActiveIndex()
	updateWindow()
	refreshLoadedExtent()
	syncActivation()
	broadcastEntered()


## 重算已加载房间的并集：推进轴取首尾，横向取最宽那间。
## 一间都没加载时退回第 0 间的范围，免得相机被零面积区域夹住。
func refreshLoadedExtent() -> void:
	if loadedRooms.is_empty():
		loadedAlongMin = 0.0
		loadedAlongMax = roomLengths[0] if not roomLengths.is_empty() else 0.0
		loadedLateralHalf = roomLateralSpans[0] * 0.5 if not roomLateralSpans.is_empty() else lateralSpan * 0.5
		return
	loadedAlongMin = INF
	loadedAlongMax = -INF
	loadedLateralHalf = 0.0
	for index in loadedRooms.keys():
		loadedAlongMin = minf(loadedAlongMin, roomStarts[index])
		loadedAlongMax = maxf(loadedAlongMax, roomStarts[index] + roomLengths[index])
		loadedLateralHalf = maxf(loadedLateralHalf, roomLateralSpans[index] * 0.5)


## 已加载房间的并集（世界坐标下的轴对齐矩形）。
func getLoadedRect() -> Rect2:
	return buildRect(loadedAlongMin, loadedAlongMax, loadedLateralHalf, forward)


## 用「推进轴区间 + 横向半宽」拼世界矩形（推进轴恒为 ±X / ±Y，所以四个角直接对成 AABB）。
static func buildRect(alongMin: float, alongMax: float, lateralHalf: float, axisForward: Vector2) -> Rect2:
	var lateral = axisForward.orthogonal()
	var cornerA = axisForward * alongMin + lateral * -lateralHalf
	var cornerB = axisForward * alongMax + lateral * lateralHalf
	var origin = Vector2(minf(cornerA.x, cornerB.x), minf(cornerA.y, cornerB.y))
	var extent = Vector2(absf(cornerB.x - cornerA.x), absf(cornerB.y - cornerA.y))
	return Rect2(origin, extent)


## 焦点落在哪个房间。焦点在链外时返回最近的一端（起点前 = 0，终点后 = 最后一间）。
func indexAtDistance(distance: float) -> int:
	for index in roomStarts.size():
		if distance < roomStarts[index] + roomLengths[index]:
			return index
	return maxi(roomStarts.size() - 1, 0)


## 把路径投给线程加载，并收取已就绪的结果。
func pollPreloads() -> void:
	for path in pendingPaths.keys():
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			var scene = ResourceLoader.load_threaded_get(path) as PackedScene
			if scene != null:
				sceneCache[path] = scene
			pendingPaths.erase(path)
		elif status != ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
			# FAILED / INVALID：不再重复请求，实例化时由 takeScene 同步兜底一次。
			failedPaths[path] = true
			pendingPaths.erase(path)

	var frontIndex = indexAtDistance(focusAlong + loadAhead)
	var startIndex = indexAtDistance(focusAlong)
	var untilIndex = mini(frontIndex + preloadCount, roomIds.size() - 1)
	for index in range(startIndex, untilIndex + 1):
		requestPreload(index)


## 为单个房间发线程加载请求；已缓存 / 已在路上 / 已失败的跳过。
func requestPreload(index: int) -> void:
	var path = StageData.getRoomScenePath(roomIds[index])
	if path == "" or sceneCache.has(path) or pendingPaths.has(path) or failedPaths.has(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		pendingPaths[path] = true


## 同步取某条路径的场景资源并进缓存；失败返回 null。
func loadAndCache(path: String) -> PackedScene:
	if path == "" or sceneCache.has(path):
		return sceneCache.get(path)
	var scene = load(path) as PackedScene
	if scene != null:
		sceneCache[path] = scene
	return scene


## 取某间房的场景资源；还在线程路上时返回 null（下一帧再试，不阻塞主线程）。
func takeScene(index: int) -> PackedScene:
	var path = StageData.getRoomScenePath(roomIds[index])
	if path == "":
		push_warning("RoomStreamer: 房间 id '%s' 没有对应场景" % roomIds[index])
		return null
	if pendingPaths.has(path):
		return null
	# 玩家推进太快、预载没跟上：这里同步加载一次。
	return loadAndCache(path)


## 实例化一间房：对齐关卡的推进轴、摆到入口位置，尺寸交给房间自己画地面。
func instantiateRoom(index: int) -> void:
	var scene = takeScene(index)
	if scene == null:
		return
	var room = scene.instantiate() as LevelRoom
	if room == null:
		push_warning("RoomStreamer: 房间场景 '%s' 的根节点不是 LevelRoom" % roomIds[index])
		return
	# 先转后摆：房间是纵向搭的也能用在横向关里，省一套横向素材。
	room.alignTo(forward)
	add_child(room)
	room.global_position = forward * roomStarts[index]
	room.setup(roomLengths[index], roomLateralSpans[index])
	loadedRooms[index] = room


## 卸载一间房：整棵释放，预置敌人 / 掩体随之消失。
func unloadRoom(index: int) -> void:
	var room = loadedRooms[index]

	loadedRooms.erase(index)
	room.queue_free()


## 算出当前所在房间；玩家跨过房门时由 [method broadcastEntered] 广播。
func syncActiveIndex() -> void:
	activeIndex = indexAtDistance(focusAlong)


## 维护加载窗口：前方该出现的实例化，后方太远的释放。
func updateWindow() -> void:
	var frontEdge = focusAlong + loadAhead
	var rearEdge = focusAlong - unloadBehind
	for index in roomIds.size():
		var roomEnd = roomStarts[index] + roomLengths[index]
		var shouldLoad = roomStarts[index] <= frontEdge and roomEnd >= rearEdge
		if shouldLoad and not loadedRooms.has(index):
			instantiateRoom(index)
		elif not shouldLoad and loadedRooms.has(index):
			unloadRoom(index)


## 只有当前房间和刚离开的那间（还在视野里）激活，其余房间的预置怪保持休眠。
func syncActivation() -> void:
	for index in loadedRooms.keys():
		loadedRooms[index].setActive(index == activeIndex or index == activeIndex - 1)


## 进入新房间时广播一次。
func broadcastEntered() -> void:
	if activeIndex == enteredIndex or not loadedRooms.has(activeIndex):
		return
	enteredIndex = activeIndex
	roomEntered.emit(activeIndex, roomIds[activeIndex])
