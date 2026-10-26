class_name NodeView
extends Area2D
## 节点视图（M3：叶簇贴图 + 剪枝粒子迸发；纹理缺失时回退到 M1 灰盒圆形）。
## 动画：剪枝 = 颤抖 → 粒子迸发 → 缩放消失；点错 = 抖红闪。
## 交互：松手判定（tap）剪枝；长按 ≥0.3s 进入"检查模式"——高亮本节点真正连接的
## 枝条与相邻节点、压暗其余（密集关卡下分辨"连接"与"路过"）。高亮为**常驻**：
## 松手不退出（也不剪枝），再次轻点任意处才退出；高亮期间的轻点一律不触发剪枝。

signal clicked(node_id: int)
signal inspect_started(node_id: int)

enum State { ALIVE, PRUNING, GONE }

const BUD_PATH := "res://assets/art/buds/foliage_green.png"   # 统一绿色叶簇
const CHIP_PATH := "res://assets/art/particles/chip_01.png"
const LEAF_PATH := "res://assets/art/particles/leaf_01.png"

const DEFAULT_RADIUS := 34.0
const SHARED_COLOR := Color(1.0, 0.55, 0.10)  # 灰盒模式共享节点色
const FLASH_COLOR := Color(0.95, 0.22, 0.15)  # 点错反馈：红
const INSPECT_DELAY := 0.30                    # 长按进入检查模式的时长（秒）
const INSPECT_RING := Color(1.0, 0.97, 0.75, 0.95)  # 检查高亮圈（暖白）

var node_id: int = -1
var radius: float = DEFAULT_RADIUS
var color: Color = Color(0.45, 0.70, 0.35)   # 灰盒兜底主色（统一绿）
var border_color: Color = Color(0.16, 0.38, 0.13)
var is_shared: bool = false

var _state: State = State.ALIVE
var _flash: bool = false
var _home: Vector2 = Vector2.ZERO
var _bud: Texture2D
var _pressing: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_index: int = -1     # 触点数（多指捏合时只响应本指）
var _moved: bool = false
var _inspecting: bool = false
var _press_token: int = 0      # 使过期长按定时器失效
var _highlight: bool = false   # 检查模式中被 BoardView 标记为相关节点
var _press_had_inspect := false  # 本次按下时检查模式是否已激活


func _ready() -> void:
	_home = position
	input_pickable = true
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	add_child(cs)
	_bud = load(BUD_PATH) as Texture2D
	queue_redraw()


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _state != State.ALIVE:
		return
	# 只在这里捕获"按下"（需在节点范围内）；松开在 _input 全局处理（手指可能滑出节点）。
	if event is InputEventScreenTouch and event.pressed:
		_begin_press(event.position, event.index)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_begin_press(event.position, -2)


## 全局输入：松开 / 移动跟踪（松开时手指/光标可能已不在节点上，_input_event 收不到）。
func _input(event: InputEvent) -> void:
	if not _pressing and not _inspecting:
		return
	if event is InputEventScreenDrag and event.index == _press_index:
		if _press_pos.distance_to(event.position) > _tap_tolerance():
			_moved = true
	elif event is InputEventMouseMotion and _press_index == -2:
		if _press_pos.distance_to(event.position) > _tap_tolerance():
			_moved = true
	elif event is InputEventScreenTouch and not event.pressed and event.index == _press_index:
		_end_press(event.position)
	elif event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _press_index == -2:
		_end_press(event.position)


func _begin_press(pos: Vector2, index: int) -> void:
	_pressing = true
	_press_pos = pos
	_press_index = index
	_moved = false
	var board := get_parent() as BoardView
	_press_had_inspect = board != null and board.is_inspecting()
	_press_token += 1
	if is_inside_tree():
		var token := _press_token
		get_tree().create_timer(INSPECT_DELAY).timeout.connect(_maybe_inspect.bind(token))


func _end_press(pos: Vector2) -> void:
	_press_token += 1
	if _inspecting:
		# 长按进入的检查模式为常驻高亮：松手只结束本次按压，不剪枝、不退出高亮
		_inspecting = false
		_pressing = false
		return
	var was_pressing := _pressing
	_pressing = false
	if was_pressing and _state == State.ALIVE \
			and _press_pos.distance_to(pos) <= _tap_tolerance():
		if _press_had_inspect:
			# 检查模式激活中的轻点 = 退出高亮（由 BoardView 统一清除），不剪枝
			return
		clicked.emit(node_id)


