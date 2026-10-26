class_name Hud
extends CanvasLayer
## 灰盒 HUD：生命（红圆点）、剩余节点计数、重开按钮、胜负结算浮层。
## M1 阶段文案用英文（Godot 默认字体不含 CJK 字形，M3 接入中文字体后切换）。

signal retry_requested
signal next_requested
signal prev_requested
signal menu_requested

var _hearts: Array[Panel] = []
var _count_label: Label
var _timer_label: Label
var _hint_label: Label
var _overlay_backdrop: ColorRect
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_level: Label
var _rating_label: Label
var _rating_caption: Label
var _result_stats: HBoxContainer
var _time_heading: Label
var _time_value: Label
var _target_box: VBoxContainer
var _target_value: Label
var _grade_row: HBoxContainer
var _grade_labels: Dictionary = {}
var _overlay_next: Button

var _total: int = 0
var _pruned: int = 0
var _lives_left: int = 0
var _lives_max: int = 3
var _prev_btn: Button
var _next_btn: Button
var _runner: LevelRunner
var _level_id: int = 0
var _last_timer_second: int = -1


func setup(runner: LevelRunner, level: LevelData) -> void:
	_runner = runner
	_level_id = level.id
	_total = level.node_count()
	_lives_left = level.lives
	_lives_max = level.lives
	layer = 10
	_build()
	runner.node_pruned.connect(_on_pruned)
	runner.life_lost.connect(_on_life_lost)


