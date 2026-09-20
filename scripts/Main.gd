extends Control
class_name Main
## MoeFive 主流程（M1 占位界面）。
##
## 职责：屏幕状态机（主页 / 难度 / 对局）、对局流程编排、悔棋与认输、
## 结算层、键盘快捷键（决策 D7）。
##
## M1 说明：界面为程序化占位美术，配色取自需求 §4.2；
## 动效（A1–A16）与音效（S1–S13）留待 M3。
## AI 思考目前同步执行并藏在"思考态"延迟之后，线程化留待 M3。

enum Screen { HOME, DIFFICULTY, GAME }

const PANEL_PAD := 20

var board := Board.new()
var ai := AIPlayer.new()
var mode: int = GameConfig.Mode.PVP
var difficulty: int = GameConfig.Difficulty.NOVICE
var undo_count: int = 0

var _screen: int = Screen.HOME
var _layer: Control
var _board_view: BoardView
var _status: Label
var _quote: Label
var _card_p1: PanelContainer
var _card_p2: PanelContainer
var _count_p1: Label
var _count_p2: Label
var _btn_undo: Button
var _modal: Control
var _ai_busy := false
var _ai_timer: Timer


func _ready() -> void:
	randomize()
	_apply_theme()

	_ai_timer = Timer.new()
	_ai_timer.one_shot = true
	_ai_timer.timeout.connect(_ai_turn)
	add_child(_ai_timer)

	_show_home()


# ========== 主题与中文字体 ==========

## M1 占位：加载系统中文（Godot 内置默认字体不含 CJK）。
## ⚠️ 打包前必须内嵌一款**授权可商用**的中文字体（M4 决策，见需求 §9 体积预算）。
func _load_cjk_font() -> Font:
	var candidates := [
		"C:/Windows/Fonts/msyh.ttc",
		"C:/Windows/Fonts/simhei.ttf",
		"C:/Windows/Fonts/simsun.ttc",
		"/System/Library/Fonts/PingFang.ttc",
		"/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
	]
	for p in candidates:
		if FileAccess.file_exists(p):
			var f := FontFile.new()
			if f.load_dynamic_font(p) == OK:
				print("MoeFive: UI 字体 -> %s（占位，打包前需内嵌可商用字体）" % p)
				return f
	push_warning("MoeFive: 未找到中文字体，中文可能显示异常")
	return null


func _apply_theme() -> void:
	var t := Theme.new()
	var f := _load_cjk_font()
	if f != null:
		t.default_font = f
	t.default_font_size = 18
	theme = t


# ========== 通用控件工厂 ==========

func _make_button(text: String, bg: Color, min_w := 200.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", GameConfig.C_TEXT_INV)
	b.add_theme_color_override("font_hover_color", GameConfig.C_TEXT_INV)
	b.add_theme_color_override("font_pressed_color", GameConfig.C_TEXT_INV)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))

	var normal := _round_box(bg, 12)
	var hover := _round_box(bg.lightened(0.10), 12)
	var pressed := _round_box(bg.darkened(0.14), 12)
	var focus := _round_box(bg, 12)
	focus.border_color = GameConfig.C_ACCENT
	focus.set_border_width_all(2)
	var disabled := _round_box(Color(bg.r, bg.g, bg.b, 0.35), 12)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", disabled)
	return b


