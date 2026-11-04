class_name Enemy
extends CharacterBody2D
## 敌人基类：追踪最近的玩家、接触扣血、受击死亡掉分。
##
## 具体敌人用**继承场景**复用本脚本，只改 Inspector 里的数值（血量 / 速度 / 伤害 / 奖励）；
## 只有行为不同才在子脚本里覆盖方法。
##
## 行为和玩家一样按状态机分发（子节点 `StateMachine`）：`Chase` 追踪、`Shoot` 保持距离开火、
## `Dead` 终态。会不会进入 `Shoot` 完全由数据决定（`attackRange` / `attackInterval` 配了才会），
## 所以近战型与射手型共用同一份代码，加新状态仍只需「状态节点 + 一对钩子」。

## 死亡时发出，参数为分数奖励与击杀者槽位（-1 表示无人击杀）。
signal enemyDied(scoreReward: int, killerIndex: int)

const ENEMY_BULLET_SCENE: PackedScene = preload("res://scene/bullet/enemy_bullet.tscn")

## 目标离开射程多少倍才退回 `Chase`（迟滞，免得在边界上反复切状态）。
const ATTACK_HYSTERESIS: float = 1.25

## 与保持距离的容差（像素）：在这个带子里既不追也不退。
const STANDOFF_TOLERANCE: float = 40.0

enum ArmorType {
	NORMAL,
	ARMORED,
	SHIELDED,
}

## 敌人 id，对应 [member StageData.enemyScenes] 的键，便于数值选型与统计。
@export var enemyId: String = "grunt"

## 护甲类型：电磁枪这类特化武器按它增伤（feature_design §4.2）。
## 普通步兵保持 NORMAL；重装兵 / 炮台用 ARMORED，带盾精英与护盾阶段 Boss 用 SHIELDED。
@export var armorType: ArmorType = ArmorType.NORMAL

## 最大血量。
@export var maxHp: int = 40

## 移动速度（像素 / 秒）。
@export var moveSpeed: float = 110.0

## 接触玩家时造成的伤害。
@export var contactDamage: int = 12

## 接触伤害的间隔（秒）；贴着玩家时按这个节奏持续扣血。
@export var contactDamageInterval: float = 0.6

## 与玩家保持的最小距离，避免完全叠在玩家身上（叠住会导致子弹从身侧掠过打不到）。
@export var stopDistance: float = 30.0

## 被击杀给玩家的分数。
@export var scoreReward: int = 100

## 射程（像素）。> 0 才是会还手的敌人：靠到这个距离就从 `Chase` 转 `Shoot`。
@export var attackRange: float = 0.0

## 想站定的距离（像素）；0 = 站桩不动（哨戒炮台）。
@export var standoffDistance: float = 0.0

## 开火间隔（秒）；0 = 不开火（近战型）。
@export var attackInterval: float = 0.0

## 单发子弹伤害。
@export var bulletDamage: int = 10

## 子弹初速（像素 / 秒）。
@export var bulletSpeed: float = 460.0

## 回收线：位置在 [member despawnForward] 方向上的投影**小于** [member despawnLine]（即落到相机后方）时回收。
## 由关卡在刷怪时按相机位置写入，纵向 / 横向推进都能用。
var despawnForward: Vector2 = Vector2.UP
var despawnLine: float = -100000.0

var hp: int = 0
var lastHitPlayer: int = -1
var contactCooldown: float = 0.0
var attackCooldown: float = 0.0

@onready var contactArea: Area2D = $ContactArea
@onready var hitFlash: HitFlash = $HitFlash
@onready var stateMachine: StateMachine = $StateMachine


# ---- 自定义函数放前面 ----

## 受伤；[param sourcePlayer] 为击杀者槽位，用于计分。
func takeDamage(amount: int, sourcePlayer: int = -1) -> void:
	if hp <= 0:
		return
	hp -= amount
	lastHitPlayer = sourcePlayer
	hitFlash.flash()
	if hp <= 0:
		die()


## 死亡：给击杀者加分后切到 `Dead`，回收由终态做。
func die() -> void:
	if lastHitPlayer >= 0:
		Game.addScore(lastHitPlayer, scoreReward)
	enemyDied.emit(scoreReward, lastHitPlayer)
	stateMachine.transitionTo(&"Dead")


