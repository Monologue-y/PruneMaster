extends SceneTree
## 关卡生成器（headless 工具，M2；v3：全关卡随机散布 + 周期从第 1 关起算）。
##
## 用法：
##   godot --headless --path game --script res://tools/level_generator.gd -- --start=2 --count=19
##
## 生成 level_002 ~ level_020（level_001 为手工教学关，不覆盖）。
##
## 周期难度（以 4 关为周期循环，从第 1 关起算；不再线性递增）：
##   pos = (level-1) % 4：0 → 简单（26 节点/3 树）；1、2 → 中等（52 节点/4 树）；
##   3 → 困难（100 节点/6 树）。第 4 周期起共享桥 +1，微弱递增。
##   即：L1 简(教程) L2 中 L3 中 L4 难 | L5 简 L6 中 L7 中 L8 难 | … | L20 难。
##
## 布局：所有难度统一"位置与树结构完全解耦"——蜂窝点阵随机旋转 ±10° 散布后随机连边，
## 玩家无法靠位置套路解题，必须读枝条方向（宽端=父、尖端=子）。难度差异由节点数承载。
##
## 保证（由构造保证 + LevelValidator 二次校验）：
## - 任意两点间距 ≥ MIN_SPACING、均在边界内（蜂窝间距 81 = 76 校验 + 双向抖动余量）
## - 边只由先创建的父指向后创建的子 → DAG 无环；贪心剪枝模拟必可清空
## 每关最多重试 150 个种子，仍失败则退出码 1。

const OUT_DIR := "res://assets/levels"

## 难度分档
const TIERS := {
	"easy":   {"nodes": 26,  "trees": 3, "shared": 1},
	"medium": {"nodes": 52,  "trees": 4, "shared": 2},
	"hard":   {"nodes": 100, "trees": 6, "shared": 4},
}

const MAX_KIDS := 3        # 单节点最大子数（防止超密分叉）
const SCATTER_GAP := 81.0  # 蜂窝点阵间距（= MIN_SPACING 76 + 双向抖动 3.6 + 余量）
const LINK_RANGE := 260.0  # 父节点选择的最大邻域
const LINK_RANGE_RELAX := 420.0

var _failures := 0


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.find("=") > 0:
			var kv := a.split("=")
			args[kv[0].substr(2)] = kv[1]
	var start := int(args.get("start", 2))
	var count := int(args.get("count", 19))
	var generated := 0
	for lvl in range(start, start + count):
		if lvl == 1:
			continue  # 手工教学关不覆盖
		if _generate(lvl):
			generated += 1
		else:
			_failures += 1
	print("GENERATED %d / %d levels" % [generated, count])
	quit(0 if _failures == 0 else 1)


## level -> { tier, cyc }（周期从第 1 关起算）
static func tier_of(lvl: int) -> Dictionary:
	var i := lvl - 1
	var pos := i % 4
	var cyc := i / 4
	if pos == 0:
		return {"tier": "easy", "cyc": cyc}
	elif pos == 3:
		return {"tier": "hard", "cyc": cyc}
	return {"tier": "medium", "cyc": cyc}


func _generate(lvl: int) -> bool:
	var info: Dictionary = tier_of(lvl)
	var tier: Dictionary = TIERS[info["tier"]]
	for attempt in 150:
		seed(7000 + lvl * 131 + attempt * 17)
		var data := _build(lvl, tier, int(info["cyc"]))
		if data.is_empty():
			continue
		var lv := LevelData.from_dict(data)
		var errs := LevelValidator.validate(lv)
		if not errs.is_empty():
			print("  level %03d attempt %d invalid: %s" % [lvl, attempt, errs[0]])
			continue
		_write(lvl, data)
		var shared := 0
		for n in data["nodes"]:
			if (n["trees"] as Array).size() > 1:
				shared += 1
		print("  level %03d OK [%s]: %d nodes, %d trees, %d shared" % [lvl, info["tier"], data["nodes"].size(), data["trees"].size(), shared])
		return true
	push_error("level %d generation failed after 150 attempts" % lvl)
	return false


