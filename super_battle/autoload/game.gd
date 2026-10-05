extends Node
## 全局游戏状态单例（Autoload 名 [code]Game[/code]）。
##
## 只存放**跨场景共享的状态**与**静态数据表**；具体玩法逻辑放在各自的场景脚本里。
## 遵循「数据与逻辑分离」：新增角色 / 武器只需往下面的字典里加一条，不改逻辑。
##
## 注意：Autoload 的枚举不是编译期常量，本文件内部可以 `const` 引用自身枚举，
## 但其它脚本用 [member Game.WeaponType] 做 key 时只能写 `var`，不能写 `const`。

## 新玩家加入（[param playerIndex] 为 0~3 的玩家槽位）。
signal playerJoined(playerIndex: int)

## 玩家退出。
signal playerLeft(playerIndex: int)

## 分数变化。
signal scoreChanged(playerIndex: int, score: int)

enum BulletOwner {
	PLAYER,
	ENEMY,
}

enum WeaponType {
	PISTOL,
	MACHINE_GUN,
	SHOTGUN,
	ROCKET,
	FLAME,
}

enum CharacterType {
	COMMANDO,
	GUNNER,
	DEMO,
	MEDIC,
}

const MAX_PLAYERS: int = 4

## 4 名玩家固定配色，HUD、角色描边、复活点标记共用，下标即玩家槽位。
const PLAYER_COLORS: Array[Color] = [
	Color(0.91, 0.3, 0.24),
	Color(0.29, 0.6, 0.95),
	Color(0.4, 0.83, 0.42),
	Color(0.95, 0.78, 0.25),
]

## 4 名可选角色的属性。数值差异只在数据里，玩家脚本不写角色分支。
const characterInfo = {
	CharacterType.COMMANDO: {
		"nameKey": "_Character_commando",
		"descKey": "_Character_commandoDesc",
		"speed": 280.0,
		"maxHp": 100,
		"startWeapon": WeaponType.PISTOL,
		"iconColor": PLAYER_COLORS[0],
	},
	CharacterType.GUNNER: {
		"nameKey": "_Character_gunner",
		"descKey": "_Character_gunnerDesc",
		"speed": 220.0,
		"maxHp": 130,
		"startWeapon": WeaponType.MACHINE_GUN,
		"iconColor": PLAYER_COLORS[1],
	},
	CharacterType.DEMO: {
		"nameKey": "_Character_demo",
		"descKey": "_Character_demoDesc",
		"speed": 250.0,
		"maxHp": 110,
		"startWeapon": WeaponType.SHOTGUN,
		"iconColor": PLAYER_COLORS[2],
	},
	CharacterType.MEDIC: {
		"nameKey": "_Character_medic",
		"descKey": "_Character_medicDesc",
		"speed": 300.0,
		"maxHp": 90,
		"startWeapon": WeaponType.PISTOL,
		"iconColor": PLAYER_COLORS[3],
	},
}

## 武器数据表。[code]ammo[/code] 为 -1 表示无限弹药。
## [code]spreadDeg[/code] 为散射总角度，多弹丸时每颗均分在散射区间内。
const weaponInfo = {
	WeaponType.PISTOL: {
		"nameKey": "_Weapon_pistol",
		"damage": 20,
		"fireInterval": 0.22,
		"bulletSpeed": 900.0,
		"bulletCount": 1,
		"spreadDeg": 0.0,
		"ammo": -1,
		"pierce": 0,
	},
	WeaponType.MACHINE_GUN: {
		"nameKey": "_Weapon_machineGun",
		"damage": 12,
		"fireInterval": 0.08,
		"bulletSpeed": 1000.0,
		"bulletCount": 1,
		"spreadDeg": 6.0,
		"ammo": 300,
		"pierce": 0,
	},
	WeaponType.SHOTGUN: {
		"nameKey": "_Weapon_shotgun",
		"damage": 14,
		"fireInterval": 0.6,
		"bulletSpeed": 820.0,
		"bulletCount": 5,
		"spreadDeg": 32.0,
		"ammo": 60,
		"pierce": 0,
	},
	WeaponType.ROCKET: {
		"nameKey": "_Weapon_rocket",
		"damage": 90,
		"fireInterval": 0.9,
		"bulletSpeed": 620.0,
		"bulletCount": 1,
		"spreadDeg": 0.0,
		"ammo": 20,
		"pierce": 1,
	},
	WeaponType.FLAME: {
		"nameKey": "_Weapon_flame",
		"damage": 6,
		"fireInterval": 0.05,
		"bulletSpeed": 520.0,
		"bulletCount": 1,
		"spreadDeg": 14.0,
		"ammo": 400,
		"pierce": 2,
	},
}

## 已加入的玩家槽位（0~3），按加入顺序排列。
var joinedPlayers: Array[int] = []

## 每个槽位选定的角色，-1 表示该槽位未加入。
var selectedCharacters: Array[int] = [-1, -1, -1, -1]

## 每个槽位的累计分数。
var playerScores: Array[int] = [0, 0, 0, 0]

## 每个槽位的剩余生命数（阵亡扣 1，全员归零时进入续关）。
var playerLives: Array[int] = [2, 2, 2, 2]


func _ready() -> void:
	resetSession()


# ---- 自定义函数放前面 ----

## 复位一局的所有玩家状态，标题界面回到选人前调用。
func resetSession() -> void:
	joinedPlayers.clear()
	selectedCharacters = [-1, -1, -1, -1]
	playerScores = [0, 0, 0, 0]
	playerLives = [2, 2, 2, 2]


## 让某个槽位加入并选定角色；槽位已占用或满员时返回 false。
func joinPlayer(playerIndex: int, characterType: int) -> bool:
	if joinedPlayers.size() >= MAX_PLAYERS:
		return false
	if joinedPlayers.has(playerIndex):
		return false
	joinedPlayers.append(playerIndex)
	selectedCharacters[playerIndex] = characterType
	playerJoined.emit(playerIndex)
	return true


## 某个槽位退出。
func leavePlayer(playerIndex: int) -> void:
	if not joinedPlayers.has(playerIndex):
		return
	joinedPlayers.erase(playerIndex)
	selectedCharacters[playerIndex] = -1
	playerLeft.emit(playerIndex)


## 某个槽位是否已加入。
func isPlayerJoined(playerIndex: int) -> bool:
	return joinedPlayers.has(playerIndex)


## 取角色数据；未选角色时返回空字典。
func getCharacterData(playerIndex: int) -> Dictionary:
	var characterType = selectedCharacters[playerIndex]
	if characterType == -1:
		return {}
	return characterInfo.get(characterType, {})


## 取武器数据；类型非法时返回空字典。
func getWeaponData(weaponType: int) -> Dictionary:
	return weaponInfo.get(weaponType, {})


## 累加分数并广播。
func addScore(playerIndex: int, amount: int) -> void:
	if playerIndex < 0 or playerIndex >= MAX_PLAYERS:
		return
	playerScores[playerIndex] += amount
	scoreChanged.emit(playerIndex, playerScores[playerIndex])


## 取玩家配色。
func getPlayerColor(playerIndex: int) -> Color:
	return PLAYER_COLORS[playerIndex % PLAYER_COLORS.size()]
