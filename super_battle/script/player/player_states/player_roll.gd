extends State
## Roll：翻滚中 —— 位移、起身、期间的子弹无敌窗口。
##
## 位移时长 / 距离 / 无敌帧全在宿主的导出参数里（[member PlayerCharacter.rollDistance] 等），
## 本状态只负责把每物理帧转给 [method PlayerCharacter.updateRoll]，
## 以及进出时开关无敌窗口（逻辑留在宿主，状态不存数据，见 code_design §6.2）。

## 宿主（由状态机注入的 [PlayerCharacter]）。
var player: PlayerCharacter:
	get:
		return actor as PlayerCharacter


# ---- 自定义函数放前面 ----

func enter(_msg: Dictionary = {}) -> void:
	player.onRollEnter()


func exit() -> void:
	player.onRollExit()


func physicsUpdate(delta: float) -> void:
	player.updateRoll(delta)
