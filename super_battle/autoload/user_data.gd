extends Node
## 玩家存档单例（Autoload 名 [code]UserData[/code]）。
##
## 用 [ConfigFile] 存到 `user://user_data.cfg`，只存**设置**与**解锁进度**，
## 不存一局内的临时状态（那些属于 [Game]）。
##
## 读写统一走 [method loadData] / [method saveData]；改动字段后调用 [method saveData] 持久化。

signal dataLoaded

const SAVE_PATH: String = "user://user_data.cfg"

## 已通关的小关编号（区代号 × 100 + 小关序号）。**战役进度只由这一张表推导**：
## 当前区 = 第一个还没全通的区，当前小关 = 当前区里第一个还没通的小关。
var clearedLevels: Array[int] = []

## 每个小关的最高评价（0~3 星），key 为小关编号。
var levelStars: Dictionary = {}

## 累计续关次数：只计入结算评级，**不提高难度**（level_design §6）。
var continueCount: int = 0

## 音乐音量（0.0~1.0）。
var musicVolume: float = 0.8

## 音效音量（0.0~1.0）。
var sfxVolume: float = 0.9

## 语言代码，如 "zh" / "en"。
var language: String = "zh"


func _ready() -> void:
	loadData()


# ---- 自定义函数放前面 ----

## 从磁盘读取存档；文件不存在时保持默认值。
func loadData() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	# ConfigFile 读回来的是无类型 Array，逐个转成 int 才能塞进 clearedLevels。
	clearedLevels.clear()
	for levelCode in config.get_value("progress", "clearedLevels", []):
		clearedLevels.append(int(levelCode))
	levelStars = config.get_value("progress", "levelStars", levelStars)
	continueCount = config.get_value("progress", "continueCount", continueCount)
	musicVolume = config.get_value("audio", "musicVolume", musicVolume)
	sfxVolume = config.get_value("audio", "sfxVolume", sfxVolume)
	language = config.get_value("system", "language", language)
	dataLoaded.emit()


## 写入磁盘，失败时打印错误（不中断游戏）。
func saveData() -> void:
	var config = ConfigFile.new()
	config.set_value("progress", "clearedLevels", clearedLevels)
	config.set_value("progress", "levelStars", levelStars)
	config.set_value("progress", "continueCount", continueCount)
	config.set_value("audio", "musicVolume", musicVolume)
	config.set_value("audio", "sfxVolume", sfxVolume)
	config.set_value("system", "language", language)
	var error = config.save(SAVE_PATH)
	if error != OK:
		push_error("保存存档失败，错误码：%d" % error)


## 记录某个小关通过：写进通关表、取最高星，并保存。
func completeLevel(levelCode: int, stars: int) -> void:
	if not clearedLevels.has(levelCode):
		clearedLevels.append(levelCode)
	levelStars[levelCode] = maxi(int(levelStars.get(levelCode, 0)), stars)
	saveData()


## 某个小关是否已通关。
func isLevelCleared(levelCode: int) -> bool:
	return clearedLevels.has(levelCode)


## 某个区是否已控制（该区 4 个小关全通）。
func isDistrictCleared(districtCode: int) -> bool:
	for levelCode in StageData.getLevelCodes(districtCode):
		if not isLevelCleared(levelCode):
			return false
	return true


## 已控制的区数（按推进顺序从头数起 —— 顺序固定，所以只能连续地往后数）。
func getClearedDistrictCount() -> int:
	var count = 0
	for districtCode in StageData.getDistrictCodesByOrder():
		if not isDistrictCleared(districtCode):
			return count
		count += 1
	return count


## 整条战役是否打完（六区全控）。
func isCampaignFinished() -> bool:
	return getClearedDistrictCount() >= StageData.districtInfo.size()


## 当前区代号；全通后仍返回决战区，免得大地图没有焦点。
func getCurrentDistrictCode() -> int:
	var ordered = StageData.getDistrictCodesByOrder()
	var index = mini(getClearedDistrictCount(), ordered.size() - 1)

	return ordered[index]


## 当前要打的小关 = 当前区里第一个还没通的小关；全区已通时返回 0。
func getCurrentLevelCode() -> int:
	for levelCode in StageData.getLevelCodes(getCurrentDistrictCode()):
		if not isLevelCleared(levelCode):
			return levelCode
	return 0


## 取某关星数（没打过 = 0）。
func getLevelStars(levelCode: int) -> int:
	return int(levelStars.get(levelCode, 0))
