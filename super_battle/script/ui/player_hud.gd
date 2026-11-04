extends Control
## 单个玩家的信息卡片：名字 / 生命数 / 当前生命值 / 持有武器 / 分数 / 翻滚体力。
##
## 4 名玩家各一个实例，由关卡加进 `HudLayer/HudBar` 容器；
## 卡片宽度交给容器均分（根节点 `size_flags_horizontal = 3`），所以内部控件全部用锚点排版，
## 换分辨率或改成 2 人局都不用手调坐标。

## 阵亡 / 出局时卡片的压暗程度（活着是 1.0）。
const DIM_ALPHA: float = 0.45

## 还没回满的体力格用这个灰（与卡片描边同色，占位阶段不引新色板）。
const STAMINA_WAITING_COLOR: Color = Color("4a5462")

## 一格体力条的尺寸（像素）。
const STAMINA_PIP_SIZE: Vector2 = Vector2(38.0, 14.0)

@onready var accent: ColorRect = $Accent
@onready var nameLabel: Label = $NameLabel
@onready var livesLabel: Label = $LivesLabel
@onready var healthBar: ProgressBar = $HealthBar
@onready var hpLabel: Label = $HpLabel
@onready var weaponLabel: Label = $WeaponLabel
@onready var scoreLabel: Label = $ScoreLabel
@onready var staminaLabel: Label = $StaminaLabel
@onready var staminaRow: HBoxContainer = $StaminaRow

var playerIndex: int = 0
var player: PlayerCharacter = null

## 体力格条，下标与 [method PlayerCharacter.getStaminaRatio] 一致；数量由玩家的体力上限决定。
var staminaPips: Array[ProgressBar] = []


# ---- 自定义函数放前面 ----

## 绑定玩家，写入不随帧变化的部分（配色与名字）。
func setup(target: PlayerCharacter) -> void:
	player = target
	playerIndex = target.playerIndex
	var playerColor = Game.getPlayerColor(playerIndex)

	accent.color = playerColor
	nameLabel.modulate = playerColor
	healthBar.modulate = playerColor
	var characterData = Game.getCharacterData(playerIndex)
	nameLabel.text = "P%d  %s" % [playerIndex + 1, tr(characterData.get("nameKey", ""))]
	healthBar.max_value = player.maxHp
	staminaLabel.text = tr("_HUD_Stamina")
	buildStaminaPips(playerColor)
	refresh()


## 按玩家的体力上限生成体力格：上限可能因简单模式 / 角色被动而变，所以不写死在场景里。
func buildStaminaPips(playerColor: Color) -> void:
	for child in staminaRow.get_children():
		staminaRow.remove_child(child)
		child.free()
	staminaPips.clear()
	for index in player.rollStaminaMax:
		var pip = ProgressBar.new()

		pip.name = "Pip%d" % index
		pip.custom_minimum_size = STAMINA_PIP_SIZE
		pip.max_value = 100.0
		pip.value = 100.0
		pip.show_percentage = false
		staminaRow.add_child(pip)
		staminaPips.append(pip)
		pip.modulate = playerColor


## 刷新动态数值；每帧调用，省掉到处连信号的麻烦。
func refresh() -> void:
	if player == null or not is_instance_valid(player):
		return
	var weapon = player.getCurrentWeapon()

	healthBar.value = player.hp
	hpLabel.text = "%d/%d" % [player.hp, player.maxHp]
	weaponLabel.text = "%s  %s" % [weapon.getDisplayName(), weapon.getAmmoText()]
	livesLabel.text = "%s x%d" % [tr("_HUD_Lives"), Game.playerLives[playerIndex]]
	scoreLabel.text = "%s %d" % [tr("_HUD_Score"), Game.playerScores[playerIndex]]
	refreshStamina()
	modulate.a = 1.0 if player.isAlive else DIM_ALPHA


## 体力格：满格用槽位色，回复中变灰并按剩余时间显示部分填充。
func refreshStamina() -> void:
	for index in staminaPips.size():
		var ratio = player.getStaminaRatio(index)
		var pip = staminaPips[index]

		pip.value = ratio * 100.0
		pip.modulate = Game.getPlayerColor(playerIndex) if ratio >= 1.0 else STAMINA_WAITING_COLOR


# ---- Godot 内置虚函数放最后 ----

func _process(_delta: float) -> void:
	refresh()
