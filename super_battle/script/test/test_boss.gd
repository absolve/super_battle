extends "res://script/test/test_player.gd"
## Boss 测试场（**手测场景**）：玩家测试场 + 一只**占位 Boss**。
##
## Boss 行为还没设计（M8），本场景先把「Boss 和玩家同场」的架子跑起来，能验的是：
## 玩家能不能打到它、它的体型与血量压不压得住场、相机与边界在超大单位下不出错、
## 电磁枪对 `ARMORED` 的倍率、火箭在 Boss 脚下的爆炸伤害。
## 真做 Boss 时改 `script/enemy/boss.gd` 与 `scene/enemy/boss.tscn`，本场景不用动。
##
## 运行：编辑器打开本场景按 F6，或
## `godot --path super_battle res://scene/test/test_boss.tscn`。

const BOSS_SCENE: PackedScene = preload("res://scene/enemy/boss.tscn")

## Boss 摆在竞技场推进轴上的位置比例（0 = 入口，1 = 尽头）。
@export var bossAlongRatio: float = 0.72

## 场上 Boss 的数量：大于 1 用来测多只大体型单位挤不挤、相机跟不跟得住。
@export var bossCount: int = 1


# ---- 自定义函数放前面 ----

## 把占位 Boss 摆进场：横向按数量铺开，纵向推到玩家前方，留出机动空间。
func spawnBosses() -> void:
	var forward = getForward()
	var lateral = getLateral()
	var lateralSpan = battleCamera.getLateralSpan()
	for index in clampi(bossCount, 1, 4):
		var boss = BOSS_SCENE.instantiate() as Boss
		add_child(boss)
		var lateralOffset = lateralSpan * (float(index) - float(bossCount + 1) * 0.5) / float(bossCount)
		boss.global_position = forward * (arenaLength * bossAlongRatio) + lateral * lateralOffset


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	super()
	spawnBosses()
