extends State
## Chase：追踪最近的玩家，贴住时按接触节奏扣血。
##
## 具体逻辑留在 [method Enemy.updateChase]，本状态只负责每物理帧转发一次。

## 宿主（由状态机注入的 [Enemy]）。
var enemy: Enemy:
	get:
		return actor as Enemy


# ---- 自定义函数放前面 ----

func physicsUpdate(_delta: float) -> void:
	enemy.updateChase()
