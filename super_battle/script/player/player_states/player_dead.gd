extends State
## Dead：血已归零、人不可见，等 RespawnTimer 把玩家送回战场。
##
## 倒计时交给场景里的 Timer（不用 `await`，切场景时不会被悬挂的协程坑到），
## 本状态只负责开 / 关它。

## 宿主（由状态机注入的 [PlayerCharacter]）。
var player: PlayerCharacter:
	get:
		return actor as PlayerCharacter


# ---- 自定义函数放前面 ----

func enter(_msg: Dictionary = {}) -> void:
	player.onDeadEnter()


func exit() -> void:
	player.onDeadExit()
