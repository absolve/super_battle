extends Control
## 标题界面：任意玩家按开火 / 开始键进入选人。
##
## 每次回到标题都会复位一局状态（[method Game.resetSession]）。

@onready var titleLabel: Label = $Center/TitleLabel
@onready var hintLabel: Label = $Center/HintLabel


# ---- 自定义函数放前面 ----

func onStartPressed() -> void:
	if SceneTransition.isTransitioning:
		return
	SceneTransition.changeScene("res://scene/ui/character_select.tscn")


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	Game.resetSession()
	titleLabel.text = tr("_Title")
	hintLabel.text = tr("_PressStart")
	SceneTransition.fadeIn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		onStartPressed()
		return
	for playerIndex in Game.MAX_PLAYERS:
		var fireAction = InputManager.getActionName(playerIndex, InputManager.ACTION_FIRE)
		var startAction = InputManager.getActionName(playerIndex, InputManager.ACTION_START)
		if event.is_action_pressed(fireAction) or event.is_action_pressed(startAction):
			onStartPressed()
			return
