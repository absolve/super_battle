extends Control
## 选人界面中的单个玩家槽位。
##
## 槽位只负责显示，所有状态都从 [Game] 读取，由 [CharacterSelect] 在状态变化后调用 [method refresh]。

## 槽位对应的玩家下标（0~3），由 [method setSlotIndex] 写入。
var playerIndex: int = 0

@onready var panel: ColorRect = $Panel
@onready var accent: ColorRect = $Accent
@onready var nameLabel: Label = $NameLabel
@onready var characterLabel: Label = $CharacterLabel
@onready var stateLabel: Label = $StateLabel


# ---- 自定义函数放前面 ----

## 设置槽位下标并锁定玩家配色。
func setSlotIndex(index: int) -> void:
	playerIndex = index
	accent.color = Game.getPlayerColor(index)
	nameLabel.text = "P%d" % (index + 1)


## 按当前 [Game] 状态刷新显示。
func refresh() -> void:
	if Game.isPlayerJoined(playerIndex):
		var characterData = Game.getCharacterData(playerIndex)
		characterLabel.text = tr(characterData.get("nameKey", ""))
		stateLabel.text = tr("_SelectReady")
		panel.color = Color(0.16, 0.2, 0.28, 0.95)
		characterLabel.modulate.a = 1.0
	else:
		characterLabel.text = "—"
		stateLabel.text = tr("_SelectJoin")
		panel.color = Color(0.09, 0.11, 0.15, 0.85)
		characterLabel.modulate.a = 0.35
