class_name PlayerCharacter
extends CharacterBody2D
## 玩家角色：4 人共用的基础控制器。
##
## 差异全部来自数据表（[member Game.characterInfo] / [member Game.weaponInfo]），
## 本脚本不写任何「某个角色 / 某把枪」的分支；新增角色或武器只改数据。
##
## 操作由 [InputManager] 按 [member playerIndex] 取，因此同一场景可放 4 个实例。
##
## 行为按状态机分发（子节点 `StateMachine`）：`Idle` 可操作、`Roll` 翻滚中、
## `Dead` 等复活、`Eliminated` 出局。状态脚本只做转发，具体逻辑留在本脚本的 `updateXxx` /
## `onXxxEnter` 钩子里；以后加状态（例如受击硬直）只需加一个状态节点 + 一对钩子。
##
## 武器是挂在 `Weapons` 容器下的 [Weapon] 节点，数值全在 [member Game.weaponInfo] 里；
## 本脚本只管三件事：枪包容量（[member weaponSlots]）、循环切换、打空兜底。

## 血量归零时发出（还在等待复活的阶段）。
signal died(playerIndex: int)

## 生命数耗尽、彻底出局。
signal eliminated(playerIndex: int)

## 换枪后发出。
signal weaponChanged(playerIndex: int, weaponType: int)

## 使用必杀后发出。
signal bombUsed(playerIndex: int)

const WEAPON_SCENE: PackedScene = preload("res://scene/weapon/weapon.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scene/pickups/pickup.tscn")

## 丢枪时向身后弹开的距离（像素），要大于玩家与拾取物的半径之和（20 + 26）。
const DROP_EJECT_DISTANCE: float = 64.0

const BOMB_RADIUS: float = 420.0
const BOMB_DAMAGE: int = 120

## 玩家槽位（0~3），由关卡在生成时写入。
@export var playerIndex: int = 0

## 复活无敌时间（秒）。
@export var invincibleTime: float = 2.5

## 初始必杀数量。
@export var bombCount: int = 2

## 枪包容量：能同时携带几把武器。满了再捡到别的枪，就替换手上这把。
@export var weaponSlots: int = 3

## 翻滚位移距离（像素）。匀速换算成瞬时速度 = 本值 / [member rollDuration]。
@export var rollDistance: float = 220.0

## 翻滚位移持续时间（秒）。
@export var rollDuration: float = 0.28

## 翻滚结束后的起身时间（秒）：这段既没位移也没无敌，读作「有代价的动作」。
@export var rollRecovery: float = 0.08

## 翻滚期间的**子弹**无敌时长（秒）。只挡子弹，接触伤害照吃（feature_design §3.5）。
@export var rollBulletImmunity: float = 0.20

## 翻滚体力格数，每格换一次翻滚。
@export var rollStaminaMax: int = 2

## 每格体力的回复时间（秒）。各格**独立计时**，不是攒着一起放。
@export var rollStaminaRecoverTime: float = 2.0

var characterType: int = -1
var maxHp: int = 100
var hp: int = 100
var moveSpeed: float = 280.0
## 枪包内容，顺序即循环切枪顺序；下标 [member currentWeaponIndex] 是手上这把。
var weapons: Array[Weapon] = []
## 手上武器的下标。
var currentWeaponIndex: int = 0
var isAlive: bool = true
var isInvincible: bool = false
## 翻滚的「只挡子弹」窗口：为 true 时子弹命中直接放过，接触伤害仍走 [method takeDamage]。
var isEvadingBullets: bool = false
## 本次翻滚的行进方向（起滚时定，途中不转向）。
var rollDirection: Vector2 = Vector2.ZERO
## 每格翻滚体力还剩多久回满（秒）；下标即格号，`<= 0` 表示这一格可用。
var staminaTimers: Array[float] = []
var aimDirection: Vector2 = Vector2.UP
var respawnPosition: Vector2 = Vector2.ZERO
## 允许活动的世界范围，由关卡随相机每帧更新。
var bounds: Rect2 = Rect2(-540, -960, 1080, 1920)

var invincibleTimer: float = 0.0
## 本次翻滚已进行的时长（秒），由 [method updateRoll] 累加。
var rollElapsed: float = 0.0

@onready var gun: Polygon2D = $Gun
@onready var weaponsRoot: Node2D = $Weapons
@onready var hitFlash: HitFlash = $HitFlash
@onready var stateMachine: StateMachine = $StateMachine
@onready var respawnTimer: Timer = $RespawnTimer


# ---- 自定义函数放前面 ----

