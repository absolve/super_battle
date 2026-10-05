extends Node
## 声音管理单例（Autoload 名 [code]SoundManage[/code]）。
##
## 一条 BGM 播放器 + 一组 SFX 播放器池，避免频繁创建节点。
## 音量统一从 [UserData] 读取（[method applyVolumes] 在设置界面改动后调用）。

const SFX_POOL_SIZE: int = 12

## 背景音乐播放器（挂在 [code]BGM[/code] 子节点上）。
@onready var bgmPlayer: AudioStreamPlayer = $BGM

## 音效播放器池。
var sfxPlayers: Array[AudioStreamPlayer] = []

var sfxCursor: int = 0


func _ready() -> void:
	buildSfxPool()
	applyVolumes()


# ---- 自定义函数放前面 ----

## 按当前 [UserData] 音量刷新播放器音量。
func applyVolumes() -> void:
	bgmPlayer.volume_db = linearToDb(UserData.musicVolume)
	var sfxDb = linearToDb(UserData.sfxVolume)
	for player in sfxPlayers:
		player.volume_db = sfxDb


## 播放背景音乐；传入与当前相同的流时不打断。
func playBgm(stream: AudioStream) -> void:
	if stream == null:
		return
	if bgmPlayer.stream == stream and bgmPlayer.playing:
		return
	bgmPlayer.stream = stream
	bgmPlayer.play()


## 停止背景音乐。
func stopBgm() -> void:
	bgmPlayer.stop()


## 用池中下一个播放器播放一次音效。
func playSfx(stream: AudioStream, pitchScale: float = 1.0) -> void:
	if stream == null or sfxPlayers.is_empty():
		return
	var player = sfxPlayers[sfxCursor]
	sfxCursor = (sfxCursor + 1) % sfxPlayers.size()
	player.stream = stream
	player.pitch_scale = pitchScale
	player.play()


## 建音效播放器池，全部挂到 SFX 总线下。
func buildSfxPool() -> void:
	if not sfxPlayers.is_empty():
		return
	for index in SFX_POOL_SIZE:
		var player = AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = &"SFX"
		add_child(player)
		sfxPlayers.append(player)


## 线性音量转分贝；为 0 时返回静音（-80 dB）。
func linearToDb(value: float) -> float:
	if value <= 0.0:
		return -80.0
	return linear_to_db(value)
