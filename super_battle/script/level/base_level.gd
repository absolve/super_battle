extends Node2D
## 战斗关卡基类：生成玩家、按房间流式推进地图、按滚动方向推进相机、判定通关 / 失败。
##
## **关卡不再是一整张地图**：地图被切成一串房间（见 [RoomStreamer]），玩家往前推就按需加载 /
## 卸载房间；掩体和敌人预置在各房间场景里，所以本脚本不再有刷怪参数。
##
## **支持纵向与横向两种推进方式**（[member scrollAxis]），关卡场景里切换即可，
## 其余逻辑（相机、玩家范围、房间排位）全部按「前进方向 / 横向」两个轴抽象，不写死 x 或 y。
##
## 新关卡用「继承场景」复用本场景 + 本脚本，通常只需改 [member levelNumber]、[member scrollAxis]
## 与 [member StageData.levelInfo] 里的房间清单；行为差异才覆盖方法。

## 通关时发出。
signal levelCleared

## 全员生命耗尽（等待续关）时发出。
signal levelFailed

const PLAYER_SCENE: PackedScene = preload("res://scene/player/player_character.tscn")
const PLAYER_HUD_SCENE: PackedScene = preload("res://scene/ui/player_hud.tscn")

## 打完 / 放弃一关都回**大地图**：进度标记在那里给玩家看到，比直接弹回标题更像战役。
const CAMPAIGN_MAP_PATH: String = "res://scene/ui/campaign_map.tscn"

## 检查点落在房间内推进方向多远处（像素）：不在门口原地复活，留出反应空间。
const CHECKPOINT_INROOM_ALONG: float = 220.0

## 关卡编号，对应 [member StageData.levelInfo] 的键。
@export var levelNumber: int = 1

## 滚动方向：纵向（画面上下推进）或横向（画面左右推进）。
@export var scrollAxis: BattleCamera.ScrollAxis = BattleCamera.ScrollAxis.VERTICAL

## 玩家出生点距画面**后方**边缘的距离。
@export var playerSpawnBackMargin: float = 180.0

## 玩家活动范围相对屏幕边缘的内缩量。
@export var viewMargin: float = 70.0

var isFinished: bool = false
var players: Array[PlayerCharacter] = []

## 检查点所在房间下标与它在推进轴上的投影；-1 表示还没记录过（回出生点）。
var checkpointRoomIndex: int = -1
var checkpointAlong: float = 0.0

## 本关的检查点房间下标（从数据表读）。
var checkpointRooms: Array[int] = []

## 每名玩家的槽位横向偏移；出生与检查点复活共用同一套车道，免得四个人叠在一点。
var laneOffsets: Array[float] = []

## 出生点在推进轴上的投影：还没记录到检查点时，复活就回这里。
var startAlong: float = 0.0

@onready var battleCamera: BattleCamera = $BattleCamera
@onready var roomStreamer: RoomStreamer = $RoomStreamer
@onready var playersRoot: Node2D = $Players
@onready var hudBar: HBoxContainer = $HudLayer/HudBar
@onready var resultLabel: Label = $HudLayer/ResultLabel
@onready var pauseMenu: Control = $HudLayer/PauseMenu
@onready var continueScreen: Control = $HudLayer/ContinueScreen


func _ready() -> void:
	levelNumber = StageData.currentLevel
	# 推进方向由关卡数据决定（同一个关卡场景既能做纵向关也能做横向关）。
	scrollAxis = StageData.getScrollAxis(levelNumber)
	resultLabel.hide()
	pauseMenu.hide()
	pauseMenu.restartRequested.connect(onRestartRequested)
	pauseMenu.quitRequested.connect(onQuitRequested)
	continueScreen.hide()
	continueScreen.continueRequested.connect(onContinueRequested)
	continueScreen.giveUpRequested.connect(onGiveUpRequested)
	roomStreamer.roomEntered.connect(onRoomEntered)
	_setupRooms()
	_spawnPlayers()
	_setupHud()


# ---- 自定义函数放前面 ----

## 关卡前进方向（单位向量）。
func getForward() -> Vector2:
	return battleCamera.forward


## 关卡横向（垂直于前进方向）的单位向量。
func getLateral() -> Vector2:
	return battleCamera.getLateralVector()


## 拾取物与掉落物的回收方向：与房间的卸载窗口同向，纵向 / 横向通用。
func getDespawnForward() -> Vector2:
	return getForward()