func _build(lvl: int, tier: Dictionary, cyc: int) -> Dictionary:
	var tree_count: int = int(tier["trees"])
	var node_count: int = int(tier["nodes"])
	var target_shared: int = int(tier["shared"]) + (1 if cyc >= 3 else 0)

	var nodes: Array = []       # { pos: Vector2, trees: Array, parents: Dictionary(set), dir: float }
	var kids_count := {}        # node index -> 孩子数

	if not _scatter_place(nodes, node_count):
		return {}
	_scatter_link(nodes, tree_count, kids_count)
	_scatter_share(nodes, target_shared, kids_count)

	# 每关至少 1 个共享节点
	var shared_count := 0
	for n in nodes:
		if (n["trees"] as Array).size() > 1:
			shared_count += 1
	if shared_count < 1:
		return {}

	# id 分配（按创建序：父先于子，天然拓扑序）与 children 收集
	var children_map := {}
	for i in nodes.size():
		for pj in (nodes[i]["parents"] as Dictionary).keys():
			var key: int = int(pj)
			if not children_map.has(key):
				children_map[key] = []
			(children_map[key] as Array).append(i + 1)
	var out_nodes: Array = []
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var pos: Vector2 = n["pos"]
		var kids: Array = (children_map.get(i, []) as Array).duplicate()
		kids.sort()
		out_nodes.append({
			"id": i + 1,
			"trees": (n["trees"] as Array).duplicate(),
			"pos": [int(round(pos.x)), int(round(pos.y))],
			"children": kids,
		})
	var trees_meta: Array = []
	for t in tree_count:
		trees_meta.append({"id": t + 1, "name": "Tree %d" % (t + 1)})
	return {
		"id": lvl,
		"name": "Level %d" % lvl,
		"lives": 3,
		"trees": trees_meta,
		"nodes": out_nodes,
	}


# ---------------------------------------------------------------- 纯随机散布

## 位置与树结构完全解耦：六边形蜂窝点阵（密度最优）+ 小角度随机旋转（±10°）
## + 微抖动 → 无轴向行列感，再随机连边。
## 纯随机泊松散布在 100 节点密度下放不下（面积上限约 85）；旋转方阵 >18° 也装不下。
func _scatter_place(nodes: Array, count: int) -> bool:
	var theta := randf_range(-PI / 18.0, PI / 18.0)  # ±10°（离线验证容量 104+ ≥ 100）
	var ct := cos(theta)
	var st := sin(theta)
	var row_h := SCATTER_GAP * sqrt(3.0) / 2.0
	var center := Vector2(360.0, 660.0)
	var pts: Array = []
	var r := 0
	var y := 157.0
	while y <= 1158.0:
		var x: float = 52.0 + (SCATTER_GAP * 0.5 if r % 2 == 1 else 0.0)
		while x <= 668.0:
			# 绕棋盘中心旋转
			var d := Vector2(x, y) - center
			var p := Vector2(d.x * ct - d.y * st, d.x * st + d.y * ct) + center
			if p.x >= 50.0 and p.x <= 670.0 and p.y >= 155.0 and p.y <= 1160.0:
				pts.append(p)
			x += SCATTER_GAP
		y += row_h
		r += 1
	if pts.size() < count:
		return false
	pts.shuffle()
	for i in count:
		# 多次尝试抖动（已放置邻居也带抖动，单次成功率约 80%，20 次几乎必成）
		var placed := false
		for _try in 20:
			var p: Vector2 = pts[i] + Vector2(randf_range(-1.8, 1.8), randf_range(-1.8, 1.8))
			if _far_from_all(nodes, p, LevelValidator.MIN_SPACING + 0.5):
				nodes.append({"pos": p, "trees": [], "parents": {}, "dir": randf() * TAU})
				placed = true
				break
		if not placed:
			var p0: Vector2 = pts[i]
			if _far_from_all(nodes, p0, LevelValidator.MIN_SPACING + 0.5):
				nodes.append({"pos": p0, "trees": [], "parents": {}, "dir": randf() * TAU})
	return nodes.size() >= count - 4


