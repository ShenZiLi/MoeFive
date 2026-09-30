@tool
extends Control
class_name MatchView

signal point_pressed(cell: Vector2i)
signal undo_requested
signal surrender_requested
signal return_requested

@onready var _environment: TextureRect = $Environment
@onready var _photo_background: TextureRect = $PhotoBackground
@onready var _title: TextureRect = $SafeLayout/TitlePlaque
@onready var _board_panel: MatchBoardPanel = $SafeLayout/BoardPanel
@onready var _board_view: BoardView = $SafeLayout/BoardPanel/BoardView
@onready var _black: MatchPlayerPanel = $SafeLayout/PlayerPanelBlack
@onready var _white: MatchPlayerPanel = $SafeLayout/PlayerPanelWhite
@onready var _toolbar: MatchActionToolbar = $SafeLayout/ActionToolbar
@onready var _quote_board: TextureRect = $SafeLayout/QuoteBoard
@onready var _quote: Label = $SafeLayout/QuoteBoard/Quote
@onready var _status: Label = $StatusMessage
@onready var _status_plate: Panel = $StatusPlate
@onready var _feedback_timer: Timer = $FeedbackTimer
@onready var _decor: Control = $ForegroundDecor
@onready var _photo_black_count: Label = $SafeLayout/PhotoBlackCount
@onready var _photo_white_count: Label = $SafeLayout/PhotoWhiteCount

const PHOTO_SIZE := Vector2(6680.0, 3768.0)
const PHOTO_BOARD_RECT := Rect2(1548.0, 132.0, 3572.0, 3503.0)
const PHOTO_COUNTER_FONT := preload("res://assets/fonts/Fredoka-SemiBold.ttf")
const PHOTO_COUNTER_TOP := 2130.0

var _last_side: int = -1
var _last_status: String = ""


func _ready() -> void:
	_photo_black_count.add_theme_font_override("font", PHOTO_COUNTER_FONT)
	_photo_white_count.add_theme_font_override("font", PHOTO_COUNTER_FONT)
	var status_style := StyleBoxFlat.new()
	status_style.bg_color = Color(1.0, 0.95, 0.83, 0.84)
	status_style.border_color = Color(0.55, 0.36, 0.22, 0.30)
	status_style.set_border_width_all(1)
	status_style.set_corner_radius_all(9)
	_status_plate.add_theme_stylebox_override("panel", status_style)
	_board_view.point_pressed.connect(func(cell: Vector2i): point_pressed.emit(cell))
	_toolbar.undo_requested.connect(func(): undo_requested.emit())
	_toolbar.surrender_requested.connect(func(): surrender_requested.emit())
	_toolbar.return_requested.connect(func(): return_requested.emit())
	_feedback_timer.timeout.connect(func(): _status.text = _last_status)
	resized.connect(_layout)
	_layout()


func bind_board(board: Board) -> void:
	_board_view.set_board(board)
	_board_view.interactive = true


func get_board_view() -> BoardView:
	return _board_view


func apply_state(state: MatchViewState) -> void:
	_black.apply("玩家一", state.black_count, state.active_side == GameConfig.BLACK, false)
	_white.apply(state.player_two_name, state.white_count,
		state.active_side == GameConfig.WHITE, state.thinking)
	_photo_black_count.text = "× %d" % state.black_count
	_photo_white_count.text = "× %d" % state.white_count
	_photo_black_count.modulate = Color.WHITE if state.active_side == GameConfig.BLACK and not state.finished else Color(1, 1, 1, 0.60)
	_photo_white_count.modulate = Color.WHITE if state.active_side == GameConfig.WHITE and not state.finished else Color(1, 1, 1, 0.60)
	if _last_side != state.active_side or state.thinking:
		_black.set_quote("加油！🐾" if state.active_side == GameConfig.BLACK else "等你落子～")
		_white.set_quote("让我想想…" if state.thinking else "来一局吧！🐾")
		_last_side = state.active_side
	_toolbar.set_undo_available(state.can_undo and not state.finished)
	_board_view.interactive = not state.thinking and not state.finished
	_last_status = state.status
	if _feedback_timer.is_stopped():
		_status.text = state.status
	_quote.text = state.quote


func show_feedback(message: String) -> void:
	_status.text = message
	_feedback_timer.start(2.5)
	if _board_view.board and _board_view.board.current == GameConfig.BLACK:
		_black.show_feedback(message)
	else:
		_white.show_feedback(message)


