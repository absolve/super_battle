class_name State
extends Node
## 有限状态机中的单个状态。
##
## 用法：在角色的 StateMachine 节点下挂一个子节点，脚本 `extends State`；
## 状态名 = 节点名，由 [StateMachine] 在 `_ready` 里统一注册并注入 [member actor]。
##
## 设计约定：
##   - 状态不保存宿主数据，只通过 [member actor] 调用宿主的钩子函数；
##   - 状态只声明「我想去哪」，真正的切换由 [StateMachine.transitionTo] 执行；
##   - 每物理帧由状态机把 [method physicsUpdate] 转发给当前状态，宿主里不写 if/else 分支。

## 所属状态机（由父级 [StateMachine] 注入）。
var stateMachine: StateMachine = null

## 状态机宿主（角色根节点），由 [StateMachine] 注入。
var actor: Node2D = null

## 本状态已持续时长（秒），进入时清零，由 [StateMachine] 每物理帧累加。
var stateTime: float = 0.0


# ---- 自定义函数放前面 ----

## 进入状态（首次进入或由其它状态切换而来），[param msg] 可携带切换参数。
func enter(_msg: Dictionary = {}) -> void:
	pass


## 离开状态（切走前调用一次），用于清理或恢复属性。
func exit() -> void:
	pass


## 每物理帧更新，仅当本状态是当前状态时被调用。
func physicsUpdate(_delta: float) -> void:
	pass


## 便捷：请求状态机切换到 [param targetName]（状态子节点名，大小写不敏感）。
func transitionTo(targetName: StringName, msg: Dictionary = {}) -> void:
	if stateMachine != null:
		stateMachine.transitionTo(targetName, msg)
