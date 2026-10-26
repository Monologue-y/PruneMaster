extends SceneTree
## M1 headless 测试套件。
## 运行：godot --headless --path game --script res://tests/test_runner.gd
## 覆盖：图模型 / 剪枝规则 / 顺序无关定理 / 环检测 / 校验器 / 关卡文件 / 流程控制。
## 退出码：0 = 全部通过，1 = 有失败。

var _checks := 0
var _failures := 0
var _f_won := false
var _f_failed := false
var _f_tapped := false
var _f_all_pruned := false


func _init() -> void:
	print("===== PruneMaster · M1 test suite =====")
	seed(20261026)
	_test_graph_basic()
	_test_runner_flow()
	_test_result_timing()
	_test_any_order_clears()
	_test_cycle_detection()
	_test_validator()
	_test_editor_core()
	_test_board_freed_views()
	_test_inspect_sticky()
	_test_level_files()
	_test_assets()
	print("RESULT: %d checks, %d failures" % [_checks, _failures])
	if _failures == 0:
		print("ALL TESTS PASSED")
	quit(0 if _failures == 0 else 1)


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("  [FAIL] " + label)


func _flag_won() -> void:
	_f_won = true


func _flag_failed() -> void:
	_f_failed = true


func _flag_all_pruned() -> void:
	_f_all_pruned = true


func _flag_tapped(_id: int) -> void:
	_f_tapped = true


func _errs_str(errs: PackedStringArray) -> String:
	if errs.is_empty():
		return ""
	var s := ""
	for e in errs:
		s += " [" + String(e) + "]"
	return s


func _has_err(errs: PackedStringArray, substr: String) -> bool:
	for e in errs:
		if String(e).find(substr) >= 0:
			return true
	return false


func _linear_nodes() -> Array:
	return [
		{"id": 1, "pos": [360.0, 190.0], "trees": [1], "children": [2]},
		{"id": 2, "pos": [360.0, 420.0], "trees": [1], "children": [3]},
		{"id": 3, "pos": [360.0, 650.0], "trees": [1], "children": [4]},
		{"id": 4, "pos": [360.0, 880.0], "trees": [1], "children": []},
	]


## ---- 1. 图模型 ----
func _test_graph_basic() -> void:
	print("- graph model basics")
	var m := GraphModel.new(_linear_nodes())
	_check(m.total_nodes == 4, "total_nodes == 4")
	_check(not m.can_prune(1), "root not prunable")
	_check(m.can_prune(4), "leaf prunable")
	_check(not m.prune(1), "prune root rejected")
	_check(m.prune(4), "prune leaf accepted")
	_check(m.is_pruned(4) and not m.is_pruned(3), "pruned state correct")
	_check(m.alive_children_count(3) == 0, "parent alive-children updated")
	_check(m.can_prune(3), "parent becomes prunable")
	m.prune(3)
	m.prune(2)
	_check(m.pruned_count == 3, "3 pruned")
	_check(m.prune(1), "root prunable after children gone")
	_check(m.pruned_count == 4, "all pruned")
	_check(not m.prune(1), "re-prune rejected")

	var m2 := GraphModel.new(_linear_nodes())
	_f_all_pruned = false
	m2.all_pruned.connect(_flag_all_pruned)
	m2.prune(4)
	m2.prune(3)
	m2.prune(2)
	m2.prune(1)
	_check(_f_all_pruned, "all_pruned signal emitted")


## ---- 2. 流程控制 ----
func _test_runner_flow() -> void:
	print("- runner flow: win / fail / input lock")
	var lv := LevelData.from_dict({"id": 1, "lives": 3, "nodes": _linear_nodes()})
	var r := LevelRunner.new()
	r.setup(lv)
	_f_won = false
	_f_failed = false
	r.level_won.connect(_flag_won)
	r.level_failed.connect(_flag_failed)

	r.try_click(1)
	_check(r.lives == 2 and not _f_failed, "invalid click costs 1 life")
	r.try_click(4)
	r.try_click(3)
	r.try_click(2)
	r.try_click(1)
	_check(_f_won and not _f_failed and r.finished, "valid order wins")
	_check(r.lives == 2, "valid prunes cost no life")
	r.try_click(1)
	_check(r.finished and r.remaining_nodes() == 0, "input ignored after win")
	r.free()

	var r2 := LevelRunner.new()
	r2.setup(LevelData.from_dict({"id": 1, "lives": 3, "nodes": _linear_nodes()}))
	_f_failed = false
	r2.level_failed.connect(_flag_failed)
	r2.try_click(1)
	r2.try_click(2)
	_check(r2.lives == 1 and not _f_failed, "two mistakes leave 1 life")
	r2.try_click(3)
	_check(_f_failed and r2.failed and not r2.finished, "third mistake fails level")
	r2.try_click(4)
	_check(r2.remaining_nodes() == 4 and r2.lives == 0, "input locked after fail")
	r2.free()