func _layout() -> void:
	if not is_node_ready() or size.x <= 0 or size.y <= 0:
		return
	var w := size.x
	var h := size.y
	var safe := DisplayServer.get_display_safe_area()
	var window := DisplayServer.window_get_size()
	var safe_top := float(safe.position.y) / maxf(1.0, float(window.y)) * h
	var safe_bottom := float(window.y - safe.end.y) / maxf(1.0, float(window.y)) * h
	var compact := w < h
	_board_panel.set_reference_mode(false)
	_board_panel.set_photo_mode(not compact)
	_board_view.reference_mode = false
	_board_view.photo_mode = not compact
	_environment.visible = compact
	_photo_background.visible = not compact
	_title.visible = false
	# 标题牌 v2 已含原型中的两行字和爪印，隐藏旧的动态叠字避免重影。
	for title_child in [_title.get_node_or_null("Title"), _title.get_node_or_null("Subtitle"),
			_title.get_node_or_null("TitlePawLeft"), _title.get_node_or_null("TitlePawRight")]:
		if title_child:
			title_child.visible = false
	_quote_board.visible = false
	var quote_paw := _quote_board.get_node_or_null("QuotePaw") as Control
	if quote_paw:
		quote_paw.visible = false
	_decor.visible = false
	_black.visible = compact
	_white.visible = compact
	_photo_black_count.visible = not compact
	_photo_white_count.visible = not compact
	_black.set_compact(compact)
	_white.set_compact(compact)
	if compact:
		_toolbar.set_compact(true)
		_status.visible = true
		_status_plate.visible = true
		var s := minf(w / 390.0, h / 844.0)
		var panel_width := minf(366.0, (w - 24.0 * s) / s)
		var panel_x := (w - panel_width * s) * 0.5
		_place(_toolbar, Vector2(w - 244.0 * s, safe_top + 8.0 * s), Vector2(232, 72), s)
		_place(_white, Vector2(panel_x, safe_top + 88.0 * s), Vector2(panel_width, 94), s)
		var board_side := minf(w - 24.0 * s, h * 0.52)
		var board_y := maxf(safe_top + 195.0 * s, (h - board_side) * 0.5)
		_place(_board_panel, Vector2((w - board_side) * 0.5, board_y), Vector2.ONE * board_side)
		_place(_black, Vector2(panel_x, board_y + board_side + 12.0 * s), Vector2(panel_width, 94), s)
		_status.position = Vector2(12.0 * s, minf(h - safe_bottom - 38.0 * s,
			board_y + board_side + 108.0 * s))
		_status.size = Vector2(w - 24.0 * s, 30.0 * s)
		_status_plate.position = _status.position
		_status_plate.size = _status.size
	else:
		_toolbar.set_photo()
		_status.visible = false
		_status_plate.visible = false
		var s := minf(w / PHOTO_SIZE.x, h / PHOTO_SIZE.y)
		var origin := (Vector2(w, h) - PHOTO_SIZE * s) * 0.5
		_place(_photo_background, origin, PHOTO_SIZE * s)
		_place(_board_panel, origin + PHOTO_BOARD_RECT.position * s, PHOTO_BOARD_RECT.size * s)
		# 两侧数字框中心与底图中黑白棋子的中心保持同一水平线。
		_place(_photo_black_count, origin + Vector2(870, PHOTO_COUNTER_TOP) * s, Vector2(470, 180), s)
		_place(_photo_white_count, origin + Vector2(5630, PHOTO_COUNTER_TOP + 30.0) * s, Vector2(470, 180), s)
		var toolbar_scale := s / (1280.0 / PHOTO_SIZE.x)
		_place(_toolbar, origin + Vector2(5140, 12) * s, Vector2(290, 94), toolbar_scale)
	_board_view.queue_redraw()


func _place(node: Control, pos: Vector2, dimensions: Vector2, scale_factor := 1.0) -> void:
	node.position = pos
	node.scale = Vector2.ONE * scale_factor
	node.size = dimensions


func _layout_decor(w: float, y0: float, s: float) -> void:
	_place(_decor.get_node("PlantLeft"), Vector2(-12 * s, y0 + 492 * s), Vector2(230, 228), s)
	_place(_decor.get_node("BooksLeft"), Vector2(-8 * s, y0 + 520 * s), Vector2(220, 132), s)
	_place(_decor.get_node("BallDog"), Vector2(65 * s, y0 + 575 * s), Vector2(210, 150), s)
	_place(_decor.get_node("SleepingCat"), Vector2(w - 318 * s, y0 + 530 * s), Vector2(190, 178), s)
	_place(_decor.get_node("Cup"), Vector2(w - 170 * s, y0 + 546 * s), Vector2(170, 180), s)
	_place(_decor.get_node("BooksRight"), Vector2(w - 130 * s, y0 + 440 * s), Vector2(160, 160), s)
	_place(_decor.get_node("PlantRight"), Vector2(w - 94 * s, y0 + 305 * s), Vector2(102, 165), s)
