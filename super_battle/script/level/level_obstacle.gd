class_name LevelObstacle
extends StaticBody2D
## 房间掩体：可选耐久，**只有爆炸 / 爆破伤害能拆**（level_design §5.1「掩体可被火箭 / 爆破摧毁」）。
##
## 挂在房间的 [code]Obstacles[/code] 下，形状与贴图沿用原来的 StaticBody2D 摆法。
## 子弹直接打上去只会被挡住（obstacle 层已在子弹掩码里），不扣耐久 ——
## 否则手枪三发就能拆掉掩体，掩体就失去意义了。
##
## [member hitPoints] 留 0 就是打不坏 —— 房间两侧墙与关后墙**必须**留 0：
## 它们撑着相机与玩家的活动范围，拆了人会掉出房间区域。

## 耐久值；0 = 不可摧毁。
@export var hitPoints: int = 0

## 剩余耐久。
var hp: int = 0


# ---- 自定义函数放前面 ----

## 爆炸 / 爆破伤害扣耐久。普通子弹走的是 [method Enemy.takeDamage] 那条路，不会调到这里。
func takeExplosionDamage(amount: int) -> void:
	if hp <= 0:
		return
	hp -= amount
	if hp <= 0:
		destroy()


## 掩体被打碎。碎块特效与掉落以后接 M3，现在先静默回收。
func destroy() -> void:
	queue_free()


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	hp = hitPoints
	if hp > 0:
		add_to_group("destructible")
