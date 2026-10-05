class_name PlayerCharacter
extends CharacterBody2D
## 玩家角色：4 人共用的基础控制器。
##
## 差异全部来自数据表（[member Game.characterInfo] / [member Game.weaponInfo]），
## 本脚本不写任何「某个角色 / 某把枪」的分支；新增角色或武器只改数据。
##
## 操作由 [InputManager] 按 [member playerIndex] 取，因此同一场景可放 4 个实例。

## 血量归零时发出（还在等待复活的阶段）。
signal died(playerIndex: int)

## 生命数耗尽、彻底出局。
signal eliminated(playerIndex: int)

## 换枪后发出。
signal weaponChanged(playerIndex: int, weaponType: int)

## 使用必杀后发出。
signal bombUsed(playerIndex: int)

const PLAYER_BULLET_SCENE: PackedScene = preload("res://scene/bullet/bullet.tscn")

const BOMB_RADIUS: float = 420.0
const BOMB_DAMAGE: int = 120
const MUZZLE_DISTANCE: float = 38.0

## 玩家槽位（0~3），由关卡在生成时写入。
@export var playerIndex: int = 0

## 复活无敌时间（秒）。
@export var invincibleTime: float = 2.5

## 复活等待时间（秒）。
@export var respawnDelay: float = 1.5

## 初始必杀数量。
@export var bombCount: int = 2

var characterType: int = -1
var maxHp: int = 100
var hp: int = 100
var moveSpeed: float = 280.0
var weaponType: int = Game.WeaponType.PISTOL
var ammo: int = -1
var isAlive: bool = true
var isInvincible: bool = false
var aimDirection: Vector2 = Vector2.UP
var respawnPosition: Vector2 = Vector2.ZERO
## 允许活动的世界范围，由关卡随相机每帧更新。
var bounds: Rect2 = Rect2(-540, -960, 1080, 1920)

var fireCooldown: float = 0.0
var invincibleTimer: float = 0.0

@onready var gun: Polygon2D = $Gun


# ---- 自定义函数放前面 ----

## 用角色数据初始化；[param index] 为玩家槽位。
func setup(index: int, character: int) -> void:
	playerIndex = index
	characterType = character
	var data = Game.getCharacterData(index)
	maxHp = data.get("maxHp", 100)
	moveSpeed = data.get("speed", 280.0)
	weaponType = data.get("startWeapon", Game.WeaponType.PISTOL)
	hp = maxHp
	ammo = _getMaxAmmo(weaponType)
	modulate = Game.getPlayerColor(index)


## 设置出生点并复位战斗状态。
func resetForSpawn(spawnPosition: Vector2) -> void:
	respawnPosition = spawnPosition
	global_position = spawnPosition
	hp = maxHp
	isAlive = true
	show()
	startInvincible(invincibleTime)


## 受伤；无敌或已阵亡时忽略。
func takeDamage(amount: int) -> void:
	if not isAlive or isInvincible:
		return
	hp -= amount
	if hp <= 0:
		hp = 0
		die()


## 阵亡：扣一条命，还有命则等待后原地复活，否则出局。
func die() -> void:
	isAlive = false
	hide()
	died.emit(playerIndex)
	Game.playerLives[playerIndex] = maxi(Game.playerLives[playerIndex] - 1, 0)
	if Game.playerLives[playerIndex] <= 0:
		eliminated.emit(playerIndex)
		return
	await get_tree().create_timer(respawnDelay).timeout
	if not is_inside_tree():
		return
	resetForSpawn(respawnPosition)


## 进入无敌状态。
func startInvincible(duration: float) -> void:
	isInvincible = true
	invincibleTimer = duration


## 切换武器并重置弹药。
func switchWeapon(newWeaponType: int) -> void:
	weaponType = newWeaponType
	ammo = _getMaxAmmo(weaponType)
	weaponChanged.emit(playerIndex, weaponType)


## 拾取补给：加血或换枪。
func pickWeapon(newWeaponType: int) -> void:
	switchWeapon(newWeaponType)


## 回血，不超过上限。
func heal(amount: int) -> void:
	hp = mini(hp + amount, maxHp)


## 加分数（内部转发到 [Game]，方便敌人调用）。
func addScore(amount: int) -> void:
	Game.addScore(playerIndex, amount)


## 开火：按武器数据生成 1~N 颗带散射的子弹。
func fire() -> void:
	if not isAlive or fireCooldown > 0.0:
		return
	var weapon = Game.getWeaponData(weaponType)
	if weapon.is_empty():
		return
	if ammo == 0:
		switchWeapon(Game.WeaponType.PISTOL)
		return
	var bulletCount: int = weapon.get("bulletCount", 1)
	var spreadDeg: float = weapon.get("spreadDeg", 0.0)
	var baseAngle: float = aimDirection.angle()
	for index in bulletCount:
		var offsetDeg: float = 0.0
		if bulletCount > 1:
			offsetDeg = -spreadDeg * 0.5 + spreadDeg * float(index) / float(bulletCount - 1)
		var shotDirection = Vector2.RIGHT.rotated(baseAngle + deg_to_rad(offsetDeg))
		_spawnBullet(shotDirection, weapon)
	fireCooldown = weapon.get("fireInterval", 0.2)
	if ammo > 0:
		ammo -= 1


## 必杀：清掉身边一圈敌人，并短暂无敌。
func useBomb() -> void:
	if not isAlive or bombCount <= 0:
		return
	bombCount -= 1
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and global_position.distance_to(enemy.global_position) <= BOMB_RADIUS:
			if enemy.has_method("takeDamage"):
				enemy.takeDamage(BOMB_DAMAGE, playerIndex)
	startInvincible(maxf(invincibleTime, 1.0))
	bombUsed.emit(playerIndex)


# ---- 内部函数放后面 ----

func _spawnBullet(shotDirection: Vector2, weapon: Dictionary) -> void:
	var bullet = PLAYER_BULLET_SCENE.instantiate()
	bullet.setup(shotDirection, playerIndex)
	bullet.damage = weapon.get("damage", 20)
	bullet.speed = weapon.get("bulletSpeed", 900.0)
	bullet.pierce = weapon.get("pierce", 0)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + shotDirection * MUZZLE_DISTANCE


func _getMaxAmmo(weapon: int) -> int:
	return Game.getWeaponData(weapon).get("ammo", -1)


func _updateInvincible(delta: float) -> void:
	if not isInvincible:
		return
	invincibleTimer -= delta
	modulate.a = 0.4 if int(invincibleTimer * 10.0) % 2 == 0 else 1.0
	if invincibleTimer <= 0.0:
		isInvincible = false
		modulate.a = 1.0


func _updateAim(moveInput: Vector2) -> void:
	if moveInput.length_squared() > 0.01:
		aimDirection = moveInput.normalized()
	gun.rotation = aimDirection.angle() + PI * 0.5


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	fireCooldown = maxf(fireCooldown - delta, 0.0)
	_updateInvincible(delta)
	if not isAlive:
		return
	var moveInput = InputManager.getMoveVector(playerIndex)
	velocity = moveInput * moveSpeed
	move_and_slide()
	position = position.clamp(bounds.position, bounds.end)
	_updateAim(moveInput)
	if InputManager.isFirePressed(playerIndex):
		fire()
	if InputManager.isBombJustPressed(playerIndex):
		useBomb()
