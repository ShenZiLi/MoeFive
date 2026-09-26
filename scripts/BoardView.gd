@tool
extends Control
class_name BoardView
## 棋盘视图 —— 绘制棋盘网格与爪印棋子资源。
##
## 布局遵循需求 §4.4（正方形木框棋盘居中）与 §4.5（组件规格）；
## 配色取自 GameConfig（= 需求 §4.2 取样值）。
##
## 触控策略（需求 §8.3）：落点按"最近交叉点"判定，热区天然放宽至整格，
## 无需额外容错半径 —— 视觉格不变、判定区放大。

signal point_pressed(cell: Vector2i)

const GRID_RATIO := 0.84     ## 紧凑布局格线比例
const STONE_RATIO := 0.40    ## 棋子半径 / 格距
const PIECE_TEXTURE := preload("res://assets/pieces/schemes/pieces_scheme_01_paws.png")
const PIECE_TILE_SIZE := 887.0
const PIECE_BODY_RATIO := 0.755  ## 棋子实心主体直径 / 单格纹理尺寸
const PIECE_BLACK_BODY_CENTER := Vector2(497.0, 438.0)
const PIECE_WHITE_BODY_CENTER := Vector2(384.0, 438.5)

var board: Board
var interactive: bool = false
var reference_mode: bool = false
var photo_mode: bool = false
var hover_cell := Vector2i(-1, -1)

var _frame_rect := Rect2()
var _board_rect := Rect2()
var _gap := 0.0
var _gap_x := 0.0
var _gap_y := 0.0
var _origin := Vector2.ZERO
var _stone_r := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_board(b: Board) -> void:
	board = b
	queue_redraw()


# ========== 几何 ==========

func _recalc() -> void:
	var n: int = board.size if board != null else GameConfig.BOARD_SIZE
	if photo_mode:
		# 图 1 原始像素坐标；BoardPanel 裁切范围与这些数值共用。
		_board_rect = Rect2(size.x * (256.0 / 3572.0), size.y * (237.0 / 3503.0),
			size.x * (3097.0 / 3572.0), size.y * (3030.0 / 3503.0))
	elif reference_mode:
		# 原型图中棋盘框的裁切范围是 (389, 3, 896, 936)。
		# x=451 与 y=54 是坐标栏边界，首个可落子交点在 (499, 107)。
		_board_rect = Rect2(size.x * (110.0 / 896.0), size.y * (104.0 / 936.0),
			size.x * (736.0 / 896.0), size.y * (755.0 / 936.0))
	elif size.y > size.x * 1.05:
		# 桌面原型棋盘：外框与交点区是略微纵向拉长的矩形。
		_board_rect = Rect2(size.x * 0.092, size.y * 0.120, size.x * 0.834, size.y * 0.781)
	else:
		var side: float = minf(size.x, size.y) * GRID_RATIO
		_board_rect = Rect2((size.x - side) * 0.5, (size.y - side) * 0.5, side, side)
	_frame_rect = Rect2(Vector2.ZERO, size)
	_gap_x = _board_rect.size.x / float(n - 1)
	_gap_y = _board_rect.size.y / float(n - 1)
	_gap = minf(_gap_x, _gap_y)
	_origin = _board_rect.position
	_stone_r = _gap * STONE_RATIO


func _point_pos(x: int, y: int) -> Vector2:
	return _origin + Vector2(float(x) * _gap_x, float(y) * _gap_y)


## 屏幕坐标 → 交叉点（越界返回 (-1, -1)）
func cell_at(pos: Vector2) -> Vector2i:
	if board == null:
		return Vector2i(-1, -1)
	_recalc()
	if _gap <= 0.0 or not _board_rect.grow(maxf(_gap_x, _gap_y) * 0.5).has_point(pos):
		return Vector2i(-1, -1)
	var rel := pos - _origin
	var cx := int(roundf(rel.x / _gap_x))
	var cy := int(roundf(rel.y / _gap_y))
	if cx < 0 or cx >= board.size or cy < 0 or cy >= board.size:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)


# ========== 绘制 ==========

func _draw() -> void:
	_recalc()
	if not reference_mode and not photo_mode:
		_draw_grid()
	if board == null:
		return
	_draw_winning_beam()
	_draw_stones()
	_draw_last_marker()
	_draw_hover()


