extends State
## Eliminated：生命数耗尽，本局彻底出局（终态，不再切出）。
##
## 与 [player_dead] 的区别是不再复活：关卡据此判断是否全员出局。

## 宿主（由状态机注入的 [PlayerCharacter]）。
var player: PlayerCharacter:
	get:
		return actor as PlayerCharacter


# ---- 自定义函数放前面 ----

func enter(_msg: Dictionary = {}) -> void:
	player.onEliminatedEnter()
