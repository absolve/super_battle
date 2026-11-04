class_name TeslaWeapon
extends Weapon
## 电磁枪：对重甲与护盾目标按倍率增伤（26 × 2.5 → 65）。
##
## 倍率读自 [member Game.weaponInfo] 的 [code]armorMulti[/code]；
## 打普通步兵就是基类的 26 伤害，所以它是「看敌人带哪把」的策略位，不是无脑升级。

## 对重甲 / 护盾目标的伤害倍率（数据表 [code]armorMulti[/code]）。
var armorMulti: float = 1.0


# ---- 自定义函数放前面 ----

## 装填基础数值后，再补读倍率字段。
func setup(type: int) -> void:
	super(type)
	armorMulti = Game.getWeaponData(weaponType).get("armorMulti", 1.0)


## 命中：重甲 / 护盾吃倍率，其余按正常伤害。
func onBulletHit(target: Node, _hitPosition: Vector2, sourcePlayer: int) -> void:
	var amount = damage

	if armorMulti > 1.0 and isArmoredTarget(target):
		amount = int(damage * armorMulti)
	applyDamage(target, amount, sourcePlayer)


## 带 [member Enemy.armorType] 且不是「普通」的目标都算重甲 / 护盾。
## 掩体等没有该属性的节点返回 false，走正常伤害。
func isArmoredTarget(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var armorValue: Variant = target.get("armorType")
	if armorValue == null:
		return false
	return int(armorValue) != Enemy.ArmorType.NORMAL
