extends Control
## 选人界面：最多 4 名玩家各自加入并选角，任一已加入玩家按开始键开战。
##
## 操作：按自己的开火键加入 → 左右键换角色 → 必杀键退出 → 开始键开战。
## 每个槽位固定对应一个玩家下标，互不抢占。

const SLOT_SCENE: PackedScene = preload("res://scene/ui/character_slot.tscn")

@onready var titleLabel: Label = $Title
@onready var slotRow: HBoxContainer = $SlotRow
@onready var hintLabel: Label = $Hint

var slots: Array[Control] = []


# ---- 自定义函数放前面 ----

func onStartBattle() -> void:
	if SceneTransition.isTransitioning:
		return
	StageData.currentLevel = 1
	SceneTransition.changeScene(StageData.getLevelScenePath(StageData.currentLevel))


func refreshSlots() -> void:
	for slot in slots:
		slot.refresh()


## 让某槽位在角色表里循环切换（[param step] 为 +1 / -1）。
func cycleCharacter(playerIndex: int, step: int) -> void:
	var characterTypes = Game.characterInfo.keys()
	var currentType = Game.selectedCharacters[playerIndex]
	var position = characterTypes.find(currentType)
	if position == -1:
		position = 0
	else:
		position = (position + step + characterTypes.size()) % characterTypes.size()
	Game.selectedCharacters[playerIndex] = characterTypes[position]


func handlePlayerInput(playerIndex: int) -> void:
	if InputManager.isFireJustPressed(playerIndex):
		if not Game.isPlayerJoined(playerIndex):
			var characterTypes = Game.characterInfo.keys()
			Game.joinPlayer(playerIndex, characterTypes[playerIndex % characterTypes.size()])
			refreshSlots()
			return
	if not Game.isPlayerJoined(playerIndex):
		return
	var leftAction = InputManager.getActionName(playerIndex, InputManager.ACTION_MOVE_LEFT)
	var rightAction = InputManager.getActionName(playerIndex, InputManager.ACTION_MOVE_RIGHT)
	if Input.is_action_just_pressed(leftAction):
		cycleCharacter(playerIndex, -1)
		refreshSlots()
	if Input.is_action_just_pressed(rightAction):
		cycleCharacter(playerIndex, 1)
		refreshSlots()
	if InputManager.isBombJustPressed(playerIndex):
		Game.leavePlayer(playerIndex)
		refreshSlots()


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	Game.resetSession()
	for index in Game.MAX_PLAYERS:
		var slot = SLOT_SCENE.instantiate()
		slotRow.add_child(slot)
		slot.setSlotIndex(index)
		slots.append(slot)
	titleLabel.text = tr("_SelectTitle")
	hintLabel.text = tr("_SelectHint")
	refreshSlots()


func _process(_delta: float) -> void:
	for playerIndex in Game.MAX_PLAYERS:
		handlePlayerInput(playerIndex)
	if InputManager.getAnyStartPressed() != -1 and not Game.joinedPlayers.is_empty():
		onStartBattle()
