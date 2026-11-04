extends Control
## 大地图（战役进度界面）：六区连线 + 当前区的小关进度，让玩家一眼看到「打到哪了」。
##
## **顺序固定，不给选路**（level_design §1.2）：地图只负责**显示进度**与**出击当前目标**，
## 玩家不能点别的区。区状态由存档推导（[method UserData.getCurrentDistrictCode] 及其上游），
## 本脚本不存任何进度状态。
##
## 美术先占位：区是色块 + 文字，连线是 [Line2D]，颜色语义照 art_style 的语义色。
## 操作：任一玩家的开火键 = 出击，必杀键 = 回标题。

## 出击 / 回标题用的按键走全局「任一键」查询，四人任一按都算（与选人界面一致）。
const TITLE_PATH: String = "res://scene/ui/title.tscn"

## 已控制（绿）/ 当前（黄）/ 未解锁（灰）—— 占位阶段用色块颜色表达状态。
const DISTRICT_CLEARED_COLOR: Color = Color("59c135")
const DISTRICT_CURRENT_COLOR: Color = Color("ffd541")
const DISTRICT_LOCKED_COLOR: Color = Color("4a5462")

@onready var titleLabel: Label = $Title
@onready var mapArea: Control = $MapArea
@onready var route: Line2D = $MapArea/Route
@onready var levelRow: HBoxContainer = $LevelRow
@onready var targetLabel: Label = $TargetLabel
@onready var hintLabel: Label = $Hint

## 区代号按推进顺序缓存一份，刷新时不必每次重排。
var districtCodes: Array[int] = []

## 推进顺序下的区色块节点，与 [member districtCodes] 一一对应。
var districtNodes: Array[ColorRect] = []


# ---- 自定义函数放前面 ----

## 按推进顺序找到每个区的色块节点；数据表加了区但地图上还没摆节点时直接报错，
## 免得大地图静默少画一区、要到肉眼试玩才发现。
func collectDistrictNodes() -> void:
	districtCodes = StageData.getDistrictCodesByOrder()
	districtNodes.clear()
	for districtCode in districtCodes:
		var node = mapArea.get_node_or_null("District_%d" % districtCode) as ColorRect

		if node == null:
			push_error("大地图缺少区代号 %d 的节点 District_%d" % [districtCode, districtCode])
			continue
		districtNodes.append(node)
		node.get_node("NameLabel").text = tr(StageData.getDistrictData(districtCode).get("nameKey", ""))


## 刷新整张图：区状态、连线、当前区的小关进度与出击目标。
func refresh() -> void:
	var currentDistrict = UserData.getCurrentDistrictCode()
	for index in districtNodes.size():
		var districtCode = districtCodes[index]
		var node = districtNodes[index]
		var statusLabel = node.get_node("StatusLabel") as Label

		if UserData.isDistrictCleared(districtCode):
			node.color = DISTRICT_CLEARED_COLOR
			statusLabel.text = tr("_StatusCleared")
		elif districtCode == currentDistrict:
			node.color = DISTRICT_CURRENT_COLOR
			statusLabel.text = tr("_StatusCurrent")
		else:
			node.color = DISTRICT_LOCKED_COLOR
			statusLabel.text = tr("_StatusLocked")
	refreshRoute()
	refreshLevelRow(currentDistrict)
	refreshTarget()


## 连线跟着色块中心走：区的位置只在场景里摆，脚本不写死坐标。
func refreshRoute() -> void:
	var points: Array[Vector2] = []
	for node in districtNodes:
		points.append(node.position + node.size * 0.5)
	route.points = points


## 当前区的 4 个小关标记（编号 + 星数 / 当前 / 待做）。
func refreshLevelRow(districtCode: int) -> void:
	# 摘下就马上放：延到帧末再 free 的话，同一帧里新旧标记会一起被 get_child_count() 数到。
	for child in levelRow.get_children():
		levelRow.remove_child(child)
		child.free()
	for levelCode in StageData.getLevelCodes(districtCode):
		var marker = Label.new()

		marker.name = "Level_%d" % levelCode
		levelRow.add_child(marker)
		marker.text = levelMarkerText(levelCode)


## 单个小关标记的文案：**没做内容的关读作「待做」**，不会伪装成可打。
func levelMarkerText(levelCode: int) -> String:
	if UserData.isLevelCleared(levelCode):
		return "%d %s" % [levelCode, "★".repeat(UserData.getLevelStars(levelCode))]
	if not StageData.isLevelPlayable(levelCode):
		return "%d %s" % [levelCode, tr("_StatusTodo")]
	if levelCode == UserData.getCurrentLevelCode():
		return "%d %s" % [levelCode, tr("_StatusCurrent")]
	return "%d %s" % [levelCode, tr("_StatusLocked")]


## 出击目标：小关名可读；还没做的关直接写「待做」，让玩家知道卡在哪。
func refreshTarget() -> void:
	var levelCode = UserData.getCurrentLevelCode()
	var prefix = "%s  " % tr("_CampaignTarget")

	if levelCode == 0:
		targetLabel.text = prefix + tr("_StatusFinished")
		return
	var levelName = tr(StageData.getLevelData(levelCode).get("nameKey", ""))

	targetLabel.text = prefix + levelName
	if not StageData.isLevelPlayable(levelCode):
		targetLabel.text += "  ·  " + tr("_StatusTodo")


## 出击：把当前小关交给关卡场景；内容还没做的小关**不跳转**（免得进空图）。
func deploy() -> void:
	var levelCode = UserData.getCurrentLevelCode()
	if not StageData.isLevelPlayable(levelCode):
		return
	StageData.currentLevel = levelCode
	SceneTransition.changeScene(StageData.getLevelScenePath(levelCode))


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	titleLabel.text = tr("_CampaignTitle")
	hintLabel.text = tr("_CampaignHint")
	collectDistrictNodes()
	refresh()


func _process(_delta: float) -> void:
	if SceneTransition.isTransitioning:
		return
	if InputManager.getAnyBombJustPressed() != -1:
		SceneTransition.changeScene(TITLE_PATH)
		return
	if InputManager.getAnyFireJustPressed() != -1:
		deploy()
		refresh()
