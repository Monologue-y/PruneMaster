class_name LevelEditorCore
extends RefCounted
## 关卡编辑器核心逻辑（纯逻辑，与 UI 解耦，可 headless 单元测试）。
## 内部数据与 docs/level_format.md 的 JSON 格式一一对应（pos 内部用 Vector2）。
##
## 连线语义（与生成器一致）：
## - 边只能从浅行指向深行（child.y > parent.y）→ 天然无环
## - 跨树连线时子节点自动并入父节点所属树（并集，上限 3 棵）→ 自动产生共享节点

signal changed

const MAX_TREE_UNION := 3

var level_id: int = 1
var level_name: String = "New Level"
var lives: int = 3
var nodes: Array = []   # Array[Dictionary]：id / pos(Vector2) / trees / children

var _next_id: int = 1


func create(p_level_id: int, p_name: String = "New Level") -> void:
	level_id = p_level_id
	level_name = p_name
	lives = 3
	nodes = []
	_next_id = 1
	changed.emit()


func load_level(path: String) -> bool:
	var lv := LevelData.load_from_file(path)
	if lv == null:
		return false
	level_id = lv.id
	level_name = lv.level_name
	lives = lv.lives
	nodes = []
	_next_id = 1
	for n in lv.nodes:
		var nd: Dictionary = n
		var pos_arr: Array = nd.get("pos", [0.0, 0.0])
		var node := {
			"id": int(nd.get("id", 0)),
			"pos": Vector2(float(pos_arr[0]), float(pos_arr[1])),
			"trees": (nd.get("trees", [1]) as Array).duplicate(),
			"children": (nd.get("children", []) as Array).duplicate(),
		}
		nodes.append(node)
		_next_id = maxi(_next_id, int(node["id"]) + 1)
	changed.emit()
	return true


func add_node(pos: Vector2, tree_id: int = 1) -> int:
	var node := {
		"id": _next_id,
		"pos": pos,
		"trees": [tree_id],
		"children": [],
	}
	_next_id += 1
	nodes.append(node)
	changed.emit()
	return int(node["id"])


func has_node(id: int) -> bool:
	return _find(id) >= 0


func get_node(id: int) -> Dictionary:
	var i := _find(id)
	if i < 0:
		return {}
	return nodes[i]


func position_of(id: int) -> Vector2:
	var nd := get_node(id)
	if nd.is_empty():
		return Vector2.ZERO
	return nd.get("pos", Vector2.ZERO)


func trees_of(id: int) -> Array:
	return get_node(id).get("trees", [])


func children_of(id: int) -> Array:
	return get_node(id).get("children", [])


func node_count() -> int:
	return nodes.size()


func move_node(id: int, pos: Vector2) -> void:
	var i := _find(id)
	if i < 0:
		return
	(nodes[i] as Dictionary)["pos"] = pos
	changed.emit()


## 重置节点所属树（单树）。
func assign_tree(id: int, tree_id: int) -> void:
	var i := _find(id)
	if i < 0:
		return
	(nodes[i] as Dictionary)["trees"] = [tree_id]
	changed.emit()


## 允许 parent→child 连线的条件：
## 1) 两节点都存在且不同；2) 不重复；3) child 在 parent 下方；
## 4) 不得成环（parent 不能已是 child 的后代）；5) 树并集 ≤ 3。
func can_link(parent_id: int, child_id: int) -> bool:
	if parent_id == child_id:
		return false
	if not has_node(parent_id) or not has_node(child_id):
		return false
	if children_of(parent_id).has(child_id):
		return false
	if position_of(child_id).y <= position_of(parent_id).y:
		return false
	if _is_reachable(child_id, parent_id):
		return false
	var pt: Array = trees_of(parent_id)
	var ct: Array = trees_of(child_id)
	if pt.is_empty() or ct.is_empty():
		return true
	var union: Array = ct.duplicate()
	for t in pt:
		if not union.has(t):
			union.append(t)
	return union.size() <= MAX_TREE_UNION


func link(parent_id: int, child_id: int) -> bool:
	if not can_link(parent_id, child_id):
		return false
	var pi := _find(parent_id)
	((nodes[pi] as Dictionary)["children"] as Array).append(child_id)
	# 跨树连线 → 子节点并入父节点的树（自动共享）
	var pt: Array = trees_of(parent_id)
	var ct: Array = trees_of(child_id)
	if not pt.is_empty() and not ct.is_empty():
		var union: Array = ct.duplicate()
		for t in pt:
			if not union.has(t):
				union.append(t)
		if union.size() <= MAX_TREE_UNION:
			var ci := _find(child_id)
			(nodes[ci] as Dictionary)["trees"] = union
	changed.emit()
	return true


## 删除节点并清理所有对它的引用（父节点的 children）。
func remove_node(id: int) -> bool:
	var i := _find(id)
	if i < 0:
		return false
	nodes.remove_at(i)
	for n in nodes:
		var nd: Dictionary = n
		(nd["children"] as Array).erase(id)
	changed.emit()
	return true


func to_dict() -> Dictionary:
	var out_nodes: Array = []
	for n in nodes:
		var nd: Dictionary = n
		var pos: Vector2 = nd["pos"]
		var children: Array = (nd["children"] as Array).duplicate()
		children.sort()
		out_nodes.append({
			"id": int(nd["id"]),
			"trees": (nd["trees"] as Array).duplicate(),
			"pos": [pos.x, pos.y],
			"children": children,
		})
	return {
		"id": level_id,
		"name": level_name,
		"lives": lives,
		"trees": _trees_meta(),
		"nodes": out_nodes,
	}


func validate() -> PackedStringArray:
	return LevelValidator.validate(LevelData.from_dict(to_dict()))


## 保存（仅当校验通过）。返回错误列表；空 = 成功。
func save_to(path: String) -> PackedStringArray:
	var errs := validate()
	if not errs.is_empty():
		return errs
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return PackedStringArray(["无法写入文件: %s" % path])
	f.store_string(JSON.stringify(to_dict(), "  ") + "\n")
	f.close()
	return PackedStringArray()


func _find(id: int) -> int:
	for i in nodes.size():
		if int((nodes[i] as Dictionary)["id"]) == id:
			return i
	return -1


## 从 from 出发沿 child 边能否到达 to。
func _is_reachable(from_id: int, to_id: int) -> bool:
	var stack: Array = [from_id]
	var visited := {}
	while not stack.is_empty():
		var cur := int(stack.pop_back())
		if cur == to_id:
			return true
		if visited.has(cur):
			continue
		visited[cur] = true
		for c in children_of(cur):
			stack.append(int(c))
	return false


func _trees_meta() -> Array:
	var max_tree := 0
	for n in nodes:
		for t in (n as Dictionary)["trees"]:
			max_tree = maxi(max_tree, int(t))
	var meta: Array = []
	for t in max_tree:
		meta.append({"id": t + 1, "name": "Tree %d" % (t + 1)})
	return meta
