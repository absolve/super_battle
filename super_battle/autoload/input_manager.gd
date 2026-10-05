extends Node
## 输入管理单例（Autoload 名 [code]InputManager[/code]）。
##
## 把键盘 / 手柄映射成 **4 名玩家各自独立**的 InputMap 动作：
## [code]p1_move_up[/code] … [code]p4_bomb[/code]。动作在运行时注册，
## 避免把几十条 InputEvent 硬编码进 `project.godot`，也方便以后做按键自定义。
##
## 手柄按**设备号**分配：[code]device 0[/code] 归 1 号玩家……[code]device 3[/code] 归 4 号玩家。
## 键盘为 4 名玩家各留一套兜底按键，方便单机调试。

const PLAYER_COUNT: int = 4

const ACTION_MOVE_UP: String = "move_up"
const ACTION_MOVE_DOWN: String = "move_down"
const ACTION_MOVE_LEFT: String = "move_left"
const ACTION_MOVE_RIGHT: String = "move_right"
const ACTION_FIRE: String = "fire"
const ACTION_BOMB: String = "bomb"
const ACTION_START: String = "start"

const ALL_ACTIONS: Array[String] = [
	ACTION_MOVE_UP,
	ACTION_MOVE_DOWN,
	ACTION_MOVE_LEFT,
	ACTION_MOVE_RIGHT,
	ACTION_FIRE,
	ACTION_BOMB,
	ACTION_START,
]

## 键盘兜底按键：槽位 -> 动作 -> 键码数组。
## 1 号 WASD、2 号方向键、3 号 IJKL、4 号小键盘，避免互相冲突。
const KEYBOARD_BINDINGS = {
	0: {
		ACTION_MOVE_UP: [KEY_W],
		ACTION_MOVE_DOWN: [KEY_S],
		ACTION_MOVE_LEFT: [KEY_A],
		ACTION_MOVE_RIGHT: [KEY_D],
		ACTION_FIRE: [KEY_G],
		ACTION_BOMB: [KEY_H],
		ACTION_START: [KEY_ENTER],
	},
	1: {
		ACTION_MOVE_UP: [KEY_UP],
		ACTION_MOVE_DOWN: [KEY_DOWN],
		ACTION_MOVE_LEFT: [KEY_LEFT],
		ACTION_MOVE_RIGHT: [KEY_RIGHT],
		ACTION_FIRE: [KEY_KP_1],
		ACTION_BOMB: [KEY_KP_2],
		ACTION_START: [KEY_KP_0],
	},
	2: {
		ACTION_MOVE_UP: [KEY_I],
		ACTION_MOVE_DOWN: [KEY_K],
		ACTION_MOVE_LEFT: [KEY_J],
		ACTION_MOVE_RIGHT: [KEY_L],
		ACTION_FIRE: [KEY_U],
		ACTION_BOMB: [KEY_O],
		ACTION_START: [KEY_P],
	},
	3: {
		ACTION_MOVE_UP: [KEY_KP_8],
		ACTION_MOVE_DOWN: [KEY_KP_5],
		ACTION_MOVE_LEFT: [KEY_KP_4],
		ACTION_MOVE_RIGHT: [KEY_KP_6],
		ACTION_FIRE: [KEY_KP_7],
		ACTION_BOMB: [KEY_KP_9],
		ACTION_START: [KEY_KP_3],
	},
}

## 手柄按键：动作 -> 按键枚举。移动走左摇杆，见 [method _registerJoypadAxes]。
const JOY_BUTTON_BINDINGS = {
	ACTION_FIRE: JOY_BUTTON_A,
	ACTION_BOMB: JOY_BUTTON_X,
	ACTION_START: JOY_BUTTON_START,
}


func _ready() -> void:
	registerActions()


# ---- 自定义函数放前面 ----

