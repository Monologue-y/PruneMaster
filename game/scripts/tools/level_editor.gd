extends Control
## 关卡编辑器 UI（桌面工具）。运行：
##   godot --path game scenes/tools/level_editor.tscn
##
## 模式：PLACE 放置 / LINK 连线（点父再点子）/ MOVE 拖动 / DELETE 删除。
## 新节点归属「树」编号；跨树连线自动生成共享节点。
## 实时校验，0 错误才允许保存到 res://assets/levels/。

const GRID_COLS := [60.0, 140.0, 220.0, 300.0, 380.0, 460.0, 540.0, 620.0]
const GRID_ROW_START := 190.0
const GRID_ROW_STEP := 110.0
const GRID_ROW_END := 1170.0
const SNAP := 10.0
const NODE_R := 34.0
const BG_COLOR := Color(0.10, 0.12, 0.09)
const GRID_DOT_COLOR := Color(0.35, 0.42, 0.32)
const LINK_COLOR := Color(0.45, 0.33, 0.20)
const ERR_COLOR := Color(1.0, 0.45, 0.40)

const PALETTE := [
	Color(0.45, 0.72, 0.38),
	Color(0.42, 0.62, 0.85),
	Color(0.82, 0.55, 0.35),
	Color(0.70, 0.50, 0.80),
	Color(0.85, 0.75, 0.40),
	Color(0.60, 0.75, 0.75),
]

enum Mode { PLACE, LINK, MOVE, DELETE }

const LEVEL_DIR := "res://assets/levels"

var core := LevelEditorCore.new()
var mode: Mode = Mode.PLACE
var current_tree: int = 1

var _selected_id := -1
var _link_from := -1
var _mode_buttons: Dictionary = {}   # Mode -> Button
var _tree_spin: SpinBox
var _level_spin: SpinBox
var _status: Label
var _errors: Label
var _last_errors: PackedStringArray = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	core.changed.connect(_refresh)
	_build()


func _build() -> void:
	var toolbar := PanelContainer.new()
	toolbar.position = Vector2(0, 0)
	toolbar.size = Vector2(720, 104)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.07, 0.95)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.35, 0.28)
	toolbar.add_theme_stylebox_override("panel", sb)
	add_child(toolbar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	toolbar.add_child(row)

	for m in [Mode.PLACE, Mode.LINK, Mode.MOVE, Mode.DELETE]:
		var b := Button.new()
		b.toggle_mode = true
		b.text = ["放置", "连线", "移动", "删除"][m]
		b.custom_minimum_size = Vector2(110, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_set_mode.bind(m))
		row.add_child(b)
		_mode_buttons[m] = b

	var tree_label := Label.new()
	tree_label.text = "树："
	tree_label.add_theme_font_size_override("font_size", 22)
	row.add_child(tree_label)
	_tree_spin = SpinBox.new()
	_tree_spin.min_value = 1
	_tree_spin.max_value = 6
	_tree_spin.value = 1
	_tree_spin.custom_minimum_size = Vector2(90, 64)
	_tree_spin.value_changed.connect(func(v: float): current_tree = int(v))
	row.add_child(_tree_spin)

	var level_label := Label.new()
	level_label.text = "关卡："
	level_label.add_theme_font_size_override("font_size", 22)
	row.add_child(level_label)
	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 99
	_level_spin.value = 21
	_level_spin.custom_minimum_size = Vector2(100, 64)
	row.add_child(_level_spin)

	var load_btn := Button.new()
	load_btn.text = "读取"
	load_btn.custom_minimum_size = Vector2(110, 64)
	load_btn.add_theme_font_size_override("font_size", 22)
	load_btn.pressed.connect(_on_load)
	row.add_child(load_btn)

	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.custom_minimum_size = Vector2(110, 64)
	save_btn.add_theme_font_size_override("font_size", 22)
	save_btn.pressed.connect(_on_save)
	row.add_child(save_btn)

	var new_btn := Button.new()
	new_btn.text = "新建"
	new_btn.custom_minimum_size = Vector2(100, 64)
	new_btn.add_theme_font_size_override("font_size", 22)
	new_btn.pressed.connect(_on_new)
	row.add_child(new_btn)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 22)
	_status.modulate = Color(0.75, 0.85, 0.68)
	_status.position = Vector2(20, 1160)
	_status.size = Vector2(680, 40)
	add_child(_status)

	_errors = Label.new()
	_errors.add_theme_font_size_override("font_size", 19)
	_errors.modulate = ERR_COLOR
	_errors.position = Vector2(20, 1200)
	_errors.size = Vector2(680, 70)
	add_child(_errors)

	_set_mode(Mode.PLACE)
	core.create(int(_level_spin.value))
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		match mode:
			Mode.PLACE:
				current_tree = int(_tree_spin.value)
				_selected_id = core.add_node(_snap(pos), current_tree)
				_link_from = -1
			Mode.LINK:
				var hit := _hit_node(pos)
				if hit >= 0:
					if _link_from < 0:
						_link_from = hit
						_selected_id = hit
					else:
						core.link(_link_from, hit)
						_link_from = -1
			Mode.MOVE:
				_selected_id = _hit_node(pos)
			Mode.DELETE:
				var hit2 := _hit_node(pos)
				if hit2 >= 0:
					core.remove_node(hit2)
					if _link_from == hit2:
						_link_from = -1
					if _selected_id == hit2:
						_selected_id = -1
	elif event is InputEventMouseMotion and mode == Mode.MOVE and _selected_id >= 0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			core.move_node(_selected_id, _snap(event.position))


