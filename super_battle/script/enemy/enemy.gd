class_name Enemy
extends CharacterBody2D
## 敌人基类：追踪最近的玩家、接触扣血、受击死亡掉分。
##
## 具体敌人用**继承场景**复用本脚本，只改 Inspector 里的数值（血量 / 速度 / 伤害 / 奖励）；
## 只有行为不同才在子脚本里覆盖方法。

## 死亡时发出，参数为分数奖励与击杀者槽位（-1 表示无人击杀）。
signal enemyDied(scoreReward: int, killerIndex: int)

## 敌人 id，对应 [member StageData.enemyScenes] 的键，便于数值选型与统计。
@export var enemyId: String = "grunt"

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

## 回收线：位置在 [member despawnForward] 方向上的投影**小于** [member despawnLine]（即落到相机后方）时回收。
## 由关卡在刷怪时按相机位置写入，纵向 / 横向推进都能用。
var despawnForward: Vector2 = Vector2.UP
var despawnLine: float = -100000.0

var hp: int = 0
var lastHitPlayer: int = -1
var contactCooldown: float = 0.0

@onready var contactArea: Area2D = $ContactArea


# ---- 自定义函数放前面 ----

## 受伤；[param sourcePlayer] 为击杀者槽位，用于计分。
func takeDamage(amount: int, sourcePlayer: int = -1) -> void:
	if hp <= 0:
		return
	hp -= amount
	lastHitPlayer = sourcePlayer
	if hp <= 0:
		die()


## 死亡：给击杀者加分后回收。
func die() -> void:
	if lastHitPlayer >= 0:
		Game.addScore(lastHitPlayer, scoreReward)
	enemyDied.emit(scoreReward, lastHitPlayer)
	queue_free()


## 贴着玩家时按 [member contactDamageInterval] 的节奏持续扣血。
func _applyContactDamage() -> void:
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

func _getNearestPlayer() -> PlayerCharacter:
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
	contactCooldown = maxf(contactCooldown - delta, 0.0)
	# 落到相机后方的回收线之外就消失（纵向 / 横向推进通用）。
	if global_position.dot(despawnForward) < despawnLine:
		queue_free()
		return
	_applyContactDamage()
	var target = _getNearestPlayer()
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