## Chase：追踪最近的玩家；贴住就停距、按节奏扣血；没有目标则朝相机后方走回去等回收。
## 会还手的敌人一进射程就被状态脚本切去 `Shoot`。
func updateChase() -> void:
	applyContactDamage()
	var target = getNearestPlayer()
	if shouldStartAttacking(target):
		stateMachine.transitionTo(&"Shoot")
	if target == null:
		velocity = -despawnForward * moveSpeed
		move_and_slide()
		return
	var toTarget = target.global_position - global_position
	if toTarget.length() <= stopDistance:
		velocity = Vector2.ZERO
	else:
		velocity = toTarget.normalized() * moveSpeed
	move_and_slide()


## 会不会还手：射程与开火间隔都配了才算（近战型两个都是 0）。
func canAttack() -> bool:
	return attackInterval > 0.0 and attackRange > 0.0


## 目标进入射程就该转 `Shoot`。
func shouldStartAttacking(target: PlayerCharacter) -> bool:
	if not canAttack() or target == null:
		return false
	return global_position.distance_to(target.global_position) <= attackRange


## 目标退出射程（带迟滞）就该回 `Chase`；目标没了也退。
func shouldStopAttacking(target: PlayerCharacter) -> bool:
	if target == null:
		return true
	return global_position.distance_to(target.global_position) > attackRange * ATTACK_HYSTERESIS


## Shoot：站在保持距离上按节奏开火。
func updateShoot(delta: float) -> void:
	var target = getNearestPlayer()

	if shouldStopAttacking(target):
		stateMachine.transitionTo(&"Chase")
		return
	attackCooldown = maxf(attackCooldown - delta, 0.0)
	keepStandoff(target)
	if attackCooldown <= 0.0:
		shootAt(target)
		attackCooldown = attackInterval


## 站到想站的位置：太远逼近、太近后退、容差带内停下；站桩型不动。
func keepStandoff(target: PlayerCharacter) -> void:
	var toTarget = target.global_position - global_position
	var distance = toTarget.length()

	if standoffDistance <= 0.0 or distance <= 0.001:
		velocity = Vector2.ZERO
	elif distance > standoffDistance:
		velocity = toTarget / distance * moveSpeed
	elif distance < standoffDistance - STANDOFF_TOLERANCE:
		velocity = -toTarget / distance * moveSpeed
	else:
		velocity = Vector2.ZERO
	move_and_slide()


## 朝目标发一发子弹。命中后的结算在 [method PlayerCharacter.takeDamage]。
func shootAt(target: PlayerCharacter) -> void:
	var direction = target.global_position - global_position

	if direction.length_squared() <= 0.001:
		return
	var bullet = ENEMY_BULLET_SCENE.instantiate()

	bullet.setup(direction.normalized(), -1)
	bullet.damage = bulletDamage
	bullet.speed = bulletSpeed
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position


## Dead 进入：加分与 [signal enemyDied] 已由 [method die] 做完，这里只收尾回收。
func onDeadEnter() -> void:
	velocity = Vector2.ZERO
	queue_free()


## 当前状态名（探针与以后 AI 决策用）。
func getCurrentStateName() -> StringName:
	return stateMachine.currentName()


## 与状态无关的每帧处理：接触冷却、落到相机后方的回收。
func updateCommon(delta: float) -> void:
	contactCooldown = maxf(contactCooldown - delta, 0.0)
	if global_position.dot(despawnForward) < despawnLine:
		queue_free()


## 贴着玩家时按 [member contactDamageInterval] 的节奏持续扣血。
func applyContactDamage() -> void:
	if contactCooldown > 0.0:
		return
	for body in contactArea.get_overlapping_bodies():
		var player = body as PlayerCharacter
		if player == null or not player.isAlive:
			continue
		player.takeDamage(contactDamage)
		contactCooldown = contactDamageInterval
		return


# ---- 内部函数放后面 ----

func getNearestPlayer() -> PlayerCharacter:
	var nearest: PlayerCharacter = null
	var nearestDistance: float = INF
	for node in get_tree().get_nodes_in_group("player"):
		var candidate = node as PlayerCharacter
		if candidate == null or not candidate.isAlive:
			continue
		var distance = global_position.distance_squared_to(candidate.global_position)
		if distance < nearestDistance:
			nearestDistance = distance
			nearest = candidate
	return nearest


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	add_to_group("enemy")
	hp = maxHp


func _physics_process(delta: float) -> void:
	# 状态相关行为由 StateMachine 子节点分发（它的 _physics_process 在本函数之后执行）。
	updateCommon(delta)
