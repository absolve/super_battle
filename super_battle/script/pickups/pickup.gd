class_name Pickup
extends Area2D
## 地面拾取物基类：武器箱、弹药包，以及玩家被换下后掉回地面的枪。
##
## 碰撞口径：自己在 pickup 层（16）、掩码 player（1），**谁先踩到算谁的**，4 人共享
## （与 Boss 空投同一套规则，见 feature_design §4.5）。
##
## 生命周期：和敌人共用一条回收线 —— 关卡把相机后方的卸载线写进
## [member despawnForward] / [member despawnLine]，落到线后就消失。
## 不做计时消失（避免「错过就没了」的挫败），也不会越攒越多。
## 摆在房间里的拾取物是房间子节点，本来就随房间一起释放。

enum PickupType {
	WEAPON,
	AMMO_PACK,
}

## 拾取物类型。
@export var pickupType: PickupType = PickupType.WEAPON

## 武器类的武器类型（[enum Game.WeaponType]）；弹药包忽略此项。
@export var weaponType: int = Game.WeaponType.PISTOL

## 武器类携带的弹药量；-1 = 按该武器的满弹量（武器箱与空投走这条）。
## 玩家被换下的枪会把剩余弹药写进来，回捡时原样带回。
@export var ammo: int = -1

## 占位色块颜色：武器箱金橙、弹药包冷白钢（feature_design §4.1 的颜色区分）。
@export var tintColor: Color = Color(0.976, 0.639, 0.106, 1)

## 回收线方向（推进方向）与投影，由关卡写入；没写就永不回收。
var despawnForward: Vector2 = Vector2.UP

var despawnLine: float = -100000.0

## 落地后过多久才可被拾起（秒）。玩家丢下的枪是在脚下生成的，
## 不隔一下就立刻被自己捡回，换枪会变成「丢 → 捡 → 再丢」的死循环。
@export var collectDelay: float = 0.35

## 已被拾取，避免同一帧多个玩家重复触发结算。
var collected: bool = false

## 距离可拾取的剩余秒数。
var armLeft: float = 0.0

@onready var nameLabel: Label = $LabelPivot/NameLabel
@onready var labelPivot: Node2D = $LabelPivot
@onready var body: Polygon2D = $Body


# ---- 自定义函数放前面 ----

## 被玩家捡到时的结算。
func collect(player: PlayerCharacter) -> void:
	if collected:
		return
	collected = true
	if pickupType == PickupType.AMMO_PACK:
		player.refillCurrentWeapon()
	else:
		player.addWeapon(weaponType, ammo)
	queue_free()


## 显示名：武器用武器表的键，弹药包用自己的键。
func getDisplayName() -> String:
	if pickupType == PickupType.AMMO_PACK:
		return tr("_Pickup_ammoPack")
	return tr(Game.getWeaponData(weaponType).get("nameKey", ""))


func onBodyEntered(body: Node) -> void:
	var player = body as PlayerCharacter

	# 阵亡（等复活）期间人是藏着的，不该顺手捡到东西。
	if player == null or not player.isAlive:
		return
	collect(player)


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(onBodyEntered)
	armLeft = collectDelay
	monitoring = collectDelay <= 0.0
	var levelRoot = get_tree().current_scene
	if levelRoot != null and levelRoot.has_method("getDespawnLine"):
		despawnForward = levelRoot.getDespawnForward()
		despawnLine = levelRoot.getDespawnLine()
	body.color = tintColor
	nameLabel.text = getDisplayName()
	# 房间可能整棵旋转（纵向搭的房间用在横向关），文字挂在独立支点上转回正方向：
	# Label 是 Control，自己没有 global_rotation，只能由父级 Node2D 反着转。
	labelPivot.global_rotation = -global_rotation


func _physics_process(delta: float) -> void:
	if armLeft > 0.0:
		armLeft -= delta
		if armLeft <= 0.0:
			# 物理帧里改监测状态必须走 deferred，否则引擎报「flushing queries」。
			set_deferred("monitoring", true)
	if global_position.dot(despawnForward) < despawnLine:
		queue_free()