## 拾取物与掉落物的回收线：落在相机后方超过卸载距离就消失，
## 地上的枪不会越攒越多，也不用给它们单独做计时器。
func getDespawnLine() -> float:
	return battleCamera.position.dot(getForward()) - roomStreamer.unloadBehind


## 摆好房间链，再按房间总长初始化相机。
## 顺序不能换：相机需要 [member RoomStreamer.totalLength] 才能算出终点与进度。
func _setupRooms() -> void:
	checkpointRooms = StageData.getCheckpointRooms(levelNumber)
	battleCamera.scrollAxis = scrollAxis
	roomStreamer.setup(
		StageData.getRoomIds(levelNumber),
		BattleCamera.forwardVector(scrollAxis),
		battleCamera.getLateralSpan(),
	)
	battleCamera.setup(roomStreamer.totalLength)


func _spawnPlayers() -> void:
	var joinedCount = Game.joinedPlayers.size()
	if joinedCount == 0:
		return
	var forward = getForward()
	var lateralSpan = battleCamera.getLateralSpan()
	var laneWidth = lateralSpan / float(joinedCount)
	# 出生点放在画面**后方**（不是中央），这样跟随相机不会一开场就把玩家顶到画面最前。
	var viewRect = battleCamera.getViewRect()
	var alongA = viewRect.position.dot(forward)
	var alongB = viewRect.end.dot(forward)
	var spawnAlong = minf(alongA, alongB) + playerSpawnBackMargin
	# 关首固定一个检查点（复活点即出生位），较难的关再在中段房间里加。
	startAlong = spawnAlong
	if checkpointRooms.has(0):
		_setCheckpoint(0, spawnAlong)
	for order in joinedCount:
		var playerIndex = Game.joinedPlayers[order]
		var player = PLAYER_SCENE.instantiate()
		playersRoot.add_child(player)
		player.setup(playerIndex, Game.selectedCharacters[playerIndex])
		laneOffsets.append(laneWidth * (order + 0.5) - lateralSpan * 0.5)
		player.resetForSpawn(respawnPositionFor(order))
		players.append(player)


## 每名玩家一张信息卡，加进顶部的 `HudBar` 容器，宽度由容器均分。
func _setupHud() -> void:
	for player in players:
		var hud = PLAYER_HUD_SCENE.instantiate()

		hudBar.add_child(hud)
		hud.setup(player)


## 玩家进入某间房：配了检查点的房间就把全队的复活点挪进来。
func onRoomEntered(index: int, _roomId: String) -> void:
	if not checkpointRooms.has(index) or index == checkpointRoomIndex:
		return
	_setCheckpoint(index, roomStreamer.roomStarts[index] + CHECKPOINT_INROOM_ALONG)


## 记录检查点，并把每个人的复活点刷过去（正在等复活的也吃到，复活用的就是新位置）。
func _setCheckpoint(index: int, along: float) -> void:
	checkpointRoomIndex = index
	checkpointAlong = along
	for order in players.size():
		if is_instance_valid(players[order]):
			players[order].respawnPosition = respawnPositionFor(order)


## 某个槽位的复活位置：有检查点回检查点，否则回出生点；横向一律走自己的车道。
func respawnPositionFor(order: int) -> Vector2:
	var lateralOffset = laneOffsets[order] if order < laneOffsets.size() else 0.0
	var along = checkpointAlong if checkpointRoomIndex >= 0 else startAlong
	return getForward() * along + getLateral() * lateralOffset


## 全员命尽：不直接判负，而是弹「是否继续游戏？」（level_design §6）。
func openContinueScreen() -> void:
	if isFinished or continueScreen.visible:
		return
	continueScreen.open()
	get_tree().paused = true


## 续关：命数恢复、清空场上敌人、相机与所有人回到检查点。
## 续关次数只进存档供结算评级用，**不提高敌人强度**。
func onContinueRequested() -> void:
	get_tree().paused = false
	UserData.continueCount += 1
	UserData.saveData()
	for playerIndex in Game.joinedPlayers:
		Game.playerLives[playerIndex] = Game.PLAYER_LIVES_DEFAULT
	_clearEnemies()
	battleCamera.resetTo(checkpointAlong)
	# 先把房间窗口和区域拉回检查点，再摆人：玩家活动范围 = 视野 ∩ 已加载区域，
	# 若沿用死前的区域，检查点还在区域外，人会被夹到区域边缘而不是落在检查点。
	roomStreamer.stream(battleCamera.position.dot(getForward()))
	battleCamera.setRegion(roomStreamer.getLoadedRect())
	updatePlayerBounds()
	for order in players.size():
		if is_instance_valid(players[order]):
			players[order].resetForSpawn(respawnPositionFor(order))


