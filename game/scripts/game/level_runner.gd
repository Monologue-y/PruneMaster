class_name LevelRunner
extends Node
## 关卡流程控制：生命值、点击裁决、胜负判定。纯逻辑，不含任何视图。
## BoardView 把节点点击转发到 try_click()；HUD 监听本节点信号刷新界面。

signal node_pruned(node_id: int)
signal prune_rejected(node_id: int)
signal life_lost(lives_left: int)
signal level_won
signal level_failed

const MIN_S_TIME := 24.0
const SECONDS_PER_NODE := 1.6

var level: LevelData
var model: GraphModel
var lives: int = 0
var lives_max: int = 0
var finished: bool = false   # 通关
var failed: bool = false     # 生命耗尽
var elapsed_time: float = 0.0


func setup(p_level: LevelData) -> void:
	level = p_level
	model = GraphModel.new(p_level.nodes)
	lives = p_level.lives
	lives_max = p_level.lives
	finished = false
	failed = false
	elapsed_time = 0.0
	set_process(true)
	model.node_pruned.connect(_on_model_pruned)
	model.prune_rejected.connect(_on_model_rejected)


func _process(delta: float) -> void:
	advance_time(delta)


## 独立入口便于 headless 测试；胜负结束后计时冻结。
func advance_time(delta: float) -> void:
	if not finished and not failed and delta > 0.0:
		elapsed_time += delta


## 玩家点击某个节点。内部裁决：合法剪枝 / 误剪扣血 / 结束后忽略。
func try_click(node_id: int) -> void:
	if finished or failed:
		return
	if not model.has_node(node_id) or model.is_pruned(node_id):
		return
	if model.can_prune(node_id):
		model.prune(node_id)
		if model.pruned_count >= model.total_nodes and not finished:
			finished = true
			set_process(false)
			level_won.emit()
	else:
		prune_rejected.emit(node_id)
		_lose_life()


func remaining_nodes() -> int:
	return model.total_nodes - model.pruned_count


func prunable_ids() -> Array[int]:
	var out: Array[int] = []
	for id in model.ids():
		if model.can_prune(int(id)):
			out.append(int(id))
	return out


func _lose_life() -> void:
	lives -= 1
	life_lost.emit(lives)
	if lives <= 0 and not failed:
		failed = true
		set_process(false)
		level_failed.emit()


## S 级目标随节点数线性增长，并设置最低 24 秒避免小关过于苛刻。
static func s_target_for_nodes(node_count: int) -> float:
	return ceilf(maxf(MIN_S_TIME, 12.0 + float(maxi(node_count, 1)) * SECONDS_PER_NODE))


static func rating_thresholds(node_count: int) -> Dictionary:
	var s_limit := s_target_for_nodes(node_count)
	return {
		"S": s_limit,
		"A": ceilf(s_limit * 1.4),
		"B": ceilf(s_limit * 1.9),
	}


static func rating_for_time(seconds: float, node_count: int) -> String:
	var limits := rating_thresholds(node_count)
	if seconds <= float(limits["S"]):
		return "S"
	if seconds <= float(limits["A"]):
		return "A"
	if seconds <= float(limits["B"]):
		return "B"
	return "C"


static func rating_name(grade: String) -> String:
	match grade:
		"S": return "大师修剪"
		"A": return "出色完成"
		"B": return "稳健完成"
		_: return "完成挑战"


static func format_time(seconds: float) -> String:
	var total_seconds := maxi(0, int(floor(seconds)))
	var minutes := int(total_seconds / 60)
	return "%02d:%02d" % [minutes, total_seconds % 60]


func result_summary() -> Dictionary:
	var node_count := model.total_nodes if model != null else 1
	var grade := rating_for_time(elapsed_time, node_count)
	var s_target := s_target_for_nodes(node_count)
	return {
		"elapsed": elapsed_time,
		"time_text": format_time(elapsed_time),
		"rating": grade,
		"rating_name": rating_name(grade),
		"s_target": s_target,
		"s_target_text": format_time(s_target),
	}


func _on_model_pruned(node_id: int) -> void:
	node_pruned.emit(node_id)


func _on_model_rejected(node_id: int) -> void:
	prune_rejected.emit(node_id)
