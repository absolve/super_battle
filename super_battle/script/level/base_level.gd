extends Node2D
## 战斗关卡基类：生成玩家、刷怪、按滚动方向推进相机、判定通关 / 失败。
##
## **支持纵向与横向两种推进方式**（[member scrollAxis]），关卡场景里切换即可，
## 其余逻辑（刷怪、玩家范围、回收）全部按「前进方向 / 横向」两个轴抽象，不写死 x 或 y。
##
## 新关卡用「继承场景」复用本场景 + 本脚本，通常只需改 [member levelNumber]、[member scrollAxis]
## 与 [member StageData.levelInfo] 里的数据；行为差异才覆盖方法。

## 通关时发出。
signal levelCleared

## 全员生命耗尽（等待续关）时发出。
signal levelFailed

const PLAYER_SCENE: PackedScene = preload("res://scene/player/player_character.tscn")
const PLAYER_HUD_SCENE: PackedScene = preload("res://scene/ui/player_hud.tscn")

## 关卡编号，对应 [member StageData.levelInfo] 的键。
@export var levelNumber: int = 1

## 滚动方向：纵向（画面上下推进）或横向（画面左右推进）。
@export var scrollAxis: BattleCamera.ScrollAxis = BattleCamera.ScrollAxis.VERTICAL

## 刷怪间隔倍率，越小越密（供高难度关卡覆盖）。
@export var spawnIntervalMultiplier: float = 1.0

## 玩家出生点距画面**后方**边缘的距离。
@export var playerSpawnBackMargin: float = 180.0

## 玩家活动范围相对屏幕边缘的内缩量。
@export var viewMargin: float = 70.0

## 敌人出生点在相机前方之外的额外距离。
@export var spawnAheadMargin: float = 140.0

var levelLength: float = 6000.0
var spawnInterval: float = 1.1
var enemyTotal: int = 40
var enemyPool: Array = []
var spawnedCount: int = 0
var spawnCooldown: float = 0.0
var isFinished: bool = false
var players: Array[PlayerCharacter] = []

@onready var battleCamera: BattleCamera = $BattleCamera
@onready var playersRoot: Node2D = $Players
@onready var enemiesRoot: Node2D = $Enemies
@onready var hudLayer: CanvasLayer = $HudLayer
@onready var resultLabel: Label = $HudLayer/ResultLabel
@onready var pauseMenu: Control = $HudLayer/PauseMenu


func _ready() -> void:
	levelNumber = StageData.currentLevel
	_applyStageData()
	resultLabel.hide()
	pauseMenu.hide()
	pauseMenu.restartRequested.connect(onRestartRequested)
	pauseMenu.quitRequested.connect(onQuitRequested)
	_setupCamera()
	_spawnPlayers()
	_setupHud()
	queue_redraw()


# ---- 自定义函数放前面 ----

## 关卡前进方向（单位向量）。
func getForward() -> Vector2:
	return battleCamera.forward


## 关卡横向（垂直于前进方向）的单位向量。
func getLateral() -> Vector2:
	return battleCamera.getLateralVector()


## 从数据表读取本关的刷怪参数。
func _applyStageData() -> void:
	var config = StageData.getSpawnConfig(levelNumber)
	levelLength = config["length"]
	enemyPool = config["enemyPool"]
	enemyTotal = config["enemyTotal"]
	spawnInterval = config["spawnInterval"] * spawnIntervalMultiplier


func _setupCamera() -> void:
	battleCamera.scrollAxis = scrollAxis
	battleCamera.setup(levelLength)


func _spawnPlayers() -> void:
	var joinedCount = Game.joinedPlayers.size()
	if joinedCount == 0:
		return
	var forward = getForward()
	var lateral = getLateral()
	var lateralSpan = battleCamera.getLateralSpan()
	var laneWidth = lateralSpan / float(joinedCount)
	# 出生点放在画面**后方**（不是中央），这样跟随相机不会一开场就把玩家顶到画面最前。
	var viewRect = battleCamera.getViewRect()
	var alongA = viewRect.position.dot(forward)
	var alongB = viewRect.end.dot(forward)
	var spawnAlong = minf(alongA, alongB) + playerSpawnBackMargin
	for order in joinedCount:
		var playerIndex = Game.joinedPlayers[order]
		var player = PLAYER_SCENE.instantiate()
		playersRoot.add_child(player)
		player.setup(playerIndex, Game.selectedCharacters[playerIndex])
		var lateralOffset = laneWidth * (order + 0.5) - lateralSpan * 0.5
		player.resetForSpawn(forward * spawnAlong + lateral * lateralOffset)
		players.append(player)