## ---- 3. 计时与评级 ----
func _test_result_timing() -> void:
	print("- result timing and rating boundaries")
	_check(LevelRunner.s_target_for_nodes(4) == 24.0, "small level S target has minimum")
	_check(LevelRunner.s_target_for_nodes(19) == 43.0, "L1 S target scales with node count")
	_check(LevelRunner.format_time(209.9) == "03:29", "time formats as mm:ss")
	_check(LevelRunner.rating_for_time(43.0, 19) == "S", "S boundary inclusive")
	_check(LevelRunner.rating_for_time(44.0, 19) == "A", "A rating after S boundary")
	_check(LevelRunner.rating_for_time(62.0, 19) == "B", "B rating after A boundary")
	_check(LevelRunner.rating_for_time(83.0, 19) == "C", "C rating after B boundary")

	var r := LevelRunner.new()
	r.setup(LevelData.from_dict({"id": 1, "lives": 3, "nodes": _linear_nodes()}))
	r.advance_time(37.8)
	_check(is_equal_approx(r.elapsed_time, 37.8), "active runner accumulates elapsed time")
	r.try_click(4)
	r.try_click(3)
	r.try_click(2)
	r.try_click(1)
	var frozen := r.elapsed_time
	r.advance_time(10.0)
	_check(is_equal_approx(r.elapsed_time, frozen), "timer freezes after win")
	var summary := r.result_summary()
	_check(summary["time_text"] == "00:37" and summary["rating"] == "B",
		"result summary contains formatted time and rating")
	r.free()


## ---- 4. 顺序无关定理 ----
func _test_any_order_clears() -> void:
	print("- theorem: any valid order clears (10 random DAGs)")
	for iter in 10:
		var nodes := _random_dag(12 + randi() % 9)
		var m := GraphModel.new(nodes)
		var deadlock := false
		var guard := 0
		while m.pruned_count < m.total_nodes and guard < 2000:
			guard += 1
			var candidates: Array[int] = []
			for id in m.ids():
				if m.can_prune(int(id)):
					candidates.append(int(id))
			if candidates.is_empty():
				deadlock = true
				break
			if not m.prune(int(candidates[randi() % candidates.size()])):
				deadlock = true
				break
		_check(not deadlock and m.pruned_count == m.total_nodes,
			"random DAG #%d cleared by arbitrary order" % iter)


func _random_dag(count: int) -> Array:
	var nodes: Array = []
	for i in count:
		nodes.append({
			"id": 100 + i,
			"pos": [60.0 + float((i % 8) * 80), 190.0 + float((i / 8) * 230)],
			"trees": [1],
			"children": [],
		})
	for i in range(1, count):
		if randf() < 0.75:
			var parent: int = randi() % i
			var pd: Dictionary = nodes[parent]
			(pd["children"] as Array).append(100 + i)
	return nodes


## ---- 4. 环检测 ----
func _test_cycle_detection() -> void:
	print("- validator: cycle detection")
	var cyclic: Array = [
		{"id": 1, "pos": [100.0, 190.0], "trees": [1], "children": [2]},
		{"id": 2, "pos": [100.0, 420.0], "trees": [1], "children": [3]},
		{"id": 3, "pos": [100.0, 650.0], "trees": [1], "children": [1]},
	]
	var errs := LevelValidator.validate(LevelData.from_dict({"id": 9, "lives": 3, "nodes": cyclic}))
	_check(not errs.is_empty(), "cycle detected")
	_check(_has_err(errs, "环"), "cycle error message present")

	var cyclic2: Array = [
		{"id": 1, "pos": [100.0, 190.0], "trees": [1], "children": [1]},
	]
	var errs2 := LevelValidator.validate(LevelData.from_dict({"id": 9, "lives": 3, "nodes": cyclic2}))
	_check(_has_err(errs2, "环") or _has_err(errs2, "自己"), "self-loop detected")