## 用角色数据初始化；[param index] 为玩家槽位。
func setup(index: int, character: int) -> void:
	playerIndex = index
	characterType = character
	var data = Game.getCharacterData(index)
	maxHp = data.get("maxHp", 100)
	moveSpeed = data.get("speed", 280.0)
	hp = maxHp
	modulate = Game.getPlayerColor(index)
	staminaTimers.resize(rollStaminaMax)
	fillStamina()
	addWeapon(data.get("startWeapon", Game.WeaponType.PISTOL))


## 设置出生点并复位战斗状态。
func resetForSpawn(spawnPosition: Vector2) -> void:
	respawnPosition = spawnPosition
	global_position = spawnPosition
	hp = maxHp
	isAlive = true
	velocity = Vector2.ZERO
	show()
	startInvincible(invincibleTime)
	# 复活给满体力：刚落点就被集火却滚不动，读起来像 bug 而不是惩罚。
	fillStamina()
	stateMachine.transitionTo(&"Idle")


## 受伤；无敌或已阵亡时忽略。
## [param sourcePlayer] 是伤害来源的玩家槽位 —— 敌方子弹不关心它是谁，
## 但参数必须在，否则与 [method Enemy.takeDamage] 的统一调用会报「参数个数不符」。
func takeDamage(amount: int, sourcePlayer: int = -1) -> void:
	if not isAlive or isInvincible:
		return
	hp -= amount
	hitFlash.flash()
	if hp <= 0:
		hp = 0
		die()


## 被子弹命中。**翻滚的无敌帧只在这里生效**：返回 false 表示这一发被躲掉，
## 子弹继续飞、不掉血 —— 比"子弹被吃掉"更好懂。接触伤害与必杀不走这条路，照吃。
func takeBulletDamage(amount: int, sourcePlayer: int = -1) -> bool:
	if isEvadingBullets:
		return false
	takeDamage(amount, sourcePlayer)
	return true


## 阵亡：扣一条命，还有命则进 `Dead` 等复活，没命则进 `Eliminated` 出局。
func die() -> void:
	if not isAlive:
		return
	isAlive = false
	hide()
	Game.playerLives[playerIndex] = maxi(Game.playerLives[playerIndex] - 1, 0)
	died.emit(playerIndex)
	if Game.playerLives[playerIndex] > 0:
		stateMachine.transitionTo(&"Dead")
	else:
		stateMachine.transitionTo(&"Eliminated")


## 进入无敌状态。
func startInvincible(duration: float) -> void:
	isInvincible = true
	invincibleTimer = duration


## 手上这把武器。枪包开局即发一把手枪，之后只增或原地替换，所以不会为空。
func getCurrentWeapon() -> Weapon:
	return weapons[currentWeaponIndex]


## 手上武器的类型（[enum Game.WeaponType]），HUD 与掉落逻辑用。
func getCurrentWeaponType() -> int:
	return getCurrentWeapon().weaponType


## 入枪包：同款只补满弹药；有空位就新增并切到它；满了则替换手上这把（旧枪掉回地面）。
## [param carriedAmmo] 为 -1 表示按该武器满弹；>= 0 用于回捡玩家自己丢下的枪。
func addWeapon(newWeaponType: int, carriedAmmo: int = -1) -> void:
	for index in weapons.size():
		if weapons[index].weaponType == newWeaponType:
			weapons[index].refill()
			selectWeapon(index)
			return
	if weapons.size() < weaponSlots:
		weapons.append(createWeapon(newWeaponType, carriedAmmo))
		selectWeapon(weapons.size() - 1)
		return
	replaceWeapon(currentWeaponIndex, newWeaponType, true, carriedAmmo)


## 循环切枪；[param step] 取 +1 / -1，对应 next / prev 键。
func cycleWeapon(step: int) -> void:
	if weapons.size() < 2:
		return
	selectWeapon(wrapi(currentWeaponIndex + step, 0, weapons.size()))


## 指定手上武器并广播换枪。
func selectWeapon(index: int) -> void:
	currentWeaponIndex = index
	weaponChanged.emit(playerIndex, weapons[index].weaponType)


## 造一把武器挂进枪包容器。有特殊命中效果的武器在数据表里用 [code]scene[/code]
## 指向自己的继承场景（rocket / tesla），没写就用基类场景。
func createWeapon(newWeaponType: int, carriedAmmo: int = -1) -> Weapon:
	var weapon = instantiateWeaponScene(newWeaponType).instantiate() as Weapon

	weaponsRoot.add_child(weapon)
	weapon.setup(newWeaponType)
	# 回捡的枪带原来的余弹；无限弹武器不受影响。
	if carriedAmmo >= 0 and weapon.maxAmmo >= 0:
		weapon.ammo = mini(carriedAmmo, weapon.maxAmmo)
	weapon.ammoEmptied.connect(onWeaponAmmoEmptied)
	return weapon


