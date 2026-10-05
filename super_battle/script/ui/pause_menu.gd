extends Control
## 暂停菜单：暂停场景树，提供继续 / 重开 / 回标题。
##
## [member process_mode] 设为 ALWAYS（在场景里配好），否则暂停后自身也不再响应输入。

signal resumeRequested
signal restartRequested
signal quitRequested

@onready var titleLabel: Label = $Center/TitleLabel
@onready var resumeButton: Button = $Center/ResumeButton
@onready var restartButton: Button = $Center/RestartButton
@onready var quitButton: Button = $Center/QuitButton


# ---- 自定义函数放前面 ----

## 打开菜单并暂停游戏。
func open() -> void:
	show()
	get_tree().paused = true
	resumeButton.grab_focus()


## 关闭菜单并恢复游戏。
func close() -> void:
	hide()
	get_tree().paused = false


func onResumePressed() -> void:
	close()
	resumeRequested.emit()


func onRestartPressed() -> void:
	close()
	restartRequested.emit()


func onQuitPressed() -> void:
	close()
	quitRequested.emit()


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	hide()
	titleLabel.text = tr("_Paused")
	resumeButton.text = tr("_Resume")
	restartButton.text = tr("_Restart")
	quitButton.text = tr("_QuitToTitle")
	resumeButton.pressed.connect(onResumePressed)
	restartButton.pressed.connect(onRestartPressed)
	quitButton.pressed.connect(onQuitPressed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		onResumePressed()
		return
	for playerIndex in Game.MAX_PLAYERS:
		var actionName = InputManager.getActionName(playerIndex, InputManager.ACTION_START)
		if event.is_action_pressed(actionName):
			onResumePressed()
			return
