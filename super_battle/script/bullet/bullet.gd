extends Area2D
## 子弹基类：直线飞行、命中扣血、可穿透。
##
## 玩家子弹与敌方子弹共用本脚本，区别只在场景里设置的 [member ownerType] 与碰撞层/掩码。

## 命中目标、即将消失时发出。
signal hitTarget(target: Node)

## 飞行速度（像素 / 秒）。
@export var speed: float = 900.0

## 伤害值，由 [method setup] 的调用方按武器数据覆盖。
@export var damage: int = 20

## 归属方，决定入哪个分组。
@export var ownerType: int = Game.BulletOwner.PLAYER

## 可穿透的额外目标数（0 = 命中即消失）。
@export var pierce: int = 0

## 存活时间上限（秒），兜底回收飞出画面的子弹。
@export var lifeTime: float = 2.5

var direction: Vector2 = Vector2.UP

## 发射者槽位（玩家子弹用于计分；-1 表示敌方或无归属）。
var sourcePlayer: int = -1

var piercedCount: int = 0
var lifeLeft: float = 0.0


# ---- 自定义函数放前面 ----

## 初始化方向与归属；应在加入场景树之前调用。
func setup(newDirection: Vector2, newSourcePlayer: int = -1) -> void:
	direction = newDirection.normalized()
	sourcePlayer = newSourcePlayer
	rotation = direction.angle() + PI * 0.5


## 命中处理：扣血、记录击杀人、按穿透决定是否回收。
func onBodyEntered(body: Node) -> void:
	if body.has_method("takeDamage"):
		body.takeDamage(damage, sourcePlayer)
	hitTarget.emit(body)
	if piercedCount >= pierce:
		queue_free()
		return
	piercedCount += 1


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	lifeLeft = lifeTime
	if ownerType == Game.BulletOwner.PLAYER:
		add_to_group("playerBullet")
	else:
		add_to_group("enemyBullet")
	body_entered.connect(onBodyEntered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifeLeft -= delta
	if lifeLeft <= 0.0:
		queue_free()
