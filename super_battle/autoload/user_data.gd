extends Node
## 玩家存档单例（Autoload 名 [code]UserData[/code]）。
##
## 用 [ConfigFile] 存到 `user://user_data.cfg`，只存**设置**与**解锁进度**，
## 不存一局内的临时状态（那些属于 [Game]）。
##
## 读写统一走 [method loadData] / [method saveData]；改动字段后调用 [method saveData] 持久化。

signal dataLoaded

const SAVE_PATH: String = "user://user_data.cfg"

## 已解锁的关卡编号（1 起）。
var unlockedLevels: int = 1

## 每关最高评价（0~3 星），key 为关卡编号。
var levelStars: Dictionary = {}

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
	unlockedLevels = config.get_value("progress", "unlockedLevels", unlockedLevels)
	levelStars = config.get_value("progress", "levelStars", levelStars)
	musicVolume = config.get_value("audio", "musicVolume", musicVolume)
	sfxVolume = config.get_value("audio", "sfxVolume", sfxVolume)
	language = config.get_value("system", "language", language)
	dataLoaded.emit()


## 写入磁盘，失败时打印错误（不中断游戏）。
func saveData() -> void:
	var config = ConfigFile.new()
	config.set_value("progress", "unlockedLevels", unlockedLevels)
	config.set_value("progress", "levelStars", levelStars)
	config.set_value("audio", "musicVolume", musicVolume)
	config.set_value("audio", "sfxVolume", sfxVolume)
	config.set_value("system", "language", language)
	var error = config.save(SAVE_PATH)
	if error != OK:
		push_error("保存存档失败，错误码：%d" % error)


## 记录某一关通过，推进解锁进度并保存。
func completeLevel(levelNumber: int, stars: int) -> void:
	unlockedLevels = maxi(unlockedLevels, levelNumber + 1)
	levelStars[levelNumber] = maxi(levelStars.get(levelNumber, 0), stars)
	saveData()
