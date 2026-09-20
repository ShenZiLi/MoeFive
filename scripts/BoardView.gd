extends Control
class_name BoardView
## 棋盘视图 —— M1 占位美术（程序化绘制，不依赖任何美术资源）。
##
## 布局遵循需求 §4.4（正方形木框棋盘居中）与 §4.5（组件规格）；
## 配色取自 GameConfig（= 需求 §4.2 取样值）。
##
## 触控策略（需求 §8.3）：落点按"最近交叉点"判定，热区天然放宽至整格，
## 无需额外容错半径 —— 视觉格不变、判定区放大。

signal point_pressed(cell: Vector2i)

const PAD_RATIO := 0.05      ## 棋盘四周留白（相对自身边长）
const STONE_RATIO := 0.40    ## 棋子半径 / 格距

var board: Board
var interactive: bool = false
var hover_cell := Vector2i(-1, -1)

var _frame_rect := Rect2()
var _board_rect := Rect2()
var _gap := 0.0
var _origin := Vector2.ZERO
var _stone_r := 0.0

var _frame_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_board(b: Board) -> void:
	board = b
	queue_redraw()


# ========== 几何 ==========

func _recalc() -> void:
	if board == null:
		return
	var n: int = board.size
	var side: float = minf(size.x, size.y) * (1.0 - PAD_RATIO * 2.0)
	var pad: float = side * 0.075     # 木框宽度
	_board_rect = Rect2(
		(size.x - side) * 0.5,
		(size.y - side) * 0.5,
		side,
		side
	)
	_frame_rect = _board_rect.grow(pad)
	_gap = side / float(n - 1)
	_origin = _board_rect.position
	_stone_r = _gap * STONE_RATIO


func _point_pos(x: int, y: int) -> Vector2:
	return _origin + Vector2(float(x) * _gap, float(y) * _gap)


## 屏幕坐标 → 交叉点（越界返回 (-1, -1)）
func cell_at(pos: Vector2) -> Vector2i:
	if board == null or _gap <= 0.0:
		return Vector2i(-1, -1)
	if not _frame_rect.grow(_gap * 0.5).has_point(pos):
		return Vector2i(-1, -1)
	var rel := pos - _origin
	var cx := int(roundf(rel.x / _gap))
	var cy := int(roundf(rel.y / _gap))
	if cx < 0 or cx >= board.size or cy < 0 or cy >= board.size:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)


# ========== 绘制 ==========

func _draw() -> void:
	if board == null:
		return
	_recalc()
	_draw_frame()
	_draw_grid()
	_draw_winning_beam()
	_draw_stones()
	_draw_last_marker()
	_draw_hover()


func _draw_frame() -> void:
	if _frame_style == null:
		_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = GameConfig.C_BOARD_FRAME
	_frame_style.set_corner_radius_all(int(maxf(6.0, _gap * 0.38)))
	_frame_style.shadow_color = Color(0.20, 0.12, 0.06, 0.22)
	_frame_style.shadow_size = int(maxf(2.0, _gap * 0.20))
	_frame_style.shadow_offset = Vector2(0, maxf(2.0, _gap * 0.14))
	draw_style_box(_frame_style, _frame_rect)

	# 木底（上亮下暗，模拟窗光）
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameConfig.C_BOARD_LIGHT
	sb.set_corner_radius_all(int(maxf(4.0, _gap * 0.22)))
	draw_style_box(sb, _board_rect)
	draw_rect(Rect2(_board_rect.position, Vector2(_board_rect.size.x, _board_rect.size.y * 0.5)),
		Color(GameConfig.C_BOARD_DARK, 0.16))


func _draw_grid() -> void:
	var line_w: float = maxf(1.0, _gap * 0.055)
	var n: int = board.size
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
	for sp in GameConfig.STAR_POINTS:
		if sp.x < n and sp.y < n:
			draw_circle(_point_pos(sp.x, sp.y), maxf(1.6, _gap * 0.11), GameConfig.C_BOARD_LINE)

	_draw_labels()


func _draw_labels() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var fs: int = int(maxf(9.0, _gap * 0.38))
	var col := Color(GameConfig.C_TEXT, 0.65)
	var n: int = board.size

	for i in n:
		# 列标 A–O（左→右）
		var letter := String.chr(65 + i)
		var lw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font,
			Vector2(_origin.x + float(i) * _gap - lw * 0.5, _board_rect.position.y - _gap * 0.30),
			letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		# 行号 15→1（屏幕自上而下；需求 §3.1.1：1 在底部）
		var num := str(n - i)
		var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font,
			Vector2(_origin.x - _gap * 0.22 - nw, _origin.y + float(i) * _gap + fs * 0.36),
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
	for y in board.size:
		for x in board.size:
			var c := board.get_cell(x, y)
			if c == GameConfig.EMPTY:
				continue
			var p := _point_pos(x, y)
			var body := GameConfig.C_STONE_BLACK if c == GameConfig.BLACK else GameConfig.C_STONE_WHITE
			draw_circle(p + Vector2(0, _stone_r * 0.14), _stone_r, Color(0.22, 0.14, 0.08, 0.22))
			draw_circle(p, _stone_r, body)
			draw_circle(p - Vector2(_stone_r * 0.30, _stone_r * 0.32),
				_stone_r * 0.24, Color(1, 1, 1, 0.30))


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