## 随机连边：随机顺序，前 T 个为根；其余轮流接入长得最少的树，父节点在邻域内随机选。
func _scatter_link(nodes: Array, tree_count: int, kids_count: Dictionary) -> void:
	var order: Array = range(nodes.size())
	order.shuffle()
	var grown_of: Array[int] = []
	for t in tree_count:
		grown_of.append(0)
	for t in tree_count:
		nodes[order[t]]["trees"] = [t + 1]
		grown_of[t] = 1
	for k in range(tree_count, order.size()):
		# 选长得最少的树（随机破平）
		var t := 0
		var best_g := 1e9
		for x in tree_count:
			var sc := float(grown_of[x]) + randf() * 0.5
			if sc < best_g:
				best_g = sc
				t = x
		var parent := _scatter_pick_parent(nodes, t + 1, (nodes[order[k]] as Dictionary)["pos"], kids_count)
		if parent < 0:
			parent = order[t]  # 兜底：直接挂根（不应发生）
		(nodes[order[k]] as Dictionary)["trees"] = [t + 1]
		(nodes[order[k]] as Dictionary)["parents"][parent] = true
		kids_count[parent] = int(kids_count.get(parent, 0)) + 1
		grown_of[t] += 1


func _scatter_pick_parent(nodes: Array, tree_id: int, pos: Vector2, kids_count: Dictionary) -> int:
	for range_limit in [LINK_RANGE, LINK_RANGE_RELAX, 9999.0]:
		var cands: Array[int] = []
		for i in nodes.size():
			var n: Dictionary = nodes[i]
			var trees: Array = n["trees"]
			if trees.size() != 1 or int(trees[0]) != tree_id:
				continue
			if int(kids_count.get(i, 0)) >= MAX_KIDS:
				continue
			if (n["pos"] as Vector2).distance_to(pos) > range_limit:
				continue
			cands.append(i)
		if not cands.is_empty():
			return cands[randi() % cands.size()]
	return -1


## 共享：给已有节点增加一个不同树的父节点（不新增节点，密集布局下更稳定）
func _scatter_share(nodes: Array, target: int, kids_count: Dictionary) -> void:
	var shared := 0
	var guard := 0
	while shared < target and guard < 300:
		guard += 1
		var i := randi() % nodes.size()
		var n: Dictionary = nodes[i]
		var mytrees: Array = n["trees"]
		if mytrees.size() != 1:
			continue
		# 找一个不同树、距离适中的节点当第二父
		for _try in 24:
			var j := randi() % nodes.size()
			if j == i:
				continue
			var p: Dictionary = nodes[j]
			var pt: Array = p["trees"]
			if pt.is_empty() or int(pt[0]) == int(mytrees[0]):
				continue
			if (p["pos"] as Vector2).distance_to(n["pos"]) > LINK_RANGE_RELAX:
				continue
			var union := _tree_union(mytrees, pt)
			if union.size() > 3:
				continue
			(n["parents"] as Dictionary)[j] = true
			n["trees"] = union
			kids_count[j] = int(kids_count.get(j, 0)) + 1
			shared += 1
			break


# ---------------------------------------------------------------- 共用工具

func _far_from_all(nodes: Array, pos: Vector2, min_d: float) -> bool:
	for n in nodes:
		if (n["pos"] as Vector2).distance_to(pos) < min_d:
			return false
	return true


func _tree_union(a: Array, b: Array) -> Array:
	var u := a.duplicate()
	for t in b:
		if not u.has(t):
			u.append(t)
	u.sort()
	return u


func _write(lvl: int, data: Dictionary) -> void:
	var path := "%s/level_%03d.json" % [OUT_DIR, lvl]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("无法写入 %s" % path)
		return
	f.store_string(JSON.stringify(data, "  ") + "\n")
	f.close()
