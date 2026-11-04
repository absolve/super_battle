class_name RocketWeapon
extends Weapon
## 火箭筒：命中后除了直伤，再按半径结算一次爆炸。
##
## 爆炸数值也从 [member Game.weaponInfo] 读（直伤 60 + 爆炸 90 / 半径 140），
## 脚本里不写死数字，也不往基类塞按武器类型的分支 —— 只是覆盖 [method onBulletHit]。

## 爆炸伤害（数据表 [code]explosionDamage[/code]）。
var explosionDamage: int = 0

## 爆炸半径，像素（数据表 [code]explosionRadius[/code]）。
var explosionRadius: float = 0.0


# ---- 自定义函数放前面 ----

## 装填基础数值后，再补读本武器独有的爆炸字段。
func setup(type: int) -> void:
	super(type)
	var data = Game.getWeaponData(weaponType)

	explosionDamage = data.get("explosionDamage", 0)
	explosionRadius = data.get("explosionRadius", 0.0)


## 命中：先算直伤，再以命中点为圆心结算爆炸。
func onBulletHit(target: Node, hitPosition: Vector2, sourcePlayer: int) -> void:
	super(target, hitPosition, sourcePlayer)
	explodeAt(hitPosition, sourcePlayer)


## 半径内的敌人与可摧毁掩体各吃一次爆炸伤害。
## 不打玩家（设计口径：火箭不自伤，见 feature_design §4.2）；
## 结构墙既不在 [code]destructible[/code] 组、也没有爆炸结算入口，天然拆不掉。
func explodeAt(center: Vector2, sourcePlayer: int) -> void:
	if explosionRadius <= 0.0:
		return
	var radiusSquared: float = explosionRadius * explosionRadius
	for node in get_tree().get_nodes_in_group("enemy"):
		var target = node as Node2D
		if withinBlast(target, center, radiusSquared):
			applyDamage(target, explosionDamage, sourcePlayer)
	for node in get_tree().get_nodes_in_group("destructible"):
		var cover = node as LevelObstacle
		if cover != null and is_instance_valid(cover) and withinBlast(cover, center, radiusSquared):
			cover.takeExplosionDamage(explosionDamage)


## 目标是否落在以 [param center] 为圆心的爆炸范围内。
func withinBlast(target: Node2D, center: Vector2, radiusSquared: float) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return center.distance_squared_to(target.global_position) <= radiusSquared