func _round_box(bg: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = PANEL_PAD * 0.8
	sb.content_margin_right = PANEL_PAD * 0.8
	sb.content_margin_top = PANEL_PAD * 0.5
	sb.content_margin_bottom = PANEL_PAD * 0.5
	sb.shadow_color = Color(0.25, 0.15, 0.08, 0.22)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _make_label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


func _plaque(text: String, fs: int) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := _round_box(GameConfig.C_BOARD_FRAME, 14)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(_make_label(text, fs, GameConfig.C_TEXT_INV))
	return pc


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _random_quote() -> String:
	return GameConfig.SCENE_QUOTES[randi() % GameConfig.SCENE_QUOTES.size()]


func _clear_layer() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_board_view = null
	_status = null
	_quote = null
	_card_p1 = null
	_card_p2 = null
	_count_p1 = null
	_count_p2 = null
	_btn_undo = null


# ========== 背景 ==========

func _draw() -> void:
	var steps := 28
	var h := size.y / float(steps)
	for i in steps:
		var t := float(i) / float(steps - 1)
		draw_rect(Rect2(0.0, h * float(i), size.x, h + 1.0),
			GameConfig.C_SCENE_TOP.lerp(GameConfig.C_SCENE_BOTTOM, t))


# ========== 主页 ==========

func _show_home() -> void:
	_screen = Screen.HOME
	_clear_layer()

	_layer = CenterContainer.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_layer.add_child(col)

	col.add_child(_plaque("五子棋", 34))
	var sub := _make_label("· 以棋会友 · 快乐常在 ·", 15, Color(GameConfig.C_TEXT, 0.78))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(_spacer(16))

	var b1 := _make_button("双人对战", GameConfig.C_P1, 260)
	b1.pressed.connect(_on_pvp_pressed)
	col.add_child(b1)

	var b2 := _make_button("人机对战", GameConfig.C_P2, 260)
	b2.pressed.connect(_show_difficulty)
	col.add_child(b2)

	col.add_child(_spacer(20))
	var q := _make_label(_random_quote(), 15, Color(GameConfig.C_TEXT, 0.72))
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(q)


func _on_pvp_pressed() -> void:
	_begin(GameConfig.Mode.PVP, GameConfig.Difficulty.NOVICE)


# ========== 难度选择 ==========

func _show_difficulty() -> void:
	_screen = Screen.DIFFICULTY
	_clear_layer()

	_layer = CenterContainer.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_layer.add_child(col)

	col.add_child(_plaque("选择对手", 26))
	col.add_child(_spacer(10))

	for i in GameConfig.DIFFICULTY_NAMES.size():
		var idx := i
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)

		var b := _make_button(GameConfig.DIFFICULTY_NAMES[idx], GameConfig.C_P2, 260)
		b.pressed.connect(func(): _begin(GameConfig.Mode.PVE, idx))
		box.add_child(b)

		var t := _make_label(GameConfig.DIFFICULTY_TAGLINE[idx], 14, Color(GameConfig.C_TEXT, 0.72))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(t)
		col.add_child(box)

	col.add_child(_spacer(16))
	var back := _make_button("返回", GameConfig.C_BOARD_FRAME, 140)
	back.pressed.connect(_show_home)
	col.add_child(back)


# ========== 对局 ==========

func _begin(m: int, d: int) -> void:
	mode = m
	difficulty = d
	board.reset()
	undo_count = 0
	_ai_busy = false
	if _ai_timer != null:
		_ai_timer.stop()
	_screen = Screen.GAME
	_clear_layer()
	_build_game_ui()
	_refresh()


func _build_game_ui() -> void:
	_layer = MarginContainer.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_layer.add_theme_constant_override("margin_" + side, 22)
	add_child(_layer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_layer.add_child(root)

	# --- 顶部：标题牌 + 场景短句 ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	top.add_child(_plaque("五子棋", 20))
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(filler)
	_quote = _make_label(_random_quote(), 15, Color(GameConfig.C_TEXT, 0.72))
	top.add_child(_quote)

	# --- 中部：左栏 / 棋盘 / 右栏 ---
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 14)
	root.add_child(mid)

	mid.add_child(_player_column(true, "玩家一", GameConfig.C_P1, GameConfig.C_P1_CREAM))

	_board_view = BoardView.new()
	_board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view.set_board(board)
	_board_view.point_pressed.connect(_on_point_pressed)
	mid.add_child(_board_view)

	mid.add_child(_player_column(false, "玩家二" if mode == GameConfig.Mode.PVP else "电脑",
		GameConfig.C_P2, GameConfig.C_P2_CREAM))

	# --- 底部：状态 + 操作 ---
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)

	var back := _make_button("返回", GameConfig.C_BOARD_FRAME, 96)
	back.custom_minimum_size.y = 44
	back.pressed.connect(_on_back_pressed)
	bottom.add_child(back)

	_status = _make_label("", 17, Color(GameConfig.C_TEXT, 0.9))
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_status)

	_btn_undo = _make_button(GameConfig.BTN_UNDO, GameConfig.C_ACCENT, 120)
	_btn_undo.custom_minimum_size.y = 44
	_btn_undo.pressed.connect(_do_undo)
	bottom.add_child(_btn_undo)

	var sur := _make_button(GameConfig.BTN_SURRENDER, GameConfig.C_P1, 120)
	sur.custom_minimum_size.y = 44
	sur.pressed.connect(_on_surrender_pressed)
	bottom.add_child(sur)