func _draw_grid() -> void:
	var line_w: float = maxf(1.0, _gap * 0.055)
	var n: int = board.size if board != null else GameConfig.BOARD_SIZE
	var line_col := Color(GameConfig.C_BOARD_LINE, 0.85)

	for i in n:
		var p := _point_pos(i, 0)
		var q := _point_pos(i, n - 1)
		draw_line(Vector2(p.x, p.y), Vector2(q.x, q.y), line_col, line_w)
	for i in n:
		var p := _point_pos(0, i)
		var q := _point_pos(n - 1, i)
		draw_line(Vector2(p.x, p.y), Vector2(q.x, q.y), line_col, line_w)

	# 星位
	var star_points := GameConfig.STAR_POINTS
	if size.y > size.x * 1.05:
		star_points = [Vector2i(2, 3), Vector2i(11, 3), Vector2i(7, 7), Vector2i(2, 10), Vector2i(11, 10)]
	for sp in star_points:
		if sp.x < n and sp.y < n:
			draw_circle(_point_pos(sp.x, sp.y), maxf(1.6, _gap * 0.11), GameConfig.C_BOARD_LINE)

	_draw_labels()


func _draw_labels() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var fs: int = int(maxf(9.0, _gap * 0.38))
	var col := Color(GameConfig.C_TEXT, 0.65)
	var n: int = board.size if board != null else GameConfig.BOARD_SIZE

	var desktop_reference := size.y > size.x * 1.05
	var columns_to_label := n - 1 if desktop_reference else n
	for i in columns_to_label:
		# 原型右上角爪印覆盖 O；紧凑布局保留全部列标。
		var letter := String.chr(65 + i)
		var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font,
			Vector2(_origin.x + float(i) * _gap_x - lw * 0.5, _board_rect.position.y - _gap_y * 0.30),
			letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	for i in n:
		# 行号 15→1（屏幕自上而下；需求 §3.1.1：1 在底部）
		var num := str(n - i)
		var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var label_y := _origin.y + float(i) * _gap_y + fs * 0.36
		if desktop_reference:
			# 原型的行号从首行下方开始，到末行上方结束。
			label_y = _origin.y + _gap_y * (0.9 + float(i) * 0.92) + fs * 0.36
		draw_string(font,
			Vector2(_origin.x - _gap_x * 0.22 - nw, label_y),
			num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## 连珠光带（画在棋子之下，避免遮挡棋子本体）
func _draw_winning_beam() -> void:
	if board.winning_line.size() < 2:
		return
	var a: Vector2i = board.winning_line[0]
	var b: Vector2i = board.winning_line[board.winning_line.size() - 1]
	draw_line(_point_pos(a.x, a.y), _point_pos(b.x, b.y),
		Color(GameConfig.C_ACCENT, 0.55), _stone_r * 0.75, true)


func _draw_stones() -> void:
	var sprite_size := _stone_r * 2.0 / PIECE_BODY_RATIO
	for y in board.size:
		for x in board.size:
			var c := board.get_cell(x, y)
			if c == GameConfig.EMPTY:
				continue
			var p := _point_pos(x, y)
			var source_rect := Rect2(Vector2.ZERO, Vector2.ONE * PIECE_TILE_SIZE)
			var body_center := PIECE_BLACK_BODY_CENTER
			if c == GameConfig.WHITE:
				source_rect.position.x = PIECE_TILE_SIZE
				body_center = PIECE_WHITE_BODY_CENTER
			var draw_rect := Rect2(
				p - body_center / PIECE_TILE_SIZE * sprite_size,
				Vector2.ONE * sprite_size
			)
			draw_texture_rect_region(PIECE_TEXTURE, draw_rect, source_rect)


func _draw_last_marker() -> void:
	if board.is_over():
		return
	var last := board.last_move()
	if last.x < 0:
		return
	draw_arc(_point_pos(last.x, last.y), _stone_r * 1.30, 0.0, TAU, 32,
		Color(GameConfig.C_ACCENT, 0.85), maxf(1.5, _gap * 0.07), true)


func _draw_hover() -> void:
	if not interactive or board.is_over():
		return
	if hover_cell.x < 0 or not board.is_empty_point(hover_cell.x, hover_cell.y):
		return
	draw_arc(_point_pos(hover_cell.x, hover_cell.y), _stone_r * 0.92, 0.0, TAU, 24,
		Color(GameConfig.C_ACCENT, 0.34), maxf(1.0, _gap * 0.055), true)


# ========== 输入 ==========

func _gui_input(event: InputEvent) -> void:
	if board == null:
		return

	if event is InputEventMouseMotion:
		var c := cell_at(event.position)
		if c != hover_cell:
			hover_cell = c
			queue_redraw()
		return

	var clicked := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked = true
			pos = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			clicked = true
			pos = event.position

	if clicked and interactive:
		var c := cell_at(pos)
		if c.x >= 0:
			point_pressed.emit(c)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_MOUSE_EXIT:
		if what == NOTIFICATION_MOUSE_EXIT:
			hover_cell = Vector2i(-1, -1)
		queue_redraw()
