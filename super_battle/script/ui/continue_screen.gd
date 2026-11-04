extends Control
## 「是否继续游戏？」画面：10 秒倒计时，**默认继续**。
##
## 开火键 = 立刻继续，必杀键 = 放弃回标题，什么都不按到点也算继续 ——
## 保证「人人可通关」：卡关的人最多是回检查点重打，而不是被判负退出。
## 挂在关卡的 HudLayer 下，process_mode 设成 ALWAYS（在场景里配好），否则暂停后收不到输入。

## 点「继续」时发出（关卡负责恢复命数、把玩家放回检查点）。
signal continueRequested

## 点「放弃」时发出。
signal giveUpRequested

## 倒计时秒数（level_design §6）。
@export var countdownSeconds: float = 10.0

## 剩余秒数。
var timeLeft: float = 0.0

@onready var titleLabel: Label = $Center/TitleLabel
@onready var countLabel: Label = $Center/CountLabel
@onready var hintLabel: Label = $Center/HintLabel
@onready var continueButton: Button = $Center/ContinueButton
@onready var giveUpButton: Button = $Center/GiveUpButton


# ---- 自定义函数放前面 ----

## 打开并开始倒计时。暂停场景树由调用方负责（与暂停菜单同一套分工）。
func open() -> void:
	show()
	timeLeft = countdownSeconds
	continueButton.grab_focus()


func close() -> void:
	hide()


## 继续本关。
func continueNow() -> void:
	if not visible:
		return
	close()
	continueRequested.emit()


## 放弃：关卡按失败结算。
func giveUp() -> void:
	if not visible:
		return
	close()
	giveUpRequested.emit()


func onContinuePressed() -> void:
	continueNow()


func onGiveUpPressed() -> void:
	giveUp()


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	hide()
	titleLabel.text = tr("_ContinueTitle")
	hintLabel.text = tr("_ContinueHint")
	continueButton.text = tr("_ContinueYes")
	giveUpButton.text = tr("_ContinueNo")
	continueButton.pressed.connect(onContinuePressed)
	giveUpButton.pressed.connect(onGiveUpPressed)


func _process(delta: float) -> void:
	if not visible:
		return
	timeLeft = maxf(timeLeft - delta, 0.0)
	countLabel.text = str(ceili(timeLeft))
	if InputManager.getAnyFireJustPressed() != -1:
		continueNow()
		return
	if InputManager.getAnyBombJustPressed() != -1:
		giveUp()
		return
	if timeLeft <= 0.0:
		continueNow()
