extends CanvasLayer
## 场景切换单例（Autoload 名 [code]SceneTransition[/code]）。
##
## 统一走 [method changeScene]：淡出 → 换场景 → 淡入。切换期间忽略重复调用。
## 界面层号设得很大（[constant LAYER]），保证盖在所有游戏 UI 之上。

const LAYER: int = 128
const FADE_TIME: float = 0.35

## 一次完整切换结束（淡入完成）后发出。
signal transitionFinished

@onready var fadeRect: ColorRect = $FadeRect

var isTransitioning: bool = false


func _ready() -> void:
	layer = LAYER
	fadeRect.color.a = 0.0
	fadeRect.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ---- 自定义函数放前面 ----

## 淡出后切换到目标场景，再淡入。切换进行中时忽略本次调用。
func changeScene(scenePath: String) -> void:
	if isTransitioning:
		return
	isTransitioning = true
	await fadeTo(1.0)
	get_tree().change_scene_to_file(scenePath)
	await get_tree().process_frame
	await fadeTo(0.0)
	isTransitioning = false
	transitionFinished.emit()


## 只做淡入（进入游戏时用），完成后发 [signal transitionFinished]。
func fadeIn() -> void:
	await fadeTo(0.0)
	transitionFinished.emit()


## 把遮罩淡到目标透明度。
func fadeTo(targetAlpha: float) -> void:
	fadeRect.visible = true
	var tween = create_tween()
	tween.tween_property(fadeRect, "color:a", targetAlpha, FADE_TIME)
	await tween.finished
	fadeRect.visible = targetAlpha > 0.0