## 注册全部玩家动作；重复调用安全（已存在的动作会跳过）。
func registerActions() -> void:
	for playerIndex in PLAYER_COUNT:
		for action in ALL_ACTIONS:
			var actionName = getActionName(playerIndex, action)
			if InputMap.has_action(actionName):
				continue
			InputMap.add_action(actionName)
			_registerKeyboard(playerIndex, action, actionName)
			_registerJoypad(playerIndex, action, actionName)


## 取某个玩家某个动作的完整动作名，如 [code]p2_fire[/code]。
func getActionName(playerIndex: int, action: String) -> String:
	return "p%d_%s" % [playerIndex + 1, action]


## 移动输入向量（已限制长度，斜向不加速）。
func getMoveVector(playerIndex: int) -> Vector2:
	var move = Vector2(
		Input.get_action_strength(getActionName(playerIndex, ACTION_MOVE_RIGHT))
			- Input.get_action_strength(getActionName(playerIndex, ACTION_MOVE_LEFT)),
		Input.get_action_strength(getActionName(playerIndex, ACTION_MOVE_DOWN))
			- Input.get_action_strength(getActionName(playerIndex, ACTION_MOVE_UP)),
	)
	return move.limit_length(1.0)


## 开火键是否按住。
func isFirePressed(playerIndex: int) -> bool:
	return Input.is_action_pressed(getActionName(playerIndex, ACTION_FIRE))


## 开火键是否刚按下（点射用）。
func isFireJustPressed(playerIndex: int) -> bool:
	return Input.is_action_just_pressed(getActionName(playerIndex, ACTION_FIRE))


## 必杀键是否刚按下。
func isBombJustPressed(playerIndex: int) -> bool:
	return Input.is_action_just_pressed(getActionName(playerIndex, ACTION_BOMB))


## 开始/暂停键是否刚按下。
func isStartJustPressed(playerIndex: int) -> bool:
	return Input.is_action_just_pressed(getActionName(playerIndex, ACTION_START))


## 任意玩家是否刚按下开始键；返回第一个匹配的槽位，没有则 -1。
func getAnyStartPressed() -> int:
	for playerIndex in PLAYER_COUNT:
		if isStartJustPressed(playerIndex):
			return playerIndex
	return -1


## 任意玩家是否刚按下开火键（菜单确认用）；返回槽位或 -1。
func getAnyFirePressed() -> int:
	for playerIndex in PLAYER_COUNT:
		if isFireJustPressed(playerIndex):
			return playerIndex
	return -1


# ---- 内部函数放后面 ----

func _registerKeyboard(playerIndex: int, action: String, actionName: String) -> void:
	var bindings = KEYBOARD_BINDINGS.get(playerIndex, {})
	for keycode in bindings.get(action, []):
		var event = InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(actionName, event)


func _registerJoypad(playerIndex: int, action: String, actionName: String) -> void:
	if JOY_BUTTON_BINDINGS.has(action):
		var buttonEvent = InputEventJoypadButton.new()
		buttonEvent.device = playerIndex
		buttonEvent.button_index = JOY_BUTTON_BINDINGS[action]
		InputMap.action_add_event(actionName, buttonEvent)
		return
	var axisEvent = _buildJoypadAxis(action)
	if axisEvent != null:
		axisEvent.device = playerIndex
		InputMap.action_add_event(actionName, axisEvent)


## 把方向动作映射到左摇杆轴；非方向动作返回 null。
func _buildJoypadAxis(action: String) -> InputEventJoypadMotion:
	var event = InputEventJoypadMotion.new()
	match action:
		ACTION_MOVE_LEFT:
			event.axis = JOY_AXIS_LEFT_X
			event.axis_value = -1.0
		ACTION_MOVE_RIGHT:
			event.axis = JOY_AXIS_LEFT_X
			event.axis_value = 1.0
		ACTION_MOVE_UP:
			event.axis = JOY_AXIS_LEFT_Y
			event.axis_value = -1.0
		ACTION_MOVE_DOWN:
			event.axis = JOY_AXIS_LEFT_Y
			event.axis_value = 1.0
		_:
			return null
	return event
