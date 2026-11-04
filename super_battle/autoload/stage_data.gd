extends Node
## 战役数据单例（Autoload 名 [code]StageData[/code]）。
##
## 三层结构：**区 → 小关 → 房间**（level_design §1 / §8）。区表和小关表都是纯数据，
## 新增内容只加条目、不改逻辑；房间表再把小关拆成一串可复用的房间场景。
##
## 小关编号 = **区代号 × 100 + 小关序号**（区代号按地名固定，与推进顺序无关）；
## 推进顺序由区表的 [code]order[/code] 决定，玩家不能选路，只能按序打。
## 目前**只配了马尾区（2xx）的内容**，其余区在区表里有名字（大地图要点得出来），
## 但没有小关数据 —— 大地图按 [method isLevelPlayable] 读作「待做」。
##
## 当前选中的小关编号存在 [member currentLevel]，由大地图写入、关卡场景读取。

## 区代号 -> 配置。区代号按地名固定：长乐 1、马尾 2、晋安 3、仓山 4、台江 5、鼓楼 6。
## [code]order[/code] 是剧本推进顺序（马尾 = 1 起点，鼓楼 = 6 决战）。
const districtInfo = {
	2: {
		"order": 1,
		"nameKey": "_District_2",
		"levels": [201, 202, 203, 209],
	},
	1: {
		"order": 2,
		"nameKey": "_District_1",
		"levels": [101, 102, 103, 109],
	},
	4: {
		"order": 3,
		"nameKey": "_District_4",
		"levels": [401, 402, 403, 409],
	},
	5: {
		"order": 4,
		"nameKey": "_District_5",
		"levels": [501, 502, 503, 509],
	},
	3: {
		"order": 5,
		"nameKey": "_District_3",
		"levels": [301, 302, 303, 309],
	},
	6: {
		"order": 6,
		"nameKey": "_District_6",
		"levels": [601, 602, 603, 609],
	},
}

## 小关编号 -> 配置。
## [code]scrollAxis[/code]：[code]"vertical"[/code] = 画面向上推进，[code]"horizontal"[/code] = 向右。
## [code]rooms[/code] 是按推进顺序的房间 id 列表（同一间可以重复用）；**空列表 = 本关内容还没做**，
## 大地图与连打流程据此拦住玩家，不会把人送进一张空图。
## [code]checkpointRooms[/code] 是检查点所在房间下标（关首固定一个，较难的关在中段再加）。
## 摆链子时的硬约束：**[code]depot[/code] 带尽头墙，只能放在链尾**，放中间会把推进路堵死。
const levelInfo = {
	201: {
		"nameKey": "_Level_201",
		"scene": "res://scene/level/level_1.tscn",
		"scrollAxis": "vertical",
		"rooms": ["start", "cover", "open", "cover", "cross", "cover", "depot"],
		"checkpointRooms": [0, 3],
	},
	202: {
		"nameKey": "_Level_202",
		"scene": "res://scene/level/level_1.tscn",
		"scrollAxis": "horizontal",
		"rooms": ["start", "open", "cross", "open", "cover", "cross", "open", "depot"],
		"checkpointRooms": [0, 3],
	},
	# 载具关：等载具系统（M5）做完再填房间清单。
	203: {
		"nameKey": "_Level_203",
		"scene": "res://scene/level/level_1.tscn",
		"scrollAxis": "horizontal",
		"rooms": [],
		"checkpointRooms": [0],
	},
	# Boss 关：等 Boss 框架（M8）与空投节奏，房间清单同样留空。
	209: {
		"nameKey": "_Level_209",
		"scene": "res://scene/level/level_1.tscn",
		"scrollAxis": "vertical",
		"rooms": [],
		"checkpointRooms": [0],
	},
}

## 房间 id -> 配置。
## [code]alongLength[/code] 是房间沿推进方向的长度（像素），由房间链总长决定关卡长度。
## [code]lateralLength[/code] 是房间横向可用宽度（像素），决定相机与玩家能被夹进来的范围；
## 不写就按相机视野宽铺满。尺寸只写在这里，房间场景内**不重复声明**，避免两处不一致。
const roomInfo = {
	"start": {
		"scene": "res://scene/level/rooms/room_start.tscn",
		"alongLength": 1080.0,
	},
	"open": {
		"scene": "res://scene/level/rooms/room_open.tscn",
		"alongLength": 1400.0,
	},
	"cover": {
		"scene": "res://scene/level/rooms/room_cover.tscn",
		"alongLength": 1080.0,
		"lateralLength": 1664.0,
	},
	"cross": {
		"scene": "res://scene/level/rooms/room_cross.tscn",
		"alongLength": 1080.0,
	},
	"depot": {
		"scene": "res://scene/level/rooms/room_depot.tscn",
		"alongLength": 1400.0,
		"lateralLength": 2560.0,
	},
}

