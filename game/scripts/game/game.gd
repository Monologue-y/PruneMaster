extends Node2D
## 主场景：装配关卡数据、流程控制（LevelRunner）、棋盘视图（BoardView）与 HUD。
## 用法：godot --path game -- --level=2 可直接进入指定关卡。

const LEVEL_DIR := "res://assets/levels"
const BG_COLOR := Color(0.93, 0.94, 0.86)
const BG_PATH := "res://assets/art/backgrounds/bg_bright.png"

const ZOOM_MIN := 0.6
const ZOOM_MAX := 3.2
const PAN_MARGIN := 160.0  # 视角允许滑出棋盘边界的余量

# 进关自动取景参数：全部节点完整落入"顶部 HUD 之下、底部按钮之上"的可用区域
const HUD_TOP := 76.0        # 顶部生命/计数条占用高度
const HUD_TOP_HINT := 116.0  # L1 提示条可见时的顶部占用
const HUD_BOTTOM := 92.0     # 底部按钮栏占用高度（按钮 56px + 上下间距）
const FIT_MARGIN := 46.0     # 节点包围盒外扩（叶簇可视半径 ~36 + 余量）

var level: LevelData
var runner: LevelRunner
var board: BoardView
var hud: Hud

var _cam: Camera2D
var _panning := false
var _shot_path := ""
var _shot_timer := 0.0
var _inspect_id := 0
var _preprune := 0
var _result_time := -1.0
var _preprune_done := false
var _inspect_applied := false


func _ready() -> void:
	_parse_cmdline()
	level = _load_current_level()
	if level == null:
		_show_fatal("关卡加载失败")
		return

	_add_background()

	# 相机：支持缩放/平移（双指捏合、拖拽、滚轮）
	_cam = Camera2D.new()
	_cam.position = Vector2(360, 640)
	_cam.enabled = true
	add_child(_cam)

	runner = LevelRunner.new()
	add_child(runner)
	runner.setup(level)

	board = BoardView.new()
	add_child(board)
	board.setup(level, runner)

	hud = Hud.new()
	add_child(hud)
	hud.setup(runner, level)
	hud.retry_requested.connect(_on_retry)
	hud.next_requested.connect(_on_next)
	hud.prev_requested.connect(_on_prev)
	hud.menu_requested.connect(_on_menu)
	hud.setup_nav(GameState.current_level > 1, _has_next_level())
	_fit_board_to_view()

	runner.level_won.connect(_on_won)
	runner.level_failed.connect(_on_failed)
	runner.node_pruned.connect(func(_id: int): AudioManager.play_sfx("snip"))
	runner.prune_rejected.connect(func(_id: int): AudioManager.play_sfx("error"))

	# 第 1 关新手提示：仅顶部精炼文案，不标记具体节点（让玩家自己观察枝条方向）
	if level.id == 1:
		hud.show_hint("看枝条尖端找没分叉的叶簇；长按高亮枝条，再点一下退出")


## 视角输入：双指捏合缩放（手动多点触控追踪，跨平台可靠）/ 单指（或鼠标左/右键）
## 拖拽平移 / 滚轮缩放 / 触控板捏合（InputEventMagnifyGesture）。
## 节点点击是"松手判定"（见 NodeView），拖拽不会误剪。
## 注意必须用 _input 而非 _unhandled_input：可拾取的 NodeView 会消费落在其上的
## 触摸/鼠标事件，密集关卡中 69% 的区域被节点覆盖，否则平移/捏合几乎无法启动。
var _touches := {}          # 触控点 index -> 屏幕坐标
var _pinch_dist := 0.0      # 双指上一帧间距

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 2:
				var pts := _touches.values()
				_pinch_dist = (pts[0] as Vector2).distance_to(pts[1])
		else:
			_touches.erase(event.index)
			_pinch_dist = 0.0
	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			_touches[event.index] = event.position
		if _touches.size() == 2:
			var pts := _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 1.0 and d > 1.0:
				var mid := ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5
				_zoom_at(mid, _cam.zoom.x * d / _pinch_dist)
			_pinch_dist = d
		elif _touches.size() == 1:
			_pan(event.relative)
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, _cam.zoom.x * event.factor)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, _cam.zoom.x * 1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, _cam.zoom.x / 1.12)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT \
				or event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
	elif event is InputEventMouseMotion and _panning:
		_pan(event.relative)