## ---- 5. 校验器 ----
func _test_validator() -> void:
	print("- validator: malformed level data")
	var ok := LevelValidator.validate(LevelData.from_dict({"id": 1, "lives": 3, "nodes": _linear_nodes()}))
	_check(ok.is_empty(), "linear level is valid" + _errs_str(ok))

	var dangling: Array = [
		{"id": 1, "pos": [100.0, 190.0], "trees": [1], "children": [99]},
	]
	_check(_has_err(LevelValidator.validate(LevelData.from_dict({"id": 1, "lives": 3, "nodes": dangling})), "不存在"),
		"dangling child reference caught")

	var dup_id: Array = [
		{"id": 1, "pos": [100.0, 190.0], "trees": [1], "children": []},
		{"id": 1, "pos": [400.0, 190.0], "trees": [1], "children": []},
	]
	_check(_has_err(LevelValidator.validate(LevelData.from_dict({"id": 1, "lives": 3, "nodes": dup_id})), "重复"),
		"duplicate id caught")

	var dup_child: Array = [
		{"id": 1, "pos": [100.0, 190.0], "trees": [1], "children": [2, 2]},
		{"id": 2, "pos": [100.0, 650.0], "trees": [1], "children": []},
	]
	_check(_has_err(LevelValidator.validate(LevelData.from_dict({"id": 1, "lives": 3, "nodes": dup_child})), "重复引用"),
		"duplicate child reference caught")

	var too_close: Array = [
		{"id": 1, "pos": [100.0, 190.0], "trees": [1], "children": []},
		{"id": 2, "pos": [140.0, 190.0], "trees": [1], "children": []},
	]
	_check(_has_err(LevelValidator.validate(LevelData.from_dict({"id": 1, "lives": 3, "nodes": too_close})), "间距"),
		"min spacing violation caught")

	var out_of_bounds: Array = [
		{"id": 1, "pos": [10.0, 190.0], "trees": [1], "children": []},
	]
	_check(_has_err(LevelValidator.validate(LevelData.from_dict({"id": 1, "lives": 3, "nodes": out_of_bounds})), "安全区域"),
		"out-of-bounds position caught")

	var bad_lives := LevelValidator.validate(LevelData.from_dict({"id": 1, "lives": 0, "nodes": _linear_nodes()}))
	_check(_has_err(bad_lives, "lives"), "lives < 1 caught")

	var empty_nodes := LevelValidator.validate(LevelData.from_dict({"id": 1, "lives": 3, "nodes": []}))
	_check(_has_err(empty_nodes, "没有任何节点"), "empty node list caught")


