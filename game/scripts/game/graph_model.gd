class_name GraphModel
extends RefCounted
## 关卡的有向无环图（DAG）模型。纯逻辑，无视图依赖。
##
## 输入 nodes_data: Array[Dictionary]，每项 { id: int, children: Array[int], ... }。
## 节点可剪 ⇔ 出度为 0（没有任何存活子节点）。
## 数学保证：有限 DAG 必有汇点，且删汇点后仍是 DAG
## → 任何合法剪枝顺序都能清空全图，永无死局（见 docs/design.md）。

signal node_pruned(node_id: int)
signal prune_rejected(node_id: int)
signal all_pruned

var total_nodes: int = 0
var pruned_count: int = 0

var _children: Dictionary = {}        # id -> Array[int]
var _parents: Dictionary = {}         # id -> Array[int]
var _alive_children: Dictionary = {}  # id -> int
var _pruned: Dictionary = {}          # id -> bool


func _init(nodes_data: Array = []) -> void:
	for n in nodes_data:
		var nd: Dictionary = n
		var id := int(nd.get("id", -1))
		_children[id] = []
		_parents[id] = []
		_pruned[id] = false
	total_nodes = _children.size()
	# 第二遍建边，保证父表在所有节点登记完成后统计
	for n in nodes_data:
		var nd: Dictionary = n
		var pid := int(nd.get("id", -1))
		for c in nd.get("children", []):
			var cid := int(c)
			(_children[pid] as Array).append(cid)
			(_parents[cid] as Array).append(pid)
	for id in _children.keys():
		_alive_children[id] = (_children[id] as Array).size()


func has_node(id: int) -> bool:
	return _children.has(id)


func is_pruned(id: int) -> bool:
	return _pruned.get(id, true)


func alive_children_count(id: int) -> int:
	return int(_alive_children.get(id, -1))


func can_prune(id: int) -> bool:
	return has_node(id) and not is_pruned(id) and alive_children_count(id) == 0


## 尝试剪去节点。成功返回 true 并发出 node_pruned；失败发出 prune_rejected。
func prune(id: int) -> bool:
	if not can_prune(id):
		prune_rejected.emit(id)
		return false
	_pruned[id] = true
	pruned_count += 1
	var ps: Array = _parents[id]
	for p in ps:
		_alive_children[int(p)] -= 1
	node_pruned.emit(id)
	if pruned_count >= total_nodes:
		all_pruned.emit()
	return true


func ids() -> Array:
	return _children.keys()


func children_of(id: int) -> Array:
	return _children.get(id, [])


func parents_of(id: int) -> Array:
	return _parents.get(id, [])
