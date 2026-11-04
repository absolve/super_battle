class_name StateMachine
extends Node
## 节点式有限状态机，供玩家 / 敌人等角色复用。
##
## 场景结构（以玩家为例）：
##   [PlayerCharacter (CharacterBody2D, script: player_character.gd)]
##   └─ [StateMachine (script: state_machine.gd)]
##       ├─ Idle        (script: player_idle.gd,        extends State)
##       ├─ Dead        (script: player_dead.gd)
##       └─ Eliminated  (script: player_eliminated.gd)
##
## 约定：
##   - 宿主默认取父节点，路径不同时在 Inspector 里改 [member actorPath]；
##   - 状态名 = 子节点名（大小写不敏感），[member initialState] 留空则取第一个 State 子节点；
##   - [method transitionTo]：exit 旧状态 → enter 新状态 → 广播 [signal stateChanged]；
##   - 每物理帧转发 [method State.physicsUpdate] 并累加 `stateTime`。
##
## 初始状态用 `call_deferred` 延后启动：子节点的 `_ready` 早于父节点，
## 若立刻 enter()，状态里访问宿主的 `@onready` 引用时它们还没赋值（会是 null）。

## 状态切换时发出（供特效 / 调试挂接，宿主不必每帧轮询当前状态）。
signal stateChanged(fromState: StringName, toState: StringName)

## 宿主节点路径。
@export var actorPath: NodePath = NodePath("..")

## 初始状态子节点名，留空 = 自动取第一个 State 子节点。
@export var initialState: StringName = &""

## 状态名（小写）-> 状态节点。
var states: Dictionary[String, State] = {}

## 当前状态（未启动时为 null）。
var currentState: State = null

## 宿主（角色根节点），`_ready` 里按 [member actorPath] 解析。
var actor: Node2D = null


# ---- 自定义函数放前面 ----

## 注册子节点为一个状态，并回填它自己拿不到的上下文。
func registerState(stateNode: State) -> void:
	states[stateKey(stateNode.name)] = stateNode
	stateNode.stateMachine = self
	stateNode.actor = actor
	stateNode.stateTime = 0.0


## 是否注册了某个状态。
func hasState(stateName: StringName) -> bool:
	return states.has(stateKey(stateName))


## 启动状态机；[param stateName] 非空时覆盖 [member initialState]。
## 宿主已在自己的 `_ready` 里切过状态时什么都不做。
func start(stateName: StringName = &"") -> void:
	if currentState != null:
		return
	var target = stateName if stateName != &"" else initialState

	if target != &"" and not hasState(target):
		push_warning("StateMachine %s: 找不到初始状态 '%s'" % [name, target])
		target = &""
	if target == &"" and not states.is_empty():
		target = states.keys()[0]
	if target != &"":
		transitionTo(target)


## 切换状态。[param stateName] 用状态子节点名（大小写不敏感）。
## 目标就是当前状态时直接返回：重入会白跑一遍 exit / enter，
## 而复活这类调用是幂等的，不需要靠重入刷新状态。
func transitionTo(stateName: StringName, msg: Dictionary = {}) -> void:
	var next = states.get(stateKey(stateName)) as State

	if next == null:
		push_warning("StateMachine %s: 没有名为 '%s' 的状态" % [name, stateName])
		return
	if next == currentState:
		return
	var fromName = currentState.name if currentState != null else &""

	if currentState != null:
		currentState.exit()
	currentState = next
	next.enter(msg)
	next.stateTime = 0.0
	stateChanged.emit(fromName, stateName)


## 当前状态名（未启动时为空）。
func currentName() -> StringName:
	return currentState.name if currentState != null else &""


## 状态名 -> 字典键（`StringName` 没有 to_lower，先转 String；大小写不敏感靠它）。
func stateKey(stateName: StringName) -> String:
	return String(stateName).to_lower()


# ---- Godot 内置虚函数放最后 ----

func _ready() -> void:
	actor = get_node_or_null(actorPath) as Node2D
	for child in get_children():
		var stateNode = child as State
		if stateNode != null:
			registerState(stateNode)
	start.call_deferred()


func _physics_process(delta: float) -> void:
	if currentState == null:
		return
	currentState.stateTime += delta
	currentState.physicsUpdate(delta)
