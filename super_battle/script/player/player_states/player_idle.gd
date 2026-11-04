extends State
## Idle：存活且可操作 —— 移动 / 瞄准 / 开火 / 必杀。
##
## 具体逻辑留在 [method PlayerCharacter.updateIdle]，本状态只负责把每物理帧转给宿主。

## 宿主（由状态机注入的 [PlayerCharacter]）。
var player: PlayerCharacter:
	get:
		return actor as PlayerCharacter


# ---- 自定义函数放前面 ----

func physicsUpdate(_delta: float) -> void:
	player.updateIdle()