## 长按计时到点：仍按住且未移动 → 进入检查模式。
func _maybe_inspect(token: int) -> void:
	if token != _press_token or not _pressing or _moved or _inspecting:
		return
	if _state != State.ALIVE:
		return
	_inspecting = true
	inspect_started.emit(node_id)


## 点击位移容差（世界坐标像素；相机放大时换算为更小的世界容差）
func _tap_tolerance() -> float:
	var z := 1.0
	var cam := get_viewport().get_camera_2d() if get_viewport() != null else null
	if cam != null:
		z = cam.zoom.x
	return 18.0 / maxf(z, 0.01)


## 检查模式：被标记为"与检查节点相连"时点亮高亮圈（由 BoardView 调用）。
func set_highlight(on: bool) -> void:
	if _highlight == on:
		return
	_highlight = on
	queue_redraw()


func _draw() -> void:
	if _state == State.GONE:
		return
	if _bud != null:
		var tint := Color.WHITE
		if _flash:
			tint = FLASH_COLOR
		var sz := _bud.get_size()
		draw_texture_rect(_bud, Rect2(-sz * 0.375, sz * 0.75), false, tint)
		# 共享节点不再画圈标记（是否共享由枝条连接关系表达；长按可检查）
		if _highlight:
			draw_arc(Vector2.ZERO, radius + 13.0, 0.0, TAU, 40, INSPECT_RING, 5.0, true)
	else:
		# 灰盒兜底（与 M1 相同）
		var fill := color
		var border := border_color
		if is_shared:
			fill = SHARED_COLOR
			border = Color(0.35, 0.15, 0.0)
		if _flash:
			fill = FLASH_COLOR
			border = Color(0.30, 0.03, 0.0)
		draw_circle(Vector2.ZERO, radius, fill)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, border, 5.0, true)
		if is_shared:
			draw_arc(Vector2.ZERO, radius - 11.0, 0.0, TAU, 32, Color(1, 1, 1, 0.65), 3.0, true)


## 剪枝动画：颤抖 0.3s → 粒子迸发 → 缩放消失。
func play_prune() -> void:
	if _state != State.ALIVE:
		return
	_state = State.PRUNING
	input_pickable = false
	var t := create_tween()
	t.tween_method(_shake, 0.0, 1.0, 0.3)
	t.tween_callback(_vanish)


## 点错动画：抖红闪一下。
func play_reject() -> void:
	if _state != State.ALIVE:
		return
	_flash = true
	queue_redraw()
	var t := create_tween()
	t.tween_method(_shake, 0.0, 1.0, 0.25)
	t.tween_callback(_reset_after_flash)


func _shake(f: float) -> void:
	position = _home + Vector2(sin(f * TAU * 5.0) * 5.0, 0.0)


func _vanish() -> void:
	_state = State.GONE
	queue_redraw()
	_spawn_burst()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(0.05, 0.05), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.chain().tween_callback(queue_free)


func _reset_after_flash() -> void:
	_flash = false
	position = _home
	queue_redraw()


## 木屑 + 落叶迸发。粒子挂到 BoardView（父节点）下，避免跟随本节点的缩放。
func _spawn_burst() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_burst(parent, CHIP_PATH, 9, 0.5, 130.0, 260.0, Vector2(0, 760), 0.55, 1.2, 0.0, 0.0)
	_burst(parent, LEAF_PATH, 5, 0.95, 60.0, 150.0, Vector2(0, 230), 0.8, 1.35, 120.0, 360.0)


func _burst(parent: Node, tex_path: String, amount: int, life: float,
		v_min: float, v_max: float, grav: Vector2,
		s_min: float, s_max: float, ang_min: float, ang_max: float) -> void:
	var tex := load(tex_path) as Texture2D
	if tex == null:
		return
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = grav
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	if ang_max > 0.0:
		p.angular_velocity_min = deg_to_rad(ang_min)
		p.angular_velocity_max = deg_to_rad(ang_max)
	p.position = _home
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.6).timeout.connect(_free_later.bind(p))


func _free_later(p: CPUParticles2D) -> void:
	if is_instance_valid(p):
		p.queue_free()
