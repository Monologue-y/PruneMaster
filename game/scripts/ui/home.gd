extends Control
## 首页（标题页）：游戏标题 + "开始游戏"按钮 → 选关页（menu.tscn）。
## 与选关页共用明亮森林背景风格。

const BG_COLOR := Color(0.93, 0.94, 0.86)
const BG_PATH := "res://assets/art/backgrounds/bg_bright.png"

var _shot_path := ""
var _shot_timer := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_parse_cmdline()
	_build()


func _parse_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.substr(7)


## 调试：--shot=PATH 时渲染 0.8s 后截图退出（视觉冒烟）。
func _process(delta: float) -> void:
	if _shot_path.is_empty():
		return
	_shot_timer += delta
	if _shot_timer >= 0.8:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		get_tree().quit()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 背景远景森林图
	if ResourceLoader.exists(BG_PATH):
		var spr := Sprite2D.new()
		spr.texture = load(BG_PATH) as Texture2D
		spr.centered = false
		add_child(spr)

	# 动态小树图标（摇摆的装饰树，复用游戏素材）
	var tree := HomeTree.new()
	tree.position = Vector2(360, 316)
	tree.scale = Vector2(1.18, 1.18)
	add_child(tree)

	var title := Label.new()
	title.text = "剪枝大师"
	title.add_theme_font_size_override("font_size", 120)
	title.modulate = Color(0.16, 0.38, 0.14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(40, 330)
	title.size = Vector2(640, 160)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "修剪枝头 · 清空树丛"
	subtitle.add_theme_font_size_override("font_size", 30)
	subtitle.modulate = Color(0.32, 0.42, 0.28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(40, 520)
	subtitle.size = Vector2(640, 44)
	add_child(subtitle)

	var start := Button.new()
	start.text = "开始游戏"
	start.custom_minimum_size = Vector2(360, 110)
	start.position = Vector2(180, 730)
	start.add_theme_font_size_override("font_size", 44)
	start.pressed.connect(_on_start)
	add_child(start)


func _on_start() -> void:
	AudioManager.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
