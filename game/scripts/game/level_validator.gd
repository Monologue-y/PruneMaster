class_name LevelValidator
extends RefCounted
## 关卡数据静态校验器。所有关卡（手写/编辑器产出）必须 100% 通过后才能进入游戏。
## 返回 PackedStringArray 错误列表；空列表 = 合法。
## 规则明细见 docs/level_format.md。

const MIN_SPACING := 76.0      # 节点最小间距（设计分辨率像素）
const DESIGN_W := 720.0
const DESIGN_H := 1280.0
const MARGIN_X := 40.0
const MARGIN_TOP := 140.0      # 顶部 HUD 区
const MARGIN_BOTTOM := 110.0   # 底部 HUD 区


static func validate(level: LevelData) -> PackedStringArray:
	var errs := PackedStringArray()
	if level == null:
		errs.append("level 为空")
		return errs
	if level.nodes.is_empty():
		errs.append("关卡没有任何节点")
		return errs
	if level.lives < 1:
		errs.append("lives 必须 >= 1（当前 %d）" % level.lives)

	# --- 节点字段与 id 唯一性 ---
	var ids := {}
	for i in level.nodes.size():
		var n: Variant = level.nodes[i]
		if not (n is Dictionary):
			errs.append("nodes[%d] 不是对象" % i)
			continue
		var nd: Dictionary = n
		if not nd.has("id"):
			errs.append("nodes[%d] 缺少 id" % i)
			continue
		var id := int(nd["id"])
		if ids.has(id):
			errs.append("节点 id 重复: %d" % id)
		ids[id] = i

		if not _pos_valid(nd, id, errs):
			continue

	# --- children 引用（存在性 / 重复 / 自引用） ---
	for n in level.nodes:
		var nd: Dictionary = n
		var id := int(nd.get("id", -1))
		var seen := {}
		for c in nd.get("children", []):
			var cid := int(c)
			if cid == id:
				errs.append("节点 %d 的 children 引用了自己" % id)
			if seen.has(cid):
				errs.append("节点 %d 的 children 重复引用 %d（会导致永久不可剪）" % [id, cid])
			seen[cid] = true
			if not ids.has(cid):
				errs.append("节点 %d 的 child %d 不存在（悬空引用）" % [id, cid])

	# --- 间距 ---
	var positions: Array = []
	for n in level.nodes:
		var nd: Dictionary = n
		if nd.has("pos") and (nd["pos"] is Array) and (nd["pos"] as Array).size() == 2:
			var p: Array = nd["pos"]
			positions.append([int(nd.get("id", -1)), Vector2(float(p[0]), float(p[1]))])
	for i in positions.size():
		var a: Array = positions[i]
		var va: Vector2 = a[1]
		for j in range(i + 1, positions.size()):
			var b: Array = positions[j]
			var dist: float = va.distance_to(b[1])
			if dist < MIN_SPACING - 0.01:
				errs.append("节点 %d 与 %d 间距 %.1f < %.1f" % [a[0], b[0], dist, MIN_SPACING])

	# --- 环检测（Kahn 拓扑排序）——唯一的死局来源 ---
	var cycle_msg := _cycle_check(level.nodes, ids)
	if not cycle_msg.is_empty():
		errs.append(cycle_msg)
	return errs


static func _pos_valid(nd: Dictionary, id: int, errs: PackedStringArray) -> bool:
	if not nd.has("pos") or not (nd["pos"] is Array) or (nd["pos"] as Array).size() != 2:
		errs.append("节点 %d pos 无效（需要 [x, y]）" % id)
		return false
	var p: Array = nd["pos"]
	if not _is_number(p[0]) or not _is_number(p[1]):
		errs.append("节点 %d pos 不是数字" % id)
		return false
	var x := float(p[0])
	var y := float(p[1])
	if x < MARGIN_X or x > DESIGN_W - MARGIN_X or y < MARGIN_TOP or y > DESIGN_H - MARGIN_BOTTOM:
		errs.append("节点 %d 超出安全区域 pos=(%.1f, %.1f)" % [id, x, y])
	return true


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


## Kahn 拓扑排序。返回空字符串 = 无环；否则返回错误描述。
static func _cycle_check(nodes: Array, ids: Dictionary) -> String:
	var indegree := {}
	var out_edges := {}
	for id in ids.keys():
		indegree[id] = 0
		out_edges[id] = []
	for n in nodes:
		var nd: Dictionary = n
		var pid := int(nd.get("id", -1))
		if not out_edges.has(pid):
			continue
		for c in nd.get("children", []):
			var cid := int(c)
			if indegree.has(cid):
				indegree[cid] = int(indegree[cid]) + 1
				(out_edges[pid] as Array).append(cid)
	var queue: Array = []
	for id in indegree.keys():
		if int(indegree[id]) == 0:
			queue.append(id)
	var processed := 0
	while not queue.is_empty():
		var cur := int(queue.pop_front())
		processed += 1
		var outs: Array = out_edges[cur]
		for nxt in outs:
			var nid := int(nxt)
			indegree[nid] = int(indegree[nid]) - 1
			if int(indegree[nid]) == 0:
				queue.append(nid)
	if processed < ids.size():
		return "关卡图含有环（%d 个节点在环或环下游，永远无法剪去）" % (ids.size() - processed)
	return ""
