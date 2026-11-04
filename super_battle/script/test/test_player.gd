extends "res://script/level/base_level.gd"
## 玩家测试场（**手测场景**，不是 headless 探针）：不走房间流，直接摆几间现成房间当竞技场，
## 专门在编辑器里单跑玩家这一套 —— 移动 / 八向瞄准 / 开火 / 切枪 / 武器拾取与掉落 /
## 弹药包 / 受击闪白 / 阵亡与复活 / 命数与续关画面 / HUD 卡片 / 暂停菜单。
##
## 运行：编辑器打开本场景按 F6，或
## `godot --path super_battle res://scene/test/test_player.tscn`。
## 竞技场房间本身就带预置怪、可拆掩体与武器箱 / 弹药包，不必再造靶子。
##
## 继承 `base_level.gd`（见 code_design §6.2「基础场景 + 基础脚本」）只为了**复用它的摆人、
## 相机、边界、HUD、复活与续关逻辑**；本脚本只覆盖两件事：地图怎么来、什么时候别结算。
##
## 一句提醒：在这里按续关会真的往存档里累加 `continueCount`（命数与续关逻辑本来就是被测对象）；
## 但测试场的「推到尽头」不会记通关，不会污染战役进度。

## 当竞技场的房间，沿推进方向依次首尾相接。换靶子 / 换地形只改这个列表。
@export var arenaRoomPaths: Array[String] = [
	"res://scene/level/rooms/room_start.tscn",
	"res://scene/level/rooms/room_open.tscn",
	"res://scene/level/rooms/room_cover.tscn",
]

## 加入的玩家数（1~4）：一人练手感，四人测同屏与顶部卡片布局。
@export var testPlayerCount: int = 4

## 推进方向：在 Inspector 里直接切，验同一套玩家逻辑在纵向 / 横向上都对。
## （正式关卡的方向由 `StageData.levelInfo` 决定，测试场没有关卡数据可依。）
@export var testAxis: BattleCamera.ScrollAxis = BattleCamera.ScrollAxis.VERTICAL

## 竞技场沿推进方向的总长，由摆下的房间累加出来。
var arenaLength: float = 0.0


# ---- 自定义函数放前面 ----

## 测试场单独跑时没走选人流程，会话数据得自己种好，否则基类一个玩家都不会生成。
func seedTestSession() -> void:
	Game.resetSession()
	var characterTypes = Game.characterInfo.keys()
	for index in clampi(testPlayerCount, 1, Game.MAX_PLAYERS):
		Game.joinPlayer(index, characterTypes[index % characterTypes.size()])


## 覆盖房间流：把 [member arenaRoomPaths] 沿推进轴摆成一块固定竞技场，
## 相机区域就是这块地（所以人走不出去、相机也拍不到外面）。
func _setupRooms() -> void:
	scrollAxis = testAxis
	checkpointRooms = [0]
	arenaLength = 0.0
	var forward = BattleCamera.forwardVector(testAxis)
	var lateralSpan = battleCamera.getLateralSpan()
	battleCamera.scrollAxis = testAxis
	for roomPath in arenaRoomPaths:
		var room = load(roomPath).instantiate() as LevelRoom
		var roomLength = StageData.getRoomLength(room.roomId)
		var roomLateral = maxf(StageData.getRoomLateralLength(room.roomId), lateralSpan)
		room.alignTo(forward)
		add_child(room)
		room.global_position = forward * arenaLength
		room.setup(roomLength, roomLateral)
		# 测试场没有房间流来激活房间，预置怪直接开工当靶子。
		room.setActive(true)
		arenaLength += roomLength
	battleCamera.setup(arenaLength)
	battleCamera.setRegion(RoomStreamer.buildRect(0.0, arenaLength, lateralSpan * 0.5, forward))


## 测试场不该「推到尽头就结算」：玩家可以一直留在这里练枪。
func _checkClear() -> void:
	pass


## 暂停菜单的「重开」在测试场里应重开**本场景**，而不是跳去正式关卡。
func onRestartRequested() -> void:
	get_tree().paused = false
	SceneTransition.changeScene(scene_file_path)


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	seedTestSession()
	super()
