extends Node
## 关卡数据单例（Autoload 名 [code]StageData[/code]）。
##
## 关卡表、敌人场景表都是纯数据，新增内容只加条目、不改逻辑。
## 当前选中的关卡编号存在 [member currentLevel]，由选人界面写入、关卡场景读取。

## 关卡编号 -> 配置。
## [code]length[/code] 是关卡纵向长度（像素），相机与流程进度据此计算。
## [code]enemyPool[/code] 是敌人 id 列表，刷怪器从中随机取用。
const levelInfo = {
	1: {
		"nameKey": "_Level_1",
		"scene": "res://scene/level/level_1.tscn",
		"length": 6000.0,
		"enemyPool": ["grunt"],
		"enemyTotal": 40,
		"spawnInterval": 1.1,
	},
	2: {
		"nameKey": "_Level_2",
		"scene": "res://scene/level/level_1.tscn",
		"length": 8000.0,
		"enemyPool": ["grunt"],
		"enemyTotal": 60,
		"spawnInterval": 0.9,
	},
	3: {
		"nameKey": "_Level_3",
		"scene": "res://scene/level/level_1.tscn",
		"length": 10000.0,
		"enemyPool": ["grunt"],
		"enemyTotal": 80,
		"spawnInterval": 0.75,
	},
}

## 敌人 id -> 场景路径。刷怪器用 id 查表实例化。
const enemyScenes = {
	"grunt": "res://scene/enemy/grunt.tscn",
}

## 当前选中的关卡编号（1 起）。
var currentLevel: int = 1


# ---- 自定义函数放前面 ----

## 取关卡配置；编号非法时返回第 1 关。
func getLevelData(levelNumber: int) -> Dictionary:
	return levelInfo.get(levelNumber, levelInfo[1])


## 取关卡场景路径。
func getLevelScenePath(levelNumber: int) -> String:
	return getLevelData(levelNumber)["scene"]


## 关卡总数。
func getLevelCount() -> int:
	return levelInfo.size()


## 取敌人场景路径；id 非法时返回空字符串。
func getEnemyScenePath(enemyId: String) -> String:
	return enemyScenes.get(enemyId, "")


## 取某关的敌人生成参数（数量 / 间隔 / 池）。
func getSpawnConfig(levelNumber: int) -> Dictionary:
	var data = getLevelData(levelNumber)
	return {
		"enemyPool": data["enemyPool"],
		"enemyTotal": data["enemyTotal"],
		"spawnInterval": data["spawnInterval"],
		"length": data["length"],
	}