func _draw() -> void:
	draw_rect(Rect2(0, 0, 720, 1280), BG_COLOR)
	# 网格参考点
	var yy := GRID_ROW_START
	while yy <= GRID_ROW_END:
		for x in GRID_COLS:
			draw_circle(Vector2(x, yy), 3.0, GRID_DOT_COLOR)
		yy += GRID_ROW_STEP
	# 连线
	for n in core.nodes:
		var nd: Dictionary = n
		var pa: Vector2 = nd["pos"]
		for c in nd["children"]:
			draw_line(pa, core.position_of(int(c)), LINK_COLOR, 12.0)
	# 节点
	for n in core.nodes:
		var nd: Dictionary = n
		var id := int(nd["id"])
		var pos: Vector2 = nd["pos"]
		var trees: Array = nd["trees"]
		var fill: Color = PALETTE[0]
		if trees.size() > 0:
			fill = PALETTE[(int(trees[0]) - 1) % PALETTE.size()]
		draw_circle(pos, NODE_R, fill)
		draw_arc(pos, NODE_R, 0.0, TAU, 40, Color(0.15, 0.10, 0.04), 5.0, true)
		if trees.size() > 1:
			draw_arc(pos, NODE_R - 11.0, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 3.0, true)
		if id == _selected_id:
			draw_arc(pos, NODE_R + 8.0, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 4.0, true)
		if id == _link_from:
			draw_arc(pos, NODE_R + 14.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.3, 0.95), 4.0, true)


func _set_mode(m: int) -> void:
	mode = m
	_link_from = -1
	for k in _mode_buttons.keys():
		(_mode_buttons[k] as Button).button_pressed = (int(k) == m)
	queue_redraw()


func _on_load() -> void:
	var n := int(_level_spin.value)
	var path := "%s/level_%03d.json" % [LEVEL_DIR, n]
	if core.load_level(path):
		_selected_id = -1
		_link_from = -1
		_refresh()
	else:
		_status.text = "LOAD FAILED: %s" % path


func _on_save() -> void:
	var n := int(_level_spin.value)
	core.level_id = n
	core.level_name = "Level %d" % n
	var path := "%s/level_%03d.json" % [LEVEL_DIR, n]
	var errs := core.save_to(path)
	if errs.is_empty():
		_last_errors.clear()
		_errors.text = ""
		_status.text = "SAVED -> %s (%d nodes)" % [path, core.node_count()]
	else:
		_status.text = "SAVE BLOCKED (invalid level)"
		_show_errors(errs)


func _on_new() -> void:
	core.create(int(_level_spin.value))
	_selected_id = -1
	_link_from = -1
	_refresh()


func _refresh() -> void:
	var errs := core.validate()
	_last_errors = errs
	if errs.is_empty():
		_status.text = "nodes: %d  |  VALID" % core.node_count()
		_errors.text = ""
	else:
		_status.text = "nodes: %d  |  INVALID" % core.node_count()
		_show_errors(errs)
	queue_redraw()


func _show_errors(errs: PackedStringArray) -> void:
	var txt := ""
	var count := 0
	for e in errs:
		txt += String(e) + "\n"
		count += 1
		if count >= 3:
			break
	if errs.size() > 3:
		txt += "... +%d more" % (errs.size() - 3)
	_errors.text = txt


func _snap(pos: Vector2) -> Vector2:
	return Vector2(snappedf(pos.x, SNAP), snappedf(pos.y, SNAP))


func _hit_node(pos: Vector2) -> int:
	var best := -1
	var best_d: float = NODE_R + 10.0
	for n in core.nodes:
		var nd: Dictionary = n
		var d: float = (nd["pos"] as Vector2).distance_to(pos)
		if d < best_d:
			best_d = d
			best = int(nd["id"])
	return best