func _process(_delta: float) -> void:
	if _runner == null:
		return
	var whole_seconds := int(floor(_runner.elapsed_time))
	if whole_seconds != _last_timer_second:
		_last_timer_second = whole_seconds
		_timer_label.text = LevelRunner.format_time(_runner.elapsed_time)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 顶部左侧：生命
	var hearts_box := HBoxContainer.new()
	hearts_box.position = Vector2(20, 22)
	hearts_box.add_theme_constant_override("separation", 10)
	root.add_child(hearts_box)
	for i in _lives_max:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(34, 34)
		p.add_theme_stylebox_override("panel", _heart_style(true))
		hearts_box.add_child(p)
		_hearts.append(p)

	# 顶部右侧：剩余节点（锚定右上角，适配 expand 模式下不同屏宽）
	_count_label = Label.new()
	_count_label.text = "剩余 %d/%d" % [_total, _total]
	_count_label.add_theme_font_size_override("font_size", 26)
	_count_label.modulate = Color(0.16, 0.38, 0.14)
	_count_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_count_label.offset_left = -290
	_count_label.offset_right = -20
	_count_label.offset_top = 24
	_count_label.offset_bottom = 64
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_count_label)

	# 顶部居中：本关计时。只显示数字，避免与左右状态区争抢空间。
	_timer_label = Label.new()
	_timer_label.text = "00:00"
	_timer_label.add_theme_font_size_override("font_size", 24)
	_timer_label.modulate = Color(0.32, 0.42, 0.28)
	_timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer_label.offset_left = -75
	_timer_label.offset_right = 75
	_timer_label.offset_top = 24
	_timer_label.offset_bottom = 60
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_timer_label)

	# 顶部居中：新手引导提示条（锚定顶部居中）
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.modulate = Color(0.55, 0.35, 0.05)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.offset_left = -320
	_hint_label.offset_right = 320
	_hint_label.offset_top = 72
	_hint_label.offset_bottom = 108
	_hint_label.visible = false
	root.add_child(_hint_label)

	# 底部栏：菜单 / 上一关 / 下一关 / 重试（关卡随时切换，全部开放）
	# 全部锚定屏幕底边（expand 模式下设计高度随屏幕变化，固定 y 坐标会悬空）
	var menu := Button.new()
	menu.text = "菜单"
	menu.add_theme_font_size_override("font_size", 24)
	menu.custom_minimum_size = Vector2(120, 56)
	menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	menu.offset_left = 30
	menu.offset_right = 150
	menu.offset_top = -70
	menu.offset_bottom = -14
	menu.pressed.connect(func(): menu_requested.emit())
	menu.pressed.connect(func(): AudioManager.play_sfx("click"))
	root.add_child(menu)

	_prev_btn = Button.new()
	_prev_btn.text = "上一关"
	_prev_btn.add_theme_font_size_override("font_size", 24)
	_prev_btn.custom_minimum_size = Vector2(140, 56)
	_prev_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prev_btn.offset_left = -195
	_prev_btn.offset_right = -55
	_prev_btn.offset_top = -70
	_prev_btn.offset_bottom = -14
	_prev_btn.pressed.connect(func(): prev_requested.emit())
	_prev_btn.pressed.connect(func(): AudioManager.play_sfx("click"))
	root.add_child(_prev_btn)

	_next_btn = Button.new()
	_next_btn.text = "下一关"
	_next_btn.add_theme_font_size_override("font_size", 24)
	_next_btn.custom_minimum_size = Vector2(140, 56)
	_next_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_next_btn.offset_left = 55
	_next_btn.offset_right = 195
	_next_btn.offset_top = -70
	_next_btn.offset_bottom = -14
	_next_btn.pressed.connect(func(): next_requested.emit())
	_next_btn.pressed.connect(func(): AudioManager.play_sfx("click"))
	root.add_child(_next_btn)

	# 右下角：重开
	var retry := Button.new()
	retry.text = "重试"
	retry.add_theme_font_size_override("font_size", 24)
	retry.custom_minimum_size = Vector2(120, 56)
	retry.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	retry.offset_left = -145
	retry.offset_right = -25
	retry.offset_top = -70
	retry.offset_bottom = -14
	retry.pressed.connect(func(): retry_requested.emit())
	retry.pressed.connect(func(): AudioManager.play_sfx("click"))
	root.add_child(retry)

	# 结果页：参考题目示例采用暗场聚焦、金色标题和清晰的成绩指标。
	_overlay_backdrop = ColorRect.new()
	_overlay_backdrop.color = Color(0.02, 0.035, 0.02, 0.78)
	_overlay_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_backdrop.visible = false
	root.add_child(_overlay_backdrop)

	_overlay = PanelContainer.new()
	_overlay.custom_minimum_size = Vector2(520, 600)
	_overlay.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.075, 0.055, 0.98)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(0.76, 0.56, 0.20)
	sb.set_border_width_all(2)
	sb.content_margin_left = 34.0
	sb.content_margin_right = 34.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 30.0
	_overlay.add_theme_stylebox_override("panel", sb)
	root.add_child(_overlay)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(452, 0)
	_overlay.add_child(vb)

	_overlay_title = Label.new()
	_overlay_title.text = "枝艺绽放"
	_overlay_title.add_theme_font_size_override("font_size", 46)
	_overlay_title.modulate = Color(0.95, 0.72, 0.25)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_overlay_title)

	_overlay_level = Label.new()
	_overlay_level.add_theme_font_size_override("font_size", 21)
	_overlay_level.modulate = Color(0.72, 0.76, 0.68)
	_overlay_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_overlay_level)

	_rating_label = Label.new()
	_rating_label.add_theme_font_size_override("font_size", 104)
	_rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rating_label.custom_minimum_size = Vector2(0, 118)
	vb.add_child(_rating_label)

	_rating_caption = Label.new()
	_rating_caption.add_theme_font_size_override("font_size", 26)
	_rating_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_rating_caption)

	_result_stats = HBoxContainer.new()
	_result_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_stats.add_theme_constant_override("separation", 28)
	vb.add_child(_result_stats)

	var time_box := VBoxContainer.new()
	time_box.custom_minimum_size = Vector2(190, 74)
	_result_stats.add_child(time_box)
	_time_heading = Label.new()
	_time_heading.text = "通关时间"
	_time_heading.add_theme_font_size_override("font_size", 18)
	_time_heading.modulate = Color(0.68, 0.70, 0.64)
	_time_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_box.add_child(_time_heading)
	_time_value = Label.new()
	_time_value.add_theme_font_size_override("font_size", 32)
	_time_value.modulate = Color(1.0, 0.88, 0.52)
	_time_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_box.add_child(_time_value)

	var metric_sep := VSeparator.new()
	metric_sep.custom_minimum_size = Vector2(1, 68)
	_result_stats.add_child(metric_sep)

	_target_box = VBoxContainer.new()
	_target_box.custom_minimum_size = Vector2(190, 74)
	_result_stats.add_child(_target_box)
	var target_heading := Label.new()
	target_heading.text = "S 级目标"
	target_heading.add_theme_font_size_override("font_size", 18)
	target_heading.modulate = Color(0.68, 0.70, 0.64)
	target_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_box.add_child(target_heading)
	_target_value = Label.new()
	_target_value.add_theme_font_size_override("font_size", 32)
	_target_value.modulate = Color(1.0, 0.88, 0.52)
	_target_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_box.add_child(_target_value)

	_grade_row = HBoxContainer.new()
	_grade_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_grade_row.add_theme_constant_override("separation", 42)
	for grade in ["S", "A", "B", "C"]:
		var grade_label := Label.new()
		grade_label.text = grade
		grade_label.add_theme_font_size_override("font_size", 25)
		grade_label.modulate = Color(0.35, 0.38, 0.34)
		grade_label.custom_minimum_size = Vector2(44, 38)
		grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_grade_row.add_child(grade_label)
		_grade_labels[grade] = grade_label
	vb.add_child(_grade_row)

	_overlay_next = Button.new()
	_overlay_next.text = "下一关"
	_overlay_next.add_theme_font_size_override("font_size", 28)
	_overlay_next.custom_minimum_size = Vector2(452, 64)
	_overlay_next.add_theme_stylebox_override("normal", _button_style(Color(0.19, 0.50, 0.17)))
	_overlay_next.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.60, 0.21)))
	_overlay_next.add_theme_stylebox_override("pressed", _button_style(Color(0.15, 0.40, 0.14)))
	_overlay_next.pressed.connect(func(): next_requested.emit())
	_overlay_next.pressed.connect(func(): AudioManager.play_sfx("click"))
	vb.add_child(_overlay_next)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	vb.add_child(actions)

	var retry2 := Button.new()
	retry2.text = "重试"
	retry2.add_theme_font_size_override("font_size", 24)
	retry2.custom_minimum_size = Vector2(218, 56)
	retry2.add_theme_stylebox_override("normal", _button_style(Color(0.24, 0.26, 0.23)))
	retry2.add_theme_stylebox_override("hover", _button_style(Color(0.31, 0.33, 0.29)))
	retry2.pressed.connect(func(): retry_requested.emit())
	retry2.pressed.connect(func(): AudioManager.play_sfx("click"))
	actions.add_child(retry2)

	var menu2 := Button.new()
	menu2.text = "返回选关"
	menu2.add_theme_font_size_override("font_size", 24)
	menu2.custom_minimum_size = Vector2(218, 56)
	menu2.add_theme_stylebox_override("normal", _button_style(Color(0.24, 0.26, 0.23)))
	menu2.add_theme_stylebox_override("hover", _button_style(Color(0.31, 0.33, 0.29)))
	menu2.pressed.connect(func(): menu_requested.emit())
	menu2.pressed.connect(func(): AudioManager.play_sfx("click"))
	actions.add_child(menu2)