func onGiveUpRequested() -> void:
	get_tree().paused = false
	finishLevel(false)


## 清场：重开这一段，敌人在房间里等着（房间没卸载的会保留当前状态）。
func _clearEnemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()


## 相机跟随：推进轴取最靠前的存活玩家（只进不退），横向取存活玩家的中心。
func followCamera() -> void:
	var forward = getForward()
	var lateralAxis = battleCamera.getLateralVector()
	var frontAlong = -INF
	var lateralSum = 0.0
	var aliveCount = 0
	for player in players:
		if not is_instance_valid(player) or not player.isAlive:
			continue
		frontAlong = maxf(frontAlong, player.global_position.dot(forward))
		lateralSum += player.global_position.dot(lateralAxis)
		aliveCount += 1
	# 全员阵亡（等复活）时横向不动，免得相机在没有参照点时乱飘。
	var lateralCenter = lateralSum / float(aliveCount) if aliveCount > 0 else battleCamera.position.dot(lateralAxis)
	battleCamera.advance(frontAlong, lateralCenter)


## 玩家活动范围 = 视野 ∩ 已加载房间区域，再按边距内缩；玩家走不出当前这批房间。
func updatePlayerBounds() -> void:
	var playRect = battleCamera.getPlayRect().grow(-viewMargin)
	for player in players:
		if is_instance_valid(player):
			player.bounds = playRect


## 通关：推到房间链终点，且已加载房间里不再有敌人。
func _checkClear() -> void:
	if battleCamera.getProgress() < 1.0:
		return
	if not get_tree().get_nodes_in_group("enemy").is_empty():
		return
	finishLevel(true)


func _checkDefeat() -> void:
	if Game.joinedPlayers.is_empty():
		return
	for playerIndex in Game.joinedPlayers:
		if Game.playerLives[playerIndex] > 0:
			return
	openContinueScreen()


func _checkPause() -> void:
	if InputManager.getAnyStartPressed() != -1:
		openPauseMenu()


## 结算：显示横幅 → 通关就**直接连到同区下一小关**（level_design §2「小关之间不回地图」），
## 区打完 / 下一关还没做出内容 / 失败，才回大地图给玩家看进度。
func finishLevel(success: bool) -> void:
	if isFinished:
		return
	isFinished = true
	if success:
		resultLabel.text = tr("_LevelCleared")
		resultLabel.show()
		UserData.completeLevel(levelNumber, 3)
		levelCleared.emit()
	else:
		resultLabel.text = tr("_GameOver")
		resultLabel.show()
		levelFailed.emit()
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return
	SceneTransition.changeScene(nextScenePath(success))


## 结算后该去哪：同区还有能打的小关就继续连打，否则回大地图。
func nextScenePath(success: bool) -> String:
	if not success:
		return CAMPAIGN_MAP_PATH
	var nextLevelCode = StageData.getNextLevelCode(levelNumber)
	if not StageData.isLevelPlayable(nextLevelCode):
		return CAMPAIGN_MAP_PATH
	StageData.currentLevel = nextLevelCode
	return StageData.getLevelScenePath(nextLevelCode)


## 打开暂停菜单并暂停场景树。
func openPauseMenu() -> void:
	if isFinished or pauseMenu.visible:
		return
	pauseMenu.open()


func onRestartRequested() -> void:
	get_tree().paused = false
	SceneTransition.changeScene(StageData.getLevelScenePath(levelNumber))


func onQuitRequested() -> void:
	get_tree().paused = false
	SceneTransition.changeScene("res://scene/ui/title.tscn")


# ---- Godot 内置虚函数放最后 ----

func _process(_delta: float) -> void:
	# 菜单 / 续关画面打开时整关停摆：关卡根节点的 process_mode 默认等同 ALWAYS，
	# 只有这里主动判断才挡得住（暂停类界面自身是 ALWAYS，见 pause_menu.tscn）。
	if isFinished or get_tree().paused:
		return
	# 三步顺序不能乱：相机先跟玩家 → 房间流按相机焦点加载 → 相机区域取已加载房间的并集。
	# 区域比焦点晚一步是本帧新加载的房间，下一帧就补上了，不会拍到空地。
	followCamera()
	roomStreamer.stream(battleCamera.position.dot(getForward()))
	battleCamera.setRegion(roomStreamer.getLoadedRect())
	updatePlayerBounds()
	_checkClear()
	_checkDefeat()
	_checkPause()