## ---- 6. 关卡文件 ----
func _test_level_files() -> void:
	print("- level files: parse / validate / clearable")
	var dir := DirAccess.open("res://assets/levels")
	if dir == null:
		_check(false, "levels directory exists")
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if fname.ends_with(".json"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	_check(files.size() >= 20, "at least 20 level files (found %d)" % files.size())

	for f in files:
		var lv := LevelData.load_from_file("res://assets/levels/" + f)
		_check(lv != null, "%s parsed" % f)
		if lv == null:
			continue
		var errs := LevelValidator.validate(lv)
		_check(errs.is_empty(), "%s valid%s" % [f, _errs_str(errs)])
		var r := LevelRunner.new()
		r.setup(lv)
		var guard := 0
		while not r.finished and not r.failed and guard < 2000:
			guard += 1
			var cands: Array[int] = r.prunable_ids()
			if cands.is_empty():
				_check(false, "%s deadlocked (theorem violated)" % f)
				break
			r.try_click(int(cands[randi() % cands.size()]))
		_check(r.finished, "%s clearable by valid pruning" % f)
		_check(r.lives == r.lives_max, "%s no life lost by valid play" % f)
		r.free()


## ---- 6b. BoardView 对已释放视图健壮（剪枝动画 queue_free 后列表残留回归） ----
func _test_board_freed_views() -> void:
	print("- board view: freed branch/node views tolerated")
	var lv := LevelData.from_dict({"id": 1, "lives": 3, "nodes": _linear_nodes()})
	var r := LevelRunner.new()
	r.setup(lv)
	var b := BoardView.new()
	b.setup(lv, r)
	# 模拟回缩/消失动画结束后的对象销毁（同步 free 等价 queue_free 之后的状态）
	for c in b.get_children():
		if c is BranchView:
			(c as BranchView).free()
			break
	for c in b.get_children():
		if c is NodeView:
			(c as NodeView).free()
			break
	# 含已释放对象的列表上执行高亮/恢复不得崩溃
	b.set_inspected(3)
	var ok := false
	for c in b.get_children():
		if c is BranchView and (c as BranchView).to_id == 3:
			ok = (c as BranchView).z_index == 5
	_check(ok, "incident branch highlighted after sibling views freed")
	b.clear_inspected()
	_check(true, "clear after freed views no crash")
	b.free()
	r.free()


## ---- 6c. 常驻检查模式：轻点退出 / 长按切换不退出 / 平移不退出 / 高亮期轻点不剪枝 ----
func _test_inspect_sticky() -> void:
	print("- inspect sticky: tap exits, long-press switch keeps, pan keeps, tap suppressed")
	var lv := LevelData.from_dict({"id": 1, "lives": 3, "nodes": _linear_nodes()})
	var r := LevelRunner.new()
	r.setup(lv)
	var b := BoardView.new()
	b.setup(lv, r)
	# 合成触摸事件（空白处轻点）
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.index = 0
	down.position = Vector2(600, 1100)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.index = 0
	up.position = Vector2(600, 1100)
	var up_far := InputEventScreenTouch.new()
	up_far.pressed = false
	up_far.index = 0
	up_far.position = Vector2(200, 400)
	# 1. 高亮常驻：set 之后不自动消失；轻点退出
	b.set_inspected(3)
	_check(b.is_inspecting(), "inspect stays after long-press (sticky)")
	b._input(down)
	b._input(up)
	_check(not b.is_inspecting(), "tap exits sticky inspect")
	# 2. 按压期间触发长按检查（切换目标）→ 松手不清除
	b.set_inspected(3)
	b._input(down)
	b.set_inspected(4)  # 模拟按压 0.3s 后长按触发
	b._input(up)
	_check(b._inspected_id == 4, "long-press switch survives release")
	# 3. 大位移（平移）不退出高亮
	b.set_inspected(3)
	b._input(down)
	b._input(up_far)
	_check(b._inspected_id == 3, "pan does not exit inspect")
	# 4. 多指（捏合）不退出高亮
	b._input(down)
	var down2 := InputEventScreenTouch.new()
	down2.pressed = true
	down2.index = 1
	down2.position = Vector2(620, 1100)
	var up2 := InputEventScreenTouch.new()
	up2.pressed = false
	up2.index = 1
	up2.position = Vector2(620, 1100)
	b._input(down2)
	b._input(up)
	b._input(up2)  # 两个手指的松开事件成对到达，触点计数归零
	_check(b._inspected_id == 3, "pinch does not exit inspect")
	# 5. 高亮激活时轻点节点：不触发剪枝点击；清除后恢复剪枝
	var v: NodeView = null
	for c in b.get_children():
		if c is NodeView and (c as NodeView).node_id == 3:
			v = c as NodeView
	_f_tapped = false
	v.clicked.connect(_flag_tapped)
	b.set_inspected(2)
	v._begin_press(v.position, -2)
	v._end_press(v.position)
	_check(not _f_tapped, "tap on node suppressed while inspecting")
	b.clear_inspected()
	v._begin_press(v.position, -2)
	v._end_press(v.position)
	_check(_f_tapped, "tap prunes after inspect cleared")
	# 6. 模拟 emulate_touch_from_mouse / emulate_mouse_from_touch 的双事件派发
	# （一次物理按压 = 鼠标 + 触摸两个事件），去重后仍能正常退出高亮
	b.set_inspected(3)
	var mdown := InputEventMouseButton.new()
	mdown.button_index = MOUSE_BUTTON_LEFT
	mdown.pressed = true
	mdown.position = Vector2(600, 1100)
	var mup := InputEventMouseButton.new()
	mup.button_index = MOUSE_BUTTON_LEFT
	mup.pressed = false
	mup.position = Vector2(600, 1100)
	b._input(mdown)
	b._input(down)
	b._input(mup)
	b._input(up)
	_check(not b.is_inspecting(), "emulated mouse+touch double events still exit inspect")
	# 反向顺序（触摸先到）同样可行
	b.set_inspected(3)
	b._input(down)
	b._input(mdown)
	b._input(up)
	b._input(mup)
	_check(not b.is_inspecting(), "reversed double events still exit inspect")
	b.free()
	r.free()


## ---- 7. 编辑器核心 ----
func _test_editor_core() -> void:
	print("- editor core: add/link/share/remove/roundtrip")
	var ec := LevelEditorCore.new()
	ec.create(99)
	var a := ec.add_node(Vector2(100, 190), 1)
	var b := ec.add_node(Vector2(100, 420), 1)
	var c := ec.add_node(Vector2(300, 420), 2)
	var d := ec.add_node(Vector2(300, 650), 2)
	_check(ec.node_count() == 4, "4 nodes added")
	_check(ec.trees_of(b) == [1], "tree assigned to new node")

	# 同树连线
	_check(ec.link(a, b), "same-tree link ok")
	# 跨树连线 → 自动共享（并集）
	_check(ec.link(a, c), "cross-tree link ok")
	var ct: Array = ec.trees_of(c)
	_check(ct.size() == 2 and ct.has(1) and ct.has(2), "child auto-shared (union)")
	# 向上连线 / 连祖先 / 重复 / 浅行 一律被拒
	_check(not ec.link(c, a), "upward link rejected")
	_check(not ec.link(b, a), "link to ancestor rejected")
	_check(not ec.link(a, b), "duplicate link rejected")
	_check(not ec.link(d, c), "link to shallower row rejected")

	# 树并集上限 3
	var e := ec.add_node(Vector2(500, 880), 3)
	_check(ec.link(c, e), "union of 3 trees allowed")
	_check(ec.trees_of(e).size() == 3, "e has 3 trees after union")
	var g := ec.add_node(Vector2(620, 650), 4)
	_check(not ec.link(g, e), "union cap (3) enforced")

	# 删除节点与引用清理
	var a_children: Array = ec.children_of(a).duplicate()
	_check(a_children.has(b), "a children contains b before removal")
	_check(ec.remove_node(b), "remove node ok")
	_check(not (ec.children_of(a) as Array).has(b), "references cleaned after removal")
	_check(not ec.has_node(b), "removed node gone")

	# 导出 → 校验 → 贪心可清空
	var data := ec.to_dict()
	var lv := LevelData.from_dict(data)
	var errs := LevelValidator.validate(lv)
	_check(errs.is_empty(), "editor level valid" + _errs_str(errs))
	var r := LevelRunner.new()
	r.setup(lv)
	var guard := 0
	while not r.finished and not r.failed and guard < 500:
		guard += 1
		var cands: Array[int] = r.prunable_ids()
		if cands.is_empty():
			break
		r.try_click(int(cands[0]))
	_check(r.finished, "editor level clearable")
	r.free()

	# 保存 → 重新加载 roundtrip
	var path := "user://test_editor_level.json"
	var save_errs := ec.save_to(path)
	_check(save_errs.is_empty(), "editor save ok" + _errs_str(save_errs))
	var ec2 := LevelEditorCore.new()
	_check(ec2.load_level(path), "editor load ok")
	_check(ec2.node_count() == ec.node_count(), "roundtrip node count matches")
	_check((ec2.children_of(a) as Array).has(c), "roundtrip children preserved")
	_check((ec2.trees_of(c) as Array).size() == 2, "roundtrip shared trees preserved")


## ---- 8. 美术与音频资产 ----
func _test_assets() -> void:
	print("- art & audio assets: files present and importable")
	var paths: Array[String] = [
		"res://assets/fonts/NotoSansSC-Regular.otf",
		"res://assets/fonts/NotoSansSC-Bold.otf",
		"res://assets/art/backgrounds/bg_bright.png",
		"res://assets/art/bark/bark_tile.png",
		"res://assets/art/buds/foliage_green.png",
		"res://assets/art/particles/leaf_01.png",
		"res://assets/art/particles/chip_01.png",
		"res://assets/audio/snip.wav",
		"res://assets/audio/error.wav",
		"res://assets/audio/win.wav",
		"res://assets/audio/lose.wav",
		"res://assets/audio/click.wav",
		"res://assets/audio/bgm_wind.wav",
	]
	for p in paths:
		_check(FileAccess.file_exists(p), "file exists: %s" % p)
		_check(ResourceLoader.exists(p), "imported resource: %s" % p)
