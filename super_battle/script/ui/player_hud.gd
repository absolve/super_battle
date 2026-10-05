extends Control
## 单个玩家的 HUD：血量 / 生命数 / 当前武器 / 分数。
##
## 4 名玩家各一个实例，由关卡按槽位摆到屏幕四角。

var playerIndex: int = 0
var player: PlayerCharacter = null

@onready var panel: ColorRect = $Panel
@onready var accent: ColorRect = $Accent
@onready var nameLabel: Label = $NameLabel
@onready var healthBar: ProgressBar = $HealthBar
@onready var infoLabel: Label = $InfoLabel


# ---- 自定义函数放前面 ----

## 绑定玩家并向其读取初始数据。
func setup(target: PlayerCharacter) -> void:
	player = target
	playerIndex = target.playerIndex
	var playerColor = Game.getPlayerColor(playerIndex)
	accent.color = playerColor
	healthBar.modulate = playerColor
	var characterData = Game.getCharacterData(playerIndex)
	nameLabel.text = "P%d  %s" % [playerIndex + 1, tr(characterData.get("nameKey", ""))]
	healthBar.max_value = player.maxHp
	refresh()


## 刷新动态数值，数值变化时调用（也每帧调用以保证实时）。
func refresh() -> void:
	if player == null or not is_instance_valid(player):
		return
	healthBar.value = player.hp
	var weaponData = Game.getWeaponData(player.weaponType)
	infoLabel.text = "%s   命 x%d   分 %d" % [
		tr(weaponData.get("nameKey", "")),
		Game.playerLives[playerIndex],
		Game.playerScores[playerIndex],
	]


# ---- Godot 内置虚函数放最后 ----

func _process(_delta: float) -> void:
	refresh()