## 敌人 id -> 场景路径。
const enemyScenes = {
	"grunt": "res://scene/enemy/grunt.tscn",
	"heavy": "res://scene/enemy/heavy.tscn",
	"drifter": "res://scene/enemy/drifter.tscn",
	"turret": "res://scene/enemy/turret.tscn",
}

## 当前选中的小关编号（区代号 × 100 + 小关序号）。
var currentLevel: int = 201


# ---- 自定义函数放前面 ----

## 区代号列表，**按剧本推进顺序**排（马尾 → 长乐 → 仓山 → 台江 → 晋安 → 鼓楼）。
func getDistrictCodesByOrder() -> Array[int]:
	var result: Array[int] = []
	for districtCode in districtInfo.keys():
		result.append(districtCode)
	result.sort_custom(compareDistrictByOrder)
	return result


## [method Array.sort_custom] 用的比较函数：[code]order[/code] 小的排在前面。
func compareDistrictByOrder(a: int, b: int) -> bool:
	return getDistrictData(a).get("order", 0) < getDistrictData(b).get("order", 0)


## 取区配置；区代号非法时返回空字典。
func getDistrictData(districtCode: int) -> Dictionary:
	return districtInfo.get(districtCode, {})


## 取区下的小关编号（就按表里写的顺序，即区内推进顺序）。
func getLevelCodes(districtCode: int) -> Array[int]:
	var result: Array[int] = []
	for levelCode in getDistrictData(districtCode).get("levels", []):
		result.append(levelCode)
	return result


## 小关编号 → 区代号（编号本身就是区代号 × 100 + 小关序号）。
func getDistrictCodeOfLevel(levelCode: int) -> int:
	return levelCode / 100


## 区在推进顺序里的序号（0 起）；区代号非法时返回 -1。
func getDistrictIndex(districtCode: int) -> int:
	return getDistrictCodesByOrder().find(districtCode)


## 区内下一小关的编号（连打用）；已经是区里最后一关时返回 0。
func getNextLevelCode(levelCode: int) -> int:
	var levelCodes = getLevelCodes(getDistrictCodeOfLevel(levelCode))
	var position = levelCodes.find(levelCode)

	if position == -1 or position + 1 >= levelCodes.size():
		return 0
	return levelCodes[position + 1]


## 取小关配置；还没配内容的区（其小关不在表里）返回空字典。
func getLevelData(levelCode: int) -> Dictionary:
	return levelInfo.get(levelCode, {})


## 本关内容是否已经做出来 —— 只由**有没有房间清单**决定，不另设开关字段。
func isLevelPlayable(levelCode: int) -> bool:
	return not getLevelData(levelCode).get("rooms", []).is_empty()


## 取关卡场景路径；小关没配置时返回空字符串（调用方据此不跳转）。
func getLevelScenePath(levelCode: int) -> String:
	return getLevelData(levelCode).get("scene", "")


## 取关卡滚动方向；数据缺失一律按纵向（没内容的关本来就不会被打开）。
func getScrollAxis(levelCode: int) -> BattleCamera.ScrollAxis:
	var axisName = getLevelData(levelCode).get("scrollAxis", "vertical")

	return BattleCamera.ScrollAxis.HORIZONTAL if axisName == "horizontal" else BattleCamera.ScrollAxis.VERTICAL


## 取某关的房间清单（按推进顺序）；配置缺失时返回空数组。
func getRoomIds(levelCode: int) -> Array[String]:
	var result: Array[String] = []
	for roomId in getLevelData(levelCode).get("rooms", []):
		result.append(roomId)
	return result


## 取某关的检查点房间下标。
func getCheckpointRooms(levelCode: int) -> Array[int]:
	var result: Array[int] = []
	for index in getLevelData(levelCode).get("checkpointRooms", []):
		result.append(index)
	return result


## 取房间配置；id 非法时返回空字典。
func getRoomData(roomId: String) -> Dictionary:
	return roomInfo.get(roomId, {})


## 取房间场景路径；id 非法时返回空字符串。
func getRoomScenePath(roomId: String) -> String:
	return getRoomData(roomId).get("scene", "")


## 取房间沿推进方向的长度（像素）；未配置时按一屏高兜底。
func getRoomLength(roomId: String) -> float:
	return getRoomData(roomId).get("alongLength", 1080.0)


## 取房间横向可用宽度（像素）；返回 0 表示「按相机视野宽铺满」。
func getRoomLateralLength(roomId: String) -> float:
	return getRoomData(roomId).get("lateralLength", 0.0)


## 取敌人场景路径；id 非法时返回空字符串。
func getEnemyScenePath(enemyId: String) -> String:
	return enemyScenes.get(enemyId, "")
