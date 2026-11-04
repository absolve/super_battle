extends State
## Dead：受致命伤后的终态。
##
## 现在没有倒地动画与掉落演出，进状态即回收节点；以后要做「尸体停留 / 掉弹药 / 爆血」
## 就在这里挂演出，宿主 [Enemy] 不用再改。

## 宿主（由状态机注入的 [Enemy]）。
var enemy: Enemy:
	get:
		return actor as Enemy


# ---- 自定义函数放前面 ----

func enter(_msg: Dictionary = {}) -> void:
	enemy.onDeadEnter()
