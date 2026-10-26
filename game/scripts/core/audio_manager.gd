extends Node
## 音频管理（autoload 单例）：SFX 播放池 + 环境风声 BGM 无缝循环。
## 用法：AudioManager.play_sfx("snip")（名称见 SFX_NAMES）。

const AUDIO_DIR := "res://assets/audio"
const SFX_NAMES := ["snip", "error", "win", "lose", "click"]
const SFX_POOL := 4
const BGM_NAME := "bgm_wind"
const BGM_VOLUME_DB := -9.0

var _sfx: Dictionary = {}   # name -> { players: Array, next: int }
var _bgm: AudioStreamPlayer


func _ready() -> void:
	_load_sfx()
	_load_bgm()


func _load_sfx() -> void:
	for n in SFX_NAMES:
		var path := "%s/%s.wav" % [AUDIO_DIR, n]
		if not ResourceLoader.exists(path):
			push_error("音效资源缺失: %s" % path)
			continue
		var stream := load(path) as AudioStream
		var players: Array = []
		for i in SFX_POOL:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			add_child(p)
			players.append(p)
		_sfx[n] = {"players": players, "next": 0}


func _load_bgm() -> void:
	var path := "%s/%s.wav" % [AUDIO_DIR, BGM_NAME]
	if not ResourceLoader.exists(path):
		push_error("BGM 资源缺失: %s" % path)
		return
	_bgm = AudioStreamPlayer.new()
	_bgm.stream = load(path)
	_bgm.volume_db = BGM_VOLUME_DB
	add_child(_bgm)
	_bgm.finished.connect(func(): _bgm.play())
	_bgm.play()


## 播放一个音效（同类可同时最多 SFX_POOL 个实例，循环取用）。
func play_sfx(sfx_name: String, volume_db := 0.0) -> void:
	if not _sfx.has(sfx_name):
		return
	var entry: Dictionary = _sfx[sfx_name]
	var players: Array = entry["players"]
	var idx: int = int(entry["next"])
	entry["next"] = (idx + 1) % players.size()
	var p := players[idx] as AudioStreamPlayer
	if p == null:
		return
	p.volume_db = volume_db
	p.stop()
	p.play()
