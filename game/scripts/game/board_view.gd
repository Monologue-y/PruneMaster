class_name BoardView
extends Node2D
## 根据 LevelData 构建 NodeView / BranchView，并把 LevelRunner 的信号接到动画。
## 绘制顺序：先树枝（下层），后芽苞节点（上层）。
## 点错反馈：节点抖红 + 棋盘横向微震。
## 检查模式（长按节点）：本节点真正连接的枝条与相邻节点保持全亮/亮圈，其余压暗，
## 解决密集关卡中"过路枝条"与"连接枝条"难以分辨的问题。
## 高亮为常驻：长按进入后松手不退出；再次轻点任意处（空白或节点）退出，
## 高亮期间的轻点不会触发剪枝；拖拽平移/双指捏合不打断高亮。

const DIM_BRANCH := Color(1, 1, 1, 0.16)
const DIM_NODE := Color(1, 1, 1, 0.30)
const EXIT_TAP_TOL := 18.0  # 退出高亮的轻点位移容差（屏幕像素）
const DEDUP_MSEC := 80      # 重复按压去重窗口（毫秒）
const DEDUP_DIST := 4.0     # 重复按压去重距离（像素）

var _node_views: Dictionary = {}  # id -> NodeView
var _in_links: Dictionary = {}    # child_id -> Array[BranchView]
var _parents: Dictionary = {}     # id -> Array[int]
var _branches: Array = []         # Array[BranchView]
var _level: LevelData
var _inspected_id: int = -1
# 轻点退出高亮的按压跟踪（多指捏合不视为轻点）
var _touch_count := 0
var _multi_touch := false
var _exit_press_active := false
var _exit_press_pos := Vector2.ZERO
var _exit_press_index := -1
var _press_had_inspect := false        # 本次按下时检查模式是否已激活
var _inspect_started_in_press := false # 本次按压期间是否（再次）触发了长按检查
var _last_press_msec := -10000         # 上一次有效按下的时刻（用于触摸/鼠标双事件去重）
var _shake_tween: Tween


func setup(level: LevelData, runner: LevelRunner) -> void:
	_level = level
	# 树枝（绘制在节点下层）
	for n in level.nodes:
		var nd: Dictionary = n
		var pid := int(nd.get("id", -1))
		var pa := level.pos_of(pid)
		for c in nd.get("children", []):
			var cid := int(c)
			var link := BranchView.new()
			link.setup(pid, cid, pa, level.pos_of(cid))
			add_child(link)
			_branches.append(link)
			if not _in_links.has(cid):
				_in_links[cid] = []
			(_in_links[cid] as Array).append(link)
			if not _parents.has(cid):
				_parents[cid] = []
			(_parents[cid] as Array).append(pid)
	# 叶簇节点（统一绿色）
	for n in level.nodes:
		var nd: Dictionary = n
		var id := int(nd.get("id", -1))
		var trees: Array = nd.get("trees", [1])
		var v := NodeView.new()
		v.node_id = id
		v.position = level.pos_of(id)
		v.is_shared = trees.size() > 1
		v.clicked.connect(runner.try_click)
		v.inspect_started.connect(_on_inspect_started)
		add_child(v)
		_node_views[id] = v
	# 信号 → 动画
	runner.node_pruned.connect(_on_node_pruned)
	runner.prune_rejected.connect(_on_rejected)


## 进入/退出检查模式：高亮 id 的连接关系，其余压暗（id <= 0 时恢复）。
func set_inspected(id: int) -> void:
	_inspected_id = id
	if id > 0:
		_inspect_started_in_press = true
	var related := {}
	if id > 0:
		related[id] = true
		for p in (_parents.get(id, []) as Array):
			related[int(p)] = true
		if _level != null:
			for c in _level.children_of(id):
				related[int(c)] = true
	for link in _branches:
		# 枝条回缩动画结束后会被 queue_free，列表中可能残留已释放对象
		if not is_instance_valid(link):
			continue
		var l := link as BranchView
		var incident: bool = id > 0 and (l.from_id == id or l.to_id == id)
		l.modulate = Color(1, 1, 1, 1) if incident else (DIM_BRANCH if id > 0 else Color(1, 1, 1, 1))
		l.z_index = 5 if incident else 0
	for nid in _node_views:
		var raw = _node_views[nid]
		if not is_instance_valid(raw):
			continue
		var v := raw as NodeView
		var on: bool = id <= 0 or related.has(nid)
		v.modulate = Color(1, 1, 1, 1) if on else DIM_NODE
		v.set_highlight(id > 0 and related.has(nid) and int(nid) != id)


func clear_inspected() -> void:
	set_inspected(-1)


func is_inspecting() -> bool:
	return _inspected_id > 0


func _on_inspect_started(node_id: int) -> void:
	set_inspected(node_id)


## 轻点退出常驻高亮：跟踪首个触点的按下/松开；仅当"按下时已在检查模式、
## 按压期间没有新触发长按检查、非多指、位移 ≤ 容差"时才视为退出轻点。
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_track_press(event.position, event.index)
		else:
			_track_release(event.position, event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_track_press(event.position, -2)
		else:
			_track_release(event.position, -2)


func _track_press(pos: Vector2, index: int) -> void:
	# 去重：emulate_touch_from_mouse / emulate_mouse_from_touch 会把一次物理按压
	# 同时派发为"触摸 + 鼠标"两个事件；极短间隔内同位置的第二个按压视为同一指/鼠标。
	var now := Time.get_ticks_msec()
	if _exit_press_active and _touch_count == 1 \
			and now - _last_press_msec < DEDUP_MSEC \
			and _exit_press_pos.distance_to(pos) < DEDUP_DIST:
		return
	_last_press_msec = now
	_touch_count += 1
	if _touch_count == 1:
		_multi_touch = false
		_exit_press_active = true
		_exit_press_pos = pos
		_exit_press_index = index
		_press_had_inspect = _inspected_id > 0
		_inspect_started_in_press = false
	else:
		_multi_touch = true


func _track_release(pos: Vector2, index: int) -> void:
	_touch_count = maxi(0, _touch_count - 1)
	if not _exit_press_active or index != _exit_press_index:
		return
	_exit_press_active = false
	if _press_had_inspect and not _inspect_started_in_press and not _multi_touch \
			and _exit_press_pos.distance_to(pos) <= EXIT_TAP_TOL:
		clear_inspected()


func _on_node_pruned(node_id: int) -> void:
	clear_inspected()
	if _in_links.has(node_id):
		for link in _in_links[node_id] as Array:
			(link as BranchView).play_retract()
	if _node_views.has(node_id):
		(_node_views[node_id] as NodeView).play_prune()


func _on_rejected(node_id: int) -> void:
	if _node_views.has(node_id):
		(_node_views[node_id] as NodeView).play_reject()
	_play_shake()


## 棋盘微震：0.28s 衰减正弦横移。
func _play_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(_shake_offset, 0.0, 1.0, 0.28)


func _shake_offset(f: float) -> void:
	var amp: float = 7.0 * (1.0 - f)
	position = Vector2(sin(f * TAU * 7.0) * amp, 0.0)
