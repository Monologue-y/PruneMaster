extends Control
## 选关界面（M3：背景森林图 + 中文文案 + 按钮音效）。
## 从首页（home.tscn）进入；全部关卡直接开放，可随时选择任意关卡。

const LEVEL_COUNT := 20
const GRID_COLS := 4
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

	var title := Label.new()
	title.text = "选择关卡"
	title.add_theme_font_size_override("font_size", 56)
	title.modulate = Color(0.16, 0.38, 0.14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(40, 96)
	title.size = Vector2(640, 80)
	add_child(title)

	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(130, 60)
	back.position = Vector2(36, 104)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(_on_back)
	add_child(back)

	var subtitle := Label.new()
	subtitle.text = "修剪枝头 · 清空树丛"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.modulate = Color(0.32, 0.42, 0.28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(40, 190)
	subtitle.size = Vector2(640, 40)
	add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(46, 270)
	scroll.size = Vector2(628, 940)
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for i in LEVEL_COUNT:
		var n: int = i + 1
		var b := Button.new()
		b.text = str(n)
		b.custom_minimum_size = Vector2(140, 150)
		b.add_theme_font_size_override("font_size", 46)
		b.pressed.connect(_on_level_selected.bind(n))
		b.pressed.connect(func(): AudioManager.play_sfx("click"))
		grid.add_child(b)


func _on_level_selected(level_number: int) -> void:
	GameState.current_level = level_number
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_back() -> void:
	AudioManager.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/menu/home.tscn")