func show_hint(text: String) -> void:
	_hint_label.text = text
	_hint_label.visible = true


## 上一关/下一关按钮的可用态（边界关禁用）
func setup_nav(has_prev: bool, has_next: bool) -> void:
	_prev_btn.disabled = not has_prev
	_next_btn.disabled = not has_next
	_prev_btn.modulate = Color(1, 1, 1) if has_prev else Color(0.55, 0.56, 0.53)
	_next_btn.modulate = Color(1, 1, 1) if has_next else Color(0.55, 0.56, 0.53)


func clear_hint() -> void:
	_hint_label.visible = false


func show_result(won: bool, has_next: bool, result: Dictionary = {}) -> void:
	var grade := String(result.get("rating", "C"))
	_overlay_level.text = "第 %d 关完成" % _level_id if won else "第 %d 关未完成" % _level_id
	_time_value.text = String(result.get("time_text", "00:00"))
	_target_value.text = String(result.get("s_target_text", "00:00"))
	_overlay_title.text = "枝艺绽放" if won else "生命耗尽"
	_overlay_title.modulate = Color(0.95, 0.72, 0.25) if won else Color(1.0, 0.45, 0.38)
	_rating_label.text = grade if won else "未完成"
	_rating_label.add_theme_font_size_override("font_size", 104 if won else 48)
	_rating_label.modulate = _rating_color(grade) if won else Color(0.82, 0.84, 0.79)
	_rating_caption.text = String(result.get("rating_name", "完成挑战")) if won else "整理思路，再试一次"
	_rating_caption.modulate = _rating_color(grade) if won else Color(0.72, 0.76, 0.68)
	_time_heading.text = "通关时间" if won else "本次用时"
	_target_box.visible = won
	_grade_row.visible = won
	for key in _grade_labels:
		var label := _grade_labels[key] as Label
		label.modulate = _rating_color(String(key)) if won and String(key) == grade else Color(0.35, 0.38, 0.34)
	_overlay_next.visible = won and has_next
	_overlay.custom_minimum_size = Vector2(520, 600 if won else 390)
	_overlay_backdrop.visible = true
	_overlay.visible = true
	_overlay.reset_size()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.20)


func _on_pruned(_node_id: int) -> void:
	_pruned += 1
	_count_label.text = "剩余 %d/%d" % [_total - _pruned, _total]


func _on_life_lost(lives_left: int) -> void:
	_lives_left = lives_left
	for i in _hearts.size():
		_hearts[i].add_theme_stylebox_override("panel", _heart_style(i < _lives_left))


static func _heart_style(full: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.22, 0.20) if full else Color(0.22, 0.24, 0.22)
	sb.set_corner_radius_all(17)
	return sb


static func _button_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


static func _rating_color(grade: String) -> Color:
	match grade:
		"S": return Color(1.0, 0.78, 0.24)
		"A": return Color(0.48, 0.86, 0.38)
		"B": return Color(0.40, 0.70, 0.94)
		_: return Color(0.76, 0.76, 0.70)