## 取该类型的武器场景资源；表里路径写错时退回基类场景，至少不该让游戏崩掉。
func instantiateWeaponScene(newWeaponType: int) -> PackedScene:
	var scenePath = Game.getWeaponData(newWeaponType).get("scene", "")

	if scenePath == "":
		return WEAPON_SCENE
	var scene = load(scenePath) as PackedScene
	if scene == null:
		push_warning("PlayerCharacter: 武器场景不存在 %s" % scenePath)
		return WEAPON_SCENE
	return scene


## 原地换掉某一把。[param dropReplaced] 为 true 时被换下的那把**掉回地面可回捡**
## （满包捡新枪走这条）；为 false 直接释放（整包打光回落手枪，旧枪本来已空，掉地上只是垃圾）。
func replaceWeapon(index: int, newWeaponType: int, dropReplaced: bool = false, carriedAmmo: int = -1) -> void:
	var old = weapons[index]

	if dropReplaced:
		dropWeapon(old)
	old.queue_free()
	weapons[index] = createWeapon(newWeaponType, carriedAmmo)
	selectWeapon(index)


## 把武器丢成地面拾取物：保留剩余弹药，4 人谁先踩到算谁的。
func dropWeapon(weapon: Weapon) -> void:
	var drop = PICKUP_SCENE.instantiate() as Pickup

	drop.weaponType = weapon.weaponType
	drop.ammo = weapon.ammo
	# 往身后弹开一点：丢在脚下的枪会和玩家重叠，落地免疫期一过就被自己捡回，
	# 换枪就变成「丢 → 捡 → 再丢」的死循环。弹到碰撞半径之外即可断开。
	drop.global_position = global_position - aimDirection * DROP_EJECT_DISTANCE
	# 掉枪常在子弹命中的回调里触发（物理 flush 期间），入树必须延后。
	get_tree().current_scene.call_deferred("add_child", drop)


## 弹药包效果：补满手上这把；手上是无限弹（手枪）就改补包里下一把有弹量上限的枪，
## 免得玩家捡了却什么都没发生。
func refillCurrentWeapon() -> void:
	var current = getCurrentWeapon()

	if current.maxAmmo >= 0:
		current.refill()
		return
	for index in weapons.size():
		if weapons[index].maxAmmo >= 0:
			weapons[index].refill()
			return


## 打空兜底：包里别处还有弹就切过去；整包打光则把手上这把换成手枪，保证永远有的打。
func onWeaponAmmoEmptied(weapon: Weapon) -> void:
	for index in weapons.size():
		if index != currentWeaponIndex and weapons[index].hasAmmo():
			selectWeapon(index)
			return
	replaceWeapon(currentWeaponIndex, Game.WeaponType.PISTOL)


## 开火与切枪输入：连发枪按住即射，半自动枪要每次按下。
func handleWeaponInput() -> void:
	if InputManager.isWeaponNextJustPressed(playerIndex):
		cycleWeapon(1)
	if InputManager.isWeaponPrevJustPressed(playerIndex):
		cycleWeapon(-1)
	var weapon = getCurrentWeapon()
	var wantFire = (
			weapon.isAutomatic and InputManager.isFirePressed(playerIndex)
			or not weapon.isAutomatic and InputManager.isFireJustPressed(playerIndex)
	)
	if wantFire:
		weapon.fire(aimDirection, playerIndex)


## 回血，不超过上限。
func heal(amount: int) -> void:
	hp = mini(hp + amount, maxHp)


## 加分数（内部转发到 [Game]，方便敌人调用）。
func addScore(amount: int) -> void:
	Game.addScore(playerIndex, amount)


## 必杀：清掉身边一圈敌人，并短暂无敌。
func useBomb() -> void:
	if bombCount <= 0:
		return
	bombCount -= 1
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and global_position.distance_to(enemy.global_position) <= BOMB_RADIUS:
			if enemy.has_method("takeDamage"):
				enemy.takeDamage(BOMB_DAMAGE, playerIndex)
	startInvincible(maxf(invincibleTime, 1.0))
	bombUsed.emit(playerIndex)


## 翻滚（紧急规避）：站在 `Idle`、活着、且有一格体力才起得来（feature_design §3.5）。
func canRoll() -> bool:
	return isAlive and stateMachine.currentName() == &"Idle" and readyStaminaCount() > 0


## 起滚：吃掉一格体力，方向取当前输入（没输入就用瞄准方向），之后交给 `Roll` 状态推进。
func startRoll() -> void:
	if not canRoll() or not spendStamina():
		return
	var moveInput = InputManager.getMoveVector(playerIndex)

	rollDirection = moveInput.normalized() if moveInput.length_squared() > 0.01 else aimDirection
	stateMachine.transitionTo(&"Roll")