func _player_column(is_p1: bool, name: String, accent: Color, cream: Color) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(180, 0)
	col.add_theme_constant_override("separation", 8)

	var card := PanelContainer.new()
	var sb := _round_box(cream, 14)
	sb.border_color = accent
	sb.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", sb)
	col.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)

	var nm := _make_label(name, 20, GameConfig.C_TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(nm)

	var stone := _make_label("●" if is_p1 else "○", 22, accent)
	stone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(stone)

	var cnt := _make_label("手数 0", 15, Color(GameConfig.C_TEXT, 0.78))
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(cnt)

	if is_p1:
		_card_p1 = card
		_count_p1 = cnt
	else:
		_card_p2 = card
		_count_p2 = cnt

	# 角色气泡（占位：圆形色块模拟萌宠头像位）
	var avatar := PanelContainer.new()
	var asb := _round_box(accent, 999)
	asb.content_margin_left = 26
	asb.content_margin_right = 26
	asb.content_margin_top = 20
	asb.content_margin_bottom = 20
	avatar.add_theme_stylebox_override("panel", asb)
	col.add_child(avatar)
	var pet := _make_label("🐶" if is_p1 else "🐱", 30, GameConfig.C_TEXT_INV)
	pet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.add_child(pet)

	col.add_child(_spacer(4))
	var bubble := _make_label("加油！🐾" if is_p1 else "来一局吧！🐾", 15, Color(GameConfig.C_TEXT, 0.82))
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(bubble)

	return col


# ========== 对局流程 ==========

func _on_point_pressed(cell: Vector2i) -> void:
	if _ai_busy or board.is_over():
		return
	if mode == GameConfig.Mode.PVE and board.current != GameConfig.BLACK:
		return

	if not board.place(cell.x, cell.y):
		# 非法落子：拒绝但不改变任何状态（需求 §3.2 · 动效 A5 的占位反馈）
		_flash_status("这里已经有棋子啦～")
		return

	_refresh()
	if board.is_over():
		_show_result()
		return
	if mode == GameConfig.Mode.PVE:
		_start_ai_turn()


func _start_ai_turn() -> void:
	_ai_busy = true
	if _board_view != null:
		_board_view.interactive = false
	_flash_status(GameConfig.QUOTE_AI_THINKING[randi() % GameConfig.QUOTE_AI_THINKING.size()])
	_refresh()
	_ai_timer.start(float(GameConfig.AI_MIN_DELAY_MS) / 1000.0)


func _ai_turn() -> void:
	var mv := ai.choose_move(board, GameConfig.WHITE, difficulty)
	if mv == Vector2i(-1, -1):
		var empties := board.empty_points()
		if empties.is_empty():
			_ai_busy = false
			return
		mv = empties[0]

	board.place(mv.x, mv.y)
	_ai_busy = false
	if _board_view != null:
		_board_view.interactive = true
	_refresh()
	if board.is_over():
		_show_result()


func _do_undo() -> void:
	if _ai_busy:
		# AI 尚未应手 → 取消其思考并只撤玩家那一手（需求 §3.3 边界）
		_ai_timer.stop()
		_ai_busy = false
		if _board_view != null:
			_board_view.interactive = true

	if board.is_over() or not board.can_undo():
		return

	undo_count += 1
	if mode == GameConfig.Mode.PVE:
		board.undo_turn_for(GameConfig.BLACK)
	else:
		board.undo_one()

	_flash_status("撤回一步（本局第 %d 次）" % undo_count)
	_refresh()


func _on_surrender_pressed() -> void:
	if board.is_over() or _ai_busy:
		return
	_show_confirm(
		GameConfig.CONFIRM_SURRENDER_TITLE,
		GameConfig.CONFIRM_SURRENDER_BODY,
		GameConfig.CONFIRM_SURRENDER_OK,
		GameConfig.CONFIRM_SURRENDER_CANCEL,
		_do_surrender
	)


func _do_surrender() -> void:
	# 认输方 = 单人模式下必为玩家一（黑）
	board.winner = GameConfig.WHITE
	board.winning_line.clear()
	_refresh()
	_show_result()


func _on_back_pressed() -> void:
	if board.is_over() or board.move_count() == 0:
		_show_home()
		return
	_show_confirm("要离开这局棋吗？", "当前进度不会保存哦。", "离开", "再下一会儿", _show_home)


func _refresh() -> void:
	if _board_view != null:
		_board_view.queue_redraw()
	if _count_p1 != null:
		_count_p1.text = "手数 %d" % _count_of(GameConfig.BLACK)
	if _count_p2 != null:
		_count_p2.text = "手数 %d" % _count_of(GameConfig.WHITE)
	if _btn_undo != null:
		_btn_undo.disabled = _ai_busy or board.is_over() or not board.can_undo()
	if _status != null and not board.is_over():
		_status.text = _turn_text()
	_update_cards()


func _count_of(color: int) -> int:
	var n := 0
	for pos in board.history:
		if board.get_cell(pos.x, pos.y) == color:
			n += 1
	return n


func _turn_text() -> String:
	if mode == GameConfig.Mode.PVE:
		if _ai_busy:
			return "对手在思考…"
		return "轮到你落子"
	return "轮到「%s」" % ("玩家一" if board.current == GameConfig.BLACK else "玩家二")


func _update_cards() -> void:
	if _card_p1 == null or _card_p2 == null:
		return
	var active: int = board.current
	_card_p1.modulate = Color.WHITE if active == GameConfig.BLACK else Color(0.82, 0.82, 0.82)
	_card_p2.modulate = Color.WHITE if active == GameConfig.WHITE else Color(0.82, 0.82, 0.82)


func _flash_status(text: String) -> void:
	if _status != null:
		_status.text = text


# ========== 模态层 ==========

func _show_confirm(title: String, body: String, ok_text: String,
		cancel_text: String, on_ok: Callable) -> void:
	var modal := _make_modal_base()
	var box := modal.get_node("Box") as VBoxContainer
	box.add_child(_modal_title(title))
	box.add_child(_make_label(body, 15, Color(GameConfig.C_TEXT, 0.82)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var cancel := _make_button(cancel_text, GameConfig.C_BOARD_FRAME, 130)
	cancel.custom_minimum_size.y = 46
	cancel.pressed.connect(_close_modal)
	row.add_child(cancel)

	var ok := _make_button(ok_text, GameConfig.C_ACCENT, 130)
	ok.custom_minimum_size.y = 46
	ok.pressed.connect(func():
		_close_modal()
		if on_ok.is_valid():
			on_ok.call()
	)
	row.add_child(ok)


func _show_result() -> void:
	var won := false
	var title := GameConfig.RESULT_DRAW
	if board.is_draw:
		title = GameConfig.RESULT_DRAW
	elif mode == GameConfig.Mode.PVE:
		won = board.winner == GameConfig.BLACK
		title = GameConfig.RESULT_WIN if won else GameConfig.RESULT_LOSE
	else:
		won = board.winner == GameConfig.BLACK
		title = "「%s」赢了！" % ("玩家一" if won else "玩家二")

	var modal := _make_modal_base()
	var box := modal.get_node("Box") as VBoxContainer
	box.add_child(_modal_title(title))

	var lines := "本局共 %d 手" % board.move_count()
	if undo_count > 0:
		lines += "\n悔棋 %d 次" % undo_count
	var stat := _make_label(lines, 15, Color(GameConfig.C_TEXT, 0.80))
	stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stat)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var home := _make_button(GameConfig.BTN_HOME, GameConfig.C_BOARD_FRAME, 150)
	home.custom_minimum_size.y = 46
	home.pressed.connect(func():
		_close_modal()
		_show_home()
	)
	row.add_child(home)

	var again := _make_button(GameConfig.BTN_AGAIN, GameConfig.C_ACCENT, 150)
	again.custom_minimum_size.y = 46
	again.pressed.connect(func():
		_close_modal()
		_begin(mode, difficulty)
	)
	row.add_child(again)


func _make_modal_base() -> Control:
	_close_modal()

	var modal := Control.new()
	modal.name = "Modal"
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)

	var dim := ColorRect.new()
	dim.color = GameConfig.C_OVERLAY
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	var card := PanelContainer.new()
	var sb := _round_box(GameConfig.C_P1_CREAM, 18)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)

	_modal = modal
	return modal


func _modal_title(text: String) -> Label:
	var l := _make_label(text, 26, GameConfig.C_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _close_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null


# ========== 快捷键（决策 D7）==========

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _screen != Screen.GAME:
		return

	match event.keycode:
		KEY_ESCAPE:
			if _modal != null:
				_close_modal()
		KEY_U:
			if _modal == null:
				_do_undo()
		KEY_R:
			if _modal == null:
				_on_surrender_pressed()
		KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