func _setupHud() -> void:
	var screenSize = get_viewport_rect().size
	for order in players.size():
		var hud = PLAYER_HUD_SCENE.instantiate()
		hudLayer.add_child(hud)
		hud.setup(players[order])
		hud.position = _getHudPosition(order, screenSize)


func _getHudPosition(order: int, screenSize: Vector2) -> Vector2:
	var hudSize = Vector2(300.0, 108.0)
	var margin = 20.0
	var columns = 2
	var isRightSide = order % columns == 1
	var isBottomSide = order >= columns
	var x = screenSize.x - hudSize.x - margin if isRightSide else margin
	var y = screenSize.y - hudSize.y - margin if isBottomSide else margin
	return Vector2(x, y)


func _updateCameraAndBounds(delta: float) -> void:
	var forward = getForward()
	var frontAlong = -INF
	for player in players:
		if is_instance_valid(player) and player.isAlive:
			frontAlong = maxf(frontAlong, player.global_position.dot(forward))
	battleCamera.advance(delta, frontAlong)
	var viewRect = battleCamera.getViewRect().grow(-viewMargin)
	for player in players:
		if is_instance_valid(player):
			player.bounds = viewRect


func _updateSpawning(delta: float) -> void:
	if spawnedCount >= enemyTotal:
		return
	if battleCamera.getProgress() >= 0.92:
		return
	spawnCooldown -= delta
	if spawnCooldown > 0.0:
		return
	spawnCooldown = spawnInterval
	_spawnEnemy()


func _spawnEnemy() -> void:
	var enemyId: String = enemyPool[randi() % enemyPool.size()]
	var scenePath = StageData.getEnemyScenePath(enemyId)
	if scenePath == "":
		return
	var enemyScene: PackedScene = load(scenePath)
	var enemy = enemyScene.instantiate()
	var forward = getForward()
	var lateral = getLateral()
	var viewRect = battleCamera.getViewRect()
	# 前进方向两侧的边界：不写死 x/y，纵向（向上）与横向（向右）都适用。
	var alongA = viewRect.position.dot(forward)
	var alongB = viewRect.end.dot(forward)
	var aheadAlong = maxf(alongA, alongB)
	var behindAlong = minf(alongA, alongB)
	var lateralMin = viewRect.position.dot(lateral) + 100.0
	var lateralMax = viewRect.end.dot(lateral) - 100.0
	var lateralPosition = randf_range(minf(lateralMin, lateralMax), maxf(lateralMin, lateralMax))
	enemiesRoot.add_child(enemy)
	enemy.global_position = forward * (aheadAlong + spawnAheadMargin) + lateral * lateralPosition
	enemy.despawnForward = forward
	enemy.despawnLine = behindAlong - 700.0
	spawnedCount += 1


func _checkClear() -> void:
	if battleCamera.getProgress() < 1.0:
		return
	if spawnedCount < enemyTotal:
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
	finishLevel(false)


func _checkPause() -> void:
	if InputManager.getAnyStartPressed() != -1:
		openPauseMenu()


## 结算关卡：显示横幅、推进解锁、返回标题。
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
	SceneTransition.changeScene("res://scene/ui/title.tscn")


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

func _process(delta: float) -> void:
	if isFinished:
		return
	_updateCameraAndBounds(delta)
	_updateSpawning(delta)
	_checkClear()
	_checkDefeat()
	_checkPause()


func _draw() -> void:
	# 关卡地面：深色底 + 网格；网格随滚动方向变化，让推进有参照物。
	var forward = getForward()
	var lateral = getLateral()
	var lateralHalf = battleCamera.getLateralSpan() * 0.5 + 260.0
	var backMargin = 600.0
	var frontMargin = 1000.0
	var corners = PackedVector2Array([
		forward * -backMargin + lateral * -lateralHalf,
		forward * -backMargin + lateral * lateralHalf,
		forward * (levelLength + frontMargin) + lateral * lateralHalf,
		forward * (levelLength + frontMargin) + lateral * -lateralHalf,
	])
	draw_colored_polygon(corners, Color(0.1, 0.12, 0.16))
	var gridColor = Color(1.0, 1.0, 1.0, 0.05)
	var along = -512.0
	while along <= levelLength + 512.0:
		draw_line(
			forward * along + lateral * -lateralHalf,
			forward * along + lateral * lateralHalf,
			gridColor,
			2.0,
		)
		along += 128.0
	var lateralPosition = -lateralHalf
	while lateralPosition <= lateralHalf:
		draw_line(
			forward * -backMargin + lateral * lateralPosition,
			forward * (levelLength + frontMargin) + lateral * lateralPosition,
			gridColor,
			2.0,
		)
		lateralPosition += 128.0
