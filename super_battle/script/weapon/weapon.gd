class_name Weapon
extends Node2D
## 武器基类：一把武器的弹药、冷却与开火。
##
## 数值（伤害 / 射速 / 弹丸数 / 散射 / 弹速 / 穿透 / 弹量）全部读自
## [member Game.weaponInfo]，本脚本只持有**运行期状态**，所以新增武器只往数据表加一行，
## 不写任何「某把枪」的分支。枪口偏移、特效、音效这类差异以后用**继承场景**在
## [code]scene/weapon/weapon.tscn[/code] 上覆盖，同样不动逻辑。
##
## 武器是玩家枪包容器（[code]Weapons[/code] 节点）的子节点，位置随玩家走，
## 因此 [method fire] 只需要一个瞄准方向。
##
## 子弹命中后回到 [method onBulletHit] 结算，所以有特殊命中效果的武器走
## **继承场景 + 覆盖钩子**（[code]rocket.tscn[/code] / [code]tesla.tscn[/code]）；
## 数据表里用 [code]scene[/code] 键指向各自的继承场景。

## 弹药变化时发出（HUD 刷新用）。
signal ammoChanged(ammo: int)

## 最后一发打光时发出，带上打空的这把（持有者据此换枪）。
signal ammoEmptied(weapon: Weapon)

const BULLET_SCENE: PackedScene = preload("res://scene/bullet/bullet.tscn")

## 数据表漏填 bulletLifeTime 时的兜底，与 bullet.tscn 场景里的默认值一致。
const DEFAULT_BULLET_LIFE: float = 2.5

## 是否连发：true = 按住开火键持续射击；false = 每次按下只出一发。
## 武器种类还没定，先默认连发，以后在继承场景的 Inspector 里按枪种改。
@export var isAutomatic: bool = true

## 枪口距持有者中心的距离（像素）。
@export var muzzleDistance: float = 38.0

## 武器类型（[enum Game.WeaponType] 值），决定读数据表的哪一行；由 [method setup] 写入。
var weaponType: int = Game.WeaponType.PISTOL

## 剩余弹药；-1 = 无限弹。
var ammo: int = -1

## 弹药上限；-1 = 无限弹。
var maxAmmo: int = -1

## 单发伤害。
var damage: int = 20

## 两发之间的最小间隔（秒）。
var fireInterval: float = 0.22

## 一次开火抛出的弹丸数（霰弹 / 火焰类 > 1）。
var bulletCount: int = 1

## 多弹丸时的散射总角度（度）。
var spreadDeg: float = 0.0

## 弹丸初速（像素 / 秒）。
var bulletSpeed: float = 900.0

## 可额外穿透的目标数。
var pierce: int = 0

## 子弹存活秒数 = 武器有效射程的表达（射程 = bulletSpeed × bulletLifeTime）。
var bulletLifeTime: float = DEFAULT_BULLET_LIFE

## 开火冷却剩余（秒）。
var fireCooldown: float = 0.0


# ---- 自定义函数放前面 ----

## 指定类型并按数据表装填；[param type] 为 [enum Game.WeaponType] 值。
func setup(type: int) -> void:
	weaponType = type
	loadStats()


## 从数据表读数值。数值在运行中被调整（升级 / 平衡）后再调一次即可。
func loadStats() -> void:
	var data = Game.getWeaponData(weaponType)
	if data.is_empty():
		push_warning("Weapon: 数据表里没有武器 %d" % weaponType)
		return
	maxAmmo = data.get("ammo", -1)
	ammo = maxAmmo
	damage = data.get("damage", 20)
	fireInterval = data.get("fireInterval", 0.22)
	bulletCount = data.get("bulletCount", 1)
	spreadDeg = data.get("spreadDeg", 0.0)
	bulletSpeed = data.get("bulletSpeed", 900.0)
	pierce = data.get("pierce", 0)
	bulletLifeTime = data.get("bulletLifeTime", DEFAULT_BULLET_LIFE)


## 补满弹药（捡到同款武器 / 弹药补给）。
func refill() -> void:
	ammo = maxAmmo
	ammoChanged.emit(ammo)


## 是否还有弹可开；无限弹武器恒为 true。
func hasAmmo() -> bool:
	return maxAmmo < 0 or ammo > 0


## 冷却是否结束。
func isReady() -> bool:
	return fireCooldown <= 0.0


## 能否开火（冷却与弹药的合取），供玩家与 AI 决策用。
func canFire() -> bool:
	return isReady() and hasAmmo()


## 开火：按数据表生成 1~N 颗带散射的子弹。成功返回 true，调用方据此决定音效 / 特效。
func fire(aimDirection: Vector2, sourcePlayer: int) -> bool:
	if not canFire():
		return false
	var baseAngle = aimDirection.angle()
	for index in bulletCount:
		var offsetDeg: float = 0.0
		if bulletCount > 1:
			offsetDeg = -spreadDeg * 0.5 + spreadDeg * float(index) / float(bulletCount - 1)
		spawnBullet(Vector2.RIGHT.rotated(baseAngle + deg_to_rad(offsetDeg)), sourcePlayer)
	fireCooldown = fireInterval
	if maxAmmo > 0:
		ammo -= 1
		ammoChanged.emit(ammo)
		if ammo == 0:
			ammoEmptied.emit(self)
	return true


## 推进冷却；由持有者的每帧公共逻辑调用。
func updateCooldown(delta: float) -> void:
	fireCooldown = maxf(fireCooldown - delta, 0.0)


## 武器名（已翻译）；数据表没配时返回空串。
func getDisplayName() -> String:
	return tr(Game.getWeaponData(weaponType).get("nameKey", ""))


## 弹药显示文本：无限弹画“∞”，否则“当前/上限”。
func getAmmoText() -> String:
	if maxAmmo < 0:
		return "∞"
	return "%d/%d" % [ammo, maxAmmo]


## 命中回调：默认就是「按伤害扣血」。有特殊效果的武器**继承本场景覆盖它**
## （爆炸、对甲倍率），不要在基类里按 weaponType 写分支。
## [param hitPosition] 为命中的世界坐标，范围类效果用它当圆心。
func onBulletHit(target: Node, _hitPosition: Vector2, sourcePlayer: int) -> void:
	applyDamage(target, damage, sourcePlayer)


## 对目标造成伤害；没有 takeDamage 的节点（地面、装饰）直接忽略。
## 参数签名与 [method Enemy.takeDamage] / [method LevelObstacle.takeDamage] 对齐，
## 范围伤害才能对敌人和掩体用同一句调用。
func applyDamage(target: Node, amount: int, sourcePlayer: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("takeDamage"):
		return
	target.takeDamage(amount, sourcePlayer)


## 生成一发子弹：方向定死后落到当前场景，出膛点在持有者前方 muzzleDistance 处。
func spawnBullet(shotDirection: Vector2, sourcePlayer: int) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.setup(shotDirection, sourcePlayer)
	bullet.damage = damage
	bullet.speed = bulletSpeed
	bullet.pierce = pierce
	bullet.lifeTime = bulletLifeTime
	# 命中结算交回武器自己处理，子弹只负责飞行与回收。
	bullet.sourceWeapon = self
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + shotDirection * muzzleDistance
