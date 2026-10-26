class_name HomeTree
extends Node2D
## 首页装饰树：复用游戏素材（BranchView 树皮枝条 + 叶簇贴图）拼一棵小树，
## 整树绕根部轻柔摇摆、叶簇各自微摆，营造"活"的呼吸感。
##
## 注意：BranchView 两端各有 16px 缩进（为藏进叶簇），因此侧枝起点要伸过
## 主干中线、顶枝起点要下探进主干可见段，衔接处才不会露缝。

const FOLIAGE_PATH := "res://assets/art/buds/foliage_green.png"
const SWAY_SPEED := 0.9
const SWAY_AMP := 0.035     # 整树摇摆幅度（弧度，约 ±2°）
const LEAF_AMP := 0.07      # 叶簇额外自摆幅度（弧度）

var _t := 0.0
var _leaves: Array[Sprite2D] = []
var _phases: Array[float] = []


func _ready() -> void:
	# 枝干（父端粗 → 子端细；id 仅参与弯曲哈希，取不同值让枝条形态各异）
	_add_branch(1, 2, Vector2(0, 0), Vector2(0, -108))       # 主干
	_add_branch(3, 4, Vector2(10, -48), Vector2(-52, -124))  # 左枝（起点越过主干中线）
	_add_branch(5, 6, Vector2(-10, -48), Vector2(52, -128))  # 右枝
	_add_branch(7, 8, Vector2(0, -76), Vector2(0, -172))     # 顶枝（起点下探进主干）
	# 叶簇：枝梢三团 + 中部两团（叶团半径同时盖住枝条缩进留下的端头）
	_add_leaf(Vector2(0, -178), 0.72)
	_add_leaf(Vector2(-56, -130), 0.62)
	_add_leaf(Vector2(56, -134), 0.62)
	_add_leaf(Vector2(-24, -112), 0.55)
	_add_leaf(Vector2(26, -114), 0.55)


func _process(delta: float) -> void:
	_t += delta
	rotation = sin(_t * SWAY_SPEED) * SWAY_AMP
	for i in _leaves.size():
		_leaves[i].rotation = sin(_t * 1.4 + _phases[i]) * LEAF_AMP


func _add_branch(from_id: int, to_id: int, a: Vector2, b: Vector2) -> void:
	var br := BranchView.new()
	br.setup(from_id, to_id, a, b)
	add_child(br)


func _add_leaf(pos: Vector2, leaf_scale: float) -> void:
	var spr := Sprite2D.new()
	spr.texture = load(FOLIAGE_PATH) as Texture2D
	spr.position = pos
	spr.scale = Vector2(leaf_scale, leaf_scale)
	add_child(spr)
	_leaves.append(spr)
	_phases.append(randf() * TAU)
