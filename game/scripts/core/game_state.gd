extends Node
## 全局单例：关卡进度与设置（M1 最小实现，M2 扩展选关/解锁/星级）。

const SAVE_PATH := "user://save.cfg"

var current_level: int = 1
var unlocked_level: int = 1


func _ready() -> void:
	_load_save()


func complete_level(level_number: int) -> void:
	if level_number + 1 > unlocked_level:
		unlocked_level = level_number + 1
	_save_save()


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		current_level = int(cfg.get_value("progress", "current_level", 1))
		unlocked_level = int(cfg.get_value("progress", "unlocked_level", 1))


func _save_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_level", current_level)
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.save(SAVE_PATH)
