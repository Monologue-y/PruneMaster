class_name BranchView
extends Node2D
## 父→子树枝（M3 程序化真实树枝，替代 M1 灰盒 LinkView）。
##
## 几何：二次贝塞尔（弯曲量由端点 id 哈希确定性生成）→ 沿曲线采样，
## 两侧沿法向偏移形成宽度渐窄的带状 Polygon2D（父端 17px → 子端 4.5px 尖尾，
## 强渐窄让每条边的"父→子"方向一眼可辨：宽端长出 = 父，尖端进入 = 子）。
## 贴树皮平铺纹理（u = 弧长/128 循环，v = 0..1 横向）。
## 纹理缺失时回退为纯色枝条（无资源兜底）。
##
## 回缩动画：剪去子节点时 extent 1 → 0 按弧长重建多边形（枝条缩回父端）。

const BARK_PATH := "res://assets/art/bark/bark_tile.png"
const SAMPLES := 14
const WIDTH_FROM := 17.0
const WIDTH_TO := 4.5
const INSET := 16.0         # 两端缩进（藏进叶簇不透明内核；过大会露出缝隙、显得"没连上"）
const BEND_MAX := 42.0      # 最大弯曲偏移
const TEX_LEN := 128.0      # 树皮纹理沿枝条方向的重复长度
const OUTLINE_W := 3.0      # 深色描边宽度（交叉枝条轮廓分离，过路/连接可辨）
const OUTLINE_COLOR := Color(0.16, 0.11, 0.07, 1.0)
const FALLBACK_COLOR := Color(0.36, 0.27, 0.17)

var from_id: int = -1
var to_id: int = -1

var _a: Vector2 = Vector2.ZERO       # 缩进后的父端
var _b_full: Vector2 = Vector2.ZERO  # 缩进后的子端
var _ctrl_full: Vector2 = Vector2.ZERO
var _extent: float = 1.0
var _retracting := false
var _poly: Polygon2D
var _outline: Polygon2D


func setup(p_from_id: int, p_to_id: int, a: Vector2, b: Vector2) -> void:
	from_id = p_from_id
	to_id = p_to_id
	var dir := b - a
	var length := dir.length()
	if length < 2.0:
		dir = Vector2.DOWN * 2.0
		length = 2.0
	var n := dir / length
	var inset: float = minf(INSET, length * 0.3)
	_a = a + n * inset
	_b_full = b - n * inset
	# 确定性弯曲：端点 id 哈希 → -1..1 → 沿法向偏移控制点
	var h: int = (p_from_id * 73856093) ^ (p_to_id * 19349663)
	var unit: float = float(absi(h) % 200) / 100.0 - 1.0
	var perp := Vector2(-n.y, n.x)
	var mid := (_a + _b_full) * 0.5
	_ctrl_full = mid + perp * (unit * BEND_MAX)
	# 短枝减弱弯曲，避免自交
	_ctrl_full = mid.lerp(_ctrl_full, clampf(length / 300.0, 0.15, 1.0))


func _ready() -> void:
	_outline = Polygon2D.new()
	_outline.color = OUTLINE_COLOR
	add_child(_outline)
	_poly = Polygon2D.new()
	var tex := load(BARK_PATH) as Texture2D
	if tex != null:
		_poly.texture = tex
		_poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	else:
		_poly.color = FALLBACK_COLOR
	_poly.antialiased = true
	_outline.antialiased = true
	add_child(_poly)
	_rebuild()


## 回缩动画：0.16s 内子端滑回父端，随后自毁。
func play_retract() -> void:
	if _retracting:
		return
	_retracting = true
	var t := create_tween()
	t.tween_method(_set_extent, 1.0, 0.0, 0.16)
	t.tween_callback(queue_free)


func _set_extent(f: float) -> void:
	_extent = clampf(f, 0.0, 1.0)
	_rebuild()


func _bezier(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var p0 := a.lerp(c, t)
	var p1 := c.lerp(b, t)
	return p0.lerp(p1, t)


func _tangent(centers: Array[Vector2], i: int) -> Vector2:
	if i <= 0:
		return centers[1] - centers[0]
	if i >= centers.size() - 1:
		return centers[centers.size() - 1] - centers[centers.size() - 2]
	return centers[i + 1] - centers[i - 1]


func _rebuild() -> void:
	if _poly == null:
		return
	if _extent <= 0.01:
		_poly.polygon = PackedVector2Array()
		_poly.uv = PackedVector2Array()
		_outline.polygon = PackedVector2Array()
		return
	var bend := _a.lerp(_b_full, _extent)
	var ctrl := _a.lerp(_ctrl_full, _extent)
	# 采样中心线 + 累计弧长
	var centers: Array[Vector2] = []
	var cum: Array[float] = []
	var run := 0.0
	var prev := _a
	for i in SAMPLES + 1:
		var t := float(i) / float(SAMPLES)
		var pt := _bezier(_a, ctrl, bend, t)
		centers.append(pt)
		run += pt.distance_to(prev)
		cum.append(run)
		prev = pt
	# 两侧轮廓点（宽度线性收窄；UV 为纹理像素空间：u = 弧长 px（128px 一循环），v = 0..64）
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var top_o := PackedVector2Array()
	var bot_o := PackedVector2Array()
	var top_uv := PackedVector2Array()
	var bot_uv := PackedVector2Array()
	for i in SAMPLES + 1:
		var t := float(i) / float(SAMPLES)
		var tang := _tangent(centers, i)
		var perp := Vector2(-tang.y, tang.x).normalized()
		var w: float = lerpf(WIDTH_FROM, WIDTH_TO, t) * 0.5
		var u: float = cum[i]
		top.append(centers[i] + perp * w)
		bot.append(centers[i] - perp * w)
		top_o.append(centers[i] + perp * (w + OUTLINE_W))
		bot_o.append(centers[i] - perp * (w + OUTLINE_W))
		top_uv.append(Vector2(u, 0.0))
		bot_uv.append(Vector2(u, 64.0))
	# 多边形 = 上侧正向 + 下侧逆向（闭合带状）
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var pts_o := PackedVector2Array()
	for i in SAMPLES + 1:
		pts.append(top[i])
		uvs.append(top_uv[i])
		pts_o.append(top_o[i])
	for i in range(SAMPLES, -1, -1):
		pts.append(bot[i])
		uvs.append(bot_uv[i])
		pts_o.append(bot_o[i])
	_poly.polygon = pts
	_poly.uv = uvs
	_outline.polygon = pts_o
