extends State
## Shoot：在保持距离上按节奏开火；目标退出射程就回 Chase。
##
## 只有配了 `attackRange` 与 `attackInterval` 的敌人会进到这里（悬浮兵、哨戒炮台）。
## 近战型永远留在 Chase，所以这不是分支判断，而是它们压根没有这条转移。

## 宿主（由状态机注入的 [Enemy]）。
var enemy: Enemy:
	get:
		return actor as Enemy


# ---- 自定义函数放前面 ----

## 进状态立刻允许开一枪，不用先空等一个间隔。
func enter(_msg: Dictionary = {}) -> void:
	enemy.attackCooldown = 0.0


func physicsUpdate(delta: float) -> void:
	enemy.updateShoot(delta)
