class_name LevelData
extends RefCounted
## 关卡数据的运行时表示。解析自 JSON（格式见 docs/level_format.md）。
## from_dict 会对 nodes/trees 做类型清洗（仅保留 Dictionary 项）。

var id: int = 0
var level_name: String = ""
var lives: int = 3
var time_limit: float = -1.0  # < 0 表示无限时（预留字段）
var trees: Array = []         # Array[Dictionary]
var nodes: Array = []         # Array[Dictionary]：id / pos / children / trees / art


static func from_dict(d: Dictionary) -> LevelData:
	var lv := LevelData.new()
	lv.id = int(d.get("id", 0))
	lv.level_name = String(d.get("name", ""))
	lv.lives = int(d.get("lives", 3))
	lv.time_limit = float(d.get("time_limit", -1.0))
	for t in d.get("trees", []):
		if t is Dictionary:
			lv.trees.append(t)
	for n in d.get("nodes", []):
		if not (n is Dictionary):
			continue
		var nd: Dictionary = n
		# 规范化：JSON 解析出的数字可能是 float，children/trees 统一转 int
		var norm: Dictionary = nd.duplicate()
		var ch: Array = []
		for c in nd.get("children", []):
			ch.append(int(c))
		norm["children"] = ch
		var tr: Array = []
		for t in nd.get("trees", [1]):
			tr.append(int(t))
		norm["trees"] = tr
		lv.nodes.append(norm)
	return lv


static func load_from_file(path: String) -> LevelData:
	if not FileAccess.file_exists(path):
		push_error("关卡文件不存在: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("关卡文件为空: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("关卡 JSON 解析失败: %s" % path)
		return null
	return from_dict(parsed as Dictionary)


func node_count() -> int:
	return nodes.size()


func node_ids() -> Array[int]:
	var out: Array[int] = []
	for n in nodes:
		out.append(int((n as Dictionary).get("id", -1)))
	return out


func node_dict(node_id: int) -> Dictionary:
	for n in nodes:
		var nd: Dictionary = n
		if int(nd.get("id", -1)) == node_id:
			return nd
	return {}


func pos_of(node_id: int) -> Vector2:
	var n := node_dict(node_id)
	var p: Array = n.get("pos", [0.0, 0.0])
	return Vector2(float(p[0]), float(p[1]))


func children_of(node_id: int) -> Array:
	return node_dict(node_id).get("children", [])