## 进关自动取景：节点包围盒（含叶簇可视半径）完整适配到 HUD 之间的可用区域，
## 居中显示；只缩不放（初始缩放 ≤ 1.0），玩家首屏即见全局，且不被按钮遮挡。
func _fit_board_to_view() -> void:
	if level == null or level.nodes.is_empty():
		return
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for n in level.nodes:
		var p := level.pos_of(int(n.get("id", -1)))
		minp = minp.min(p)
		maxp = maxp.max(p)
	minp -= Vector2(FIT_MARGIN, FIT_MARGIN)
	maxp += Vector2(FIT_MARGIN, FIT_MARGIN)
	var bbox := maxp - minp
	# 可用区域 = 视口去掉 HUD 占用带（canvas_items + expand：视口设计尺寸随屏幕变化）
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var top := HUD_TOP_HINT if level.id == 1 else HUD_TOP
	var usable := Vector2(vp.x, vp.y - top - HUD_BOTTOM)
	var z := clampf(minf(usable.x / bbox.x, usable.y / bbox.y), ZOOM_MIN, 1.0)
	_cam.zoom = Vector2(z, z)
	# 包围盒中心对准可用区域中心（相机位置 = 屏幕中心的世界点）
	var band_center := Vector2(vp.x * 0.5, top + usable.y * 0.5)
	_cam.position = (minp + maxp) * 0.5 - (band_center - vp * 0.5) / z
	_clamp_cam()


func _zoom_at(screen_pos: Vector2, new_zoom: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var old := _cam.zoom.x
	new_zoom = clampf(new_zoom, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, old):
		return
	var before := _cam.position + (screen_pos - vp * 0.5) / old
	_cam.zoom = Vector2(new_zoom, new_zoom)
	var after := _cam.position + (screen_pos - vp * 0.5) / new_zoom
	_cam.position += before - after
	_clamp_cam()


func _pan(rel_screen: Vector2) -> void:
	_cam.position -= rel_screen / _cam.zoom.x
	_clamp_cam()


func _clamp_cam() -> void:
	_cam.position.x = clampf(_cam.position.x, -PAN_MARGIN, 720.0 + PAN_MARGIN)
	_cam.position.y = clampf(_cam.position.y, 40.0, 1280.0 + PAN_MARGIN)


## 亮色统一背景：挂在屏幕空间 CanvasLayer（layer=-10），缩放/平移时始终铺满视口。
func _add_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	if ResourceLoader.exists(BG_PATH):
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(BG_PATH) as Texture2D
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.add_child(tex_rect)


func _parse_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			var n := int(arg.substr(8))
			if n > 0:
				GameState.current_level = n
		elif arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg.begins_with("--inspect="):
			_inspect_id = int(arg.substr(10))
		elif arg.begins_with("--preprune="):
			_preprune = int(arg.substr(11))
		elif arg.begins_with("--result-time="):
			_result_time = float(arg.substr(14))


## 调试：--shot=PATH 时渲染 0.8s 后截图退出（视觉冒烟）。
## --preprune=K 先剪掉 K 个可剪节点（0.2s 起，制造"枝条已释放"场景）；
## --inspect=N 在 0.55s 时模拟长按检查高亮（验证高亮逻辑对已释放对象的健壮性）。
func _process(delta: float) -> void:
	if _shot_path.is_empty() and _preprune <= 0 and _inspect_id <= 0:
		return
	_shot_timer += delta
	if _preprune > 0 and not _preprune_done and _shot_timer >= 0.2:
		_preprune_done = true
		if _result_time >= 0.0:
			runner.elapsed_time = _result_time
		for i in _preprune:
			var ids: Array[int] = runner.prunable_ids()
			if ids.is_empty():
				break
			runner.try_click(ids[0])
	if _inspect_id > 0 and not _inspect_applied and _shot_timer >= 0.55:
		_inspect_applied = true
		board.set_inspected(_inspect_id)
	if not _shot_path.is_empty() and _shot_timer >= 0.8:
		if DisplayServer.get_name() == "headless":
			push_error("截图失败：headless 模式无法读取视口纹理，请使用正常渲染模式")
			get_tree().quit(1)
			return
		var img := get_viewport().get_texture().get_image()
		if img == null:
			push_error("截图失败：当前渲染器无法读取视口纹理")
			get_tree().quit(1)
			return
		img.save_png(_shot_path)
		get_tree().quit()


func _load_current_level() -> LevelData:
	var path := "%s/level_%03d.json" % [LEVEL_DIR, GameState.current_level]
	var lv := LevelData.load_from_file(path)
	if lv == null:
		return null
	var errs := LevelValidator.validate(lv)
	if not errs.is_empty():
		for e in errs:
			push_error("关卡 %d 校验失败: %s" % [lv.id, e])
		return null
	return lv


func _on_won() -> void:
	AudioManager.play_sfx("win")
	GameState.complete_level(GameState.current_level)
	hud.clear_hint()
	hud.show_result(true, _has_next_level(), runner.result_summary())


func _on_failed() -> void:
	AudioManager.play_sfx("lose")
	hud.clear_hint()
	hud.show_result(false, false, runner.result_summary())


func _on_retry() -> void:
	get_tree().reload_current_scene()


func _on_next() -> void:
	if not _has_next_level():
		return
	GameState.current_level += 1
	get_tree().reload_current_scene()


func _on_prev() -> void:
	if GameState.current_level <= 1:
		return
	GameState.current_level -= 1
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _has_next_level() -> bool:
	var path := "%s/level_%03d.json" % [LEVEL_DIR, GameState.current_level + 1]
	return FileAccess.file_exists(path)


func _show_fatal(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.modulate = Color(1, 0.4, 0.4)
	lbl.position = Vector2(140, 620)
	add_child(lbl)