## Roll：位移 → 起身 → 回 `Idle`。翻滚与起身期间不调用 [method handleWeaponInput]，
## 所以开火 / 切枪 / 必杀自然被吞掉 —— 不许把翻滚当成滚动射击平台。
func updateRoll(delta: float) -> void:
	rollElapsed += delta
	velocity = rollDirection * (rollDistance / rollDuration) if rollElapsed <= rollDuration else Vector2.ZERO
	# 无敌帧只覆盖翻滚的前段，起身那一下是真有风险。
	isEvadingBullets = rollElapsed <= rollBulletImmunity
	move_and_slide()
	position = position.clamp(bounds.position, bounds.end)
	if rollElapsed >= rollDuration + rollRecovery:
		stateMachine.transitionTo(&"Idle")


## Roll 进入：重置计时并立刻开启子弹无敌（第一帧就该躲得到）。
func onRollEnter() -> void:
	rollElapsed = 0.0
	isEvadingBullets = true


## Roll 退出：关掉子弹无敌。之后哪怕刚好死在起身瞬间也是正常伤害。
func onRollExit() -> void:
	isEvadingBullets = false
	velocity = Vector2.ZERO


## 把体力全部回满（出生 / 复活用）。
func fillStamina() -> void:
	for index in staminaTimers.size():
		staminaTimers[index] = 0.0


## 现在有几格体力可用。
func readyStaminaCount() -> int:
	var count = 0
	for timer in staminaTimers:
		if timer <= 0.0:
			count += 1
	return count


## 第 [param index] 格体力的填充比例（1.0 = 可用；回复中按比例，HUD 画部分填充用）。
func getStaminaRatio(index: int) -> float:
	if index < 0 or index >= staminaTimers.size():
		return 0.0
	if staminaTimers[index] <= 0.0:
		return 1.0
	return 1.0 - staminaTimers[index] / rollStaminaRecoverTime


## 吃掉一格体力（取第一格已回满的）；没有可用格则返回 false。
func spendStamina() -> bool:
	for index in staminaTimers.size():
		if staminaTimers[index] <= 0.0:
			staminaTimers[index] = rollStaminaRecoverTime
			return true
	return false


## 各格独立回复，互不影响。
func updateStamina(delta: float) -> void:
	for index in staminaTimers.size():
		if staminaTimers[index] > 0.0:
			staminaTimers[index] = maxf(staminaTimers[index] - delta, 0.0)


## Idle：移动 / 瞄准 / 开火 / 必杀，外加双击方向起滚。
func updateIdle() -> void:
	if InputManager.isRollJustPressed(playerIndex):
		startRoll()
		return
	var moveInput = InputManager.getMoveVector(playerIndex)
	velocity = moveInput * moveSpeed
	move_and_slide()
	position = position.clamp(bounds.position, bounds.end)
	updateAim(moveInput)
	handleWeaponInput()
	if InputManager.isBombJustPressed(playerIndex):
		useBomb()


## Dead 进入：起复活倒计时。计时交给 [member respawnTimer]，状态本身不需要每帧更新。
func onDeadEnter() -> void:
	velocity = Vector2.ZERO
	respawnTimer.start()


## Dead 退出：停掉倒计时，避免下一次阵亡时它还在跑。
func onDeadExit() -> void:
	respawnTimer.stop()


## Eliminated 进入：出局终态。扣命与 [signal died] 已由 [method die] 做完，这里只补终态信号。
func onEliminatedEnter() -> void:
	velocity = Vector2.ZERO
	respawnTimer.stop()
	eliminated.emit(playerIndex)


## 复活倒计时结束：回到出生点（[method resetForSpawn] 会把状态切回 `Idle`）。
func onRespawnTimeout() -> void:
	resetForSpawn(respawnPosition)


## 与状态无关的每帧处理：整包武器的冷却、无敌计时与闪烁、翻滚体力回复。
func updateCommon(delta: float) -> void:
	for weapon in weapons:
		weapon.updateCooldown(delta)
	updateInvincible(delta)
	updateStamina(delta)


# ---- 内部函数放后面 ----

func updateInvincible(delta: float) -> void:
	if not isInvincible:
		return
	invincibleTimer -= delta
	modulate.a = 0.4 if int(invincibleTimer * 10.0) % 2 == 0 else 1.0
	if invincibleTimer <= 0.0:
		isInvincible = false
		modulate.a = 1.0


func updateAim(moveInput: Vector2) -> void:
	if moveInput.length_squared() > 0.01:
		aimDirection = moveInput.normalized()
	gun.rotation = aimDirection.angle() + PI * 0.5


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	add_to_group("player")
	respawnTimer.timeout.connect(onRespawnTimeout)


func _physics_process(delta: float) -> void:
	# 状态相关的行为由 StateMachine 子节点分发（它的 _physics_process 在本函数之后执行）。
	updateCommon(delta)
