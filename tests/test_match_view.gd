extends SceneTree
## 对局视图集成检查：
## Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_match_view.gd

var _view: MatchView
var _board: Board
var _pass := 0
var _fail := 0
var _undo_seen := false
var _surrender_seen := false
var _return_seen := false


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/match/match_view.tscn")
	if scene == null:
		push_error("对局场景无法加载")
		quit(1)
		return
	_view = scene.instantiate() as MatchView
	if _view == null:
		push_error("对局场景无法实例化为 MatchView")
		quit(1)
		return
	root.add_child(_view)
	_view.custom_minimum_size = Vector2.ZERO
	_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_view.position = Vector2.ZERO
	call_deferred("_run_checks")


func _run_checks() -> void:
	await process_frame
	_check_texture_bindings(_view)
	_board = Board.new()
	_view.bind_board(_board)
	var toolbar: HBoxContainer = _view.get_node("SafeLayout/ActionToolbar")
	var names := PackedStringArray()
	for child in toolbar.get_children():
		names.append(child.name)
	_check(names == PackedStringArray(["UndoButton", "SurrenderButton", "ReturnButton"]),
		"按钮节点从左到右：悔棋、认输、返回")
	var undo: TextureButton = toolbar.get_node("UndoButton")
	var surrender: TextureButton = toolbar.get_node("SurrenderButton")
	var back: TextureButton = toolbar.get_node("ReturnButton")
	_check(undo.tooltip_text == "悔棋" and surrender.tooltip_text == "认输" and back.tooltip_text == "返回",
		"按钮语义与节点顺序一致")
	_view.undo_requested.connect(func(): _undo_seen = true)
	_view.surrender_requested.connect(func(): _surrender_seen = true)
	_view.return_requested.connect(func(): _return_seen = true)
	undo.pressed.emit()
	surrender.pressed.emit()
	back.pressed.emit()
	_check(_undo_seen and _surrender_seen and _return_seen, "三个按钮信号传递到对局场景")

	var state := MatchViewState.new()
	state.status = "轮到玩家一"
	_view.apply_state(state)
	_check(undo.disabled, "空盘时悔棋禁用")
	_check(_view.get_node("SafeLayout/PlayerPanelBlack/Count").text == "× 0", "开局黑方计数为零")
	_check(_view.get_node("SafeLayout/PlayerPanelWhite/Count").text == "× 0", "开局白方计数为零")
	_check(_view.get_node("SafeLayout/PhotoBlackCount").text == "× 0"
		and _view.get_node("SafeLayout/PhotoWhiteCount").text == "× 0",
		"新底图开局双方计数为零")
	_check(_view.get_node("SafeLayout/PhotoBlackCount").modulate.a >
		_view.get_node("SafeLayout/PhotoWhiteCount").modulate.a,
		"开局突出黑方落子数")

	_check(_board.place(7, 7) and _board.place(8, 8), "两方各落一子")
	state.black_count = 1
	state.white_count = 1
	state.can_undo = _board.can_undo()
	state.active_side = _board.current
	_view.apply_state(state)
	_check(not undo.disabled, "有历史落子时悔棋可用")
	_check(_view.get_node("SafeLayout/PlayerPanelBlack/Count").text == "× 1", "黑方计数同步")
	_check(_view.get_node("SafeLayout/PlayerPanelWhite/Count").text == "× 1", "白方计数同步")
	_check(_view.get_node("SafeLayout/PhotoBlackCount").text == "× 1"
		and _view.get_node("SafeLayout/PhotoWhiteCount").text == "× 1",
		"新底图双方计数同步")

	_board.undo_one()
	state.white_count = 0
	state.active_side = _board.current
	state.can_undo = _board.can_undo()
	_view.apply_state(state)
	_check(_view.get_node("SafeLayout/PlayerPanelWhite/Count").text == "× 0", "悔棋后白方计数同步")
	_check(_view.get_node("SafeLayout/PhotoWhiteCount").text == "× 0"
		and _view.get_node("SafeLayout/PhotoWhiteCount").modulate.a >
		_view.get_node("SafeLayout/PhotoBlackCount").modulate.a,
		"悔棋后突出白方并更新计数")
	_board.undo_one()
	state.black_count = 0
	state.can_undo = _board.can_undo()
	state.active_side = _board.current
	_view.apply_state(state)
	_check(undo.disabled and _view.get_node("SafeLayout/PlayerPanelBlack/Count").text == "× 0",
		"撤至空盘后计数与悔棋状态同步")

	for dimensions in [Vector2(1280, 720), Vector2(1920, 1080),
		Vector2(1024, 768), Vector2(2560, 1080), Vector2(390, 844)]:
		_view.size = dimensions
		_view.call("_layout")
		await process_frame
		var board_view: BoardView = _view.get_board_view()
		if board_view.photo_mode:
			_check_photo_board_coordinates(dimensions)
		elif board_view.reference_mode:
			_check_reference_board_coordinates(dimensions)
		else:
			_check_non_reference_board_coordinates(dimensions)
		_check(board_view.size.x > 100.0 and board_view.size.y > 100.0,
			"%s 棋盘交互区域已布局" % str(dimensions))
		_check(toolbar.get_child(0).position.x < toolbar.get_child(1).position.x
			and toolbar.get_child(1).position.x < toolbar.get_child(2).position.x,
			"%s 三按钮保持横排顺序" % str(dimensions))
		var toolbar_end := toolbar.position + toolbar.size * toolbar.scale
		_check(toolbar.position.x >= -0.5 and toolbar.position.y >= -0.5
			and toolbar_end.x <= dimensions.x + 0.5
			and toolbar_end.y <= dimensions.y + 0.5,
			"%s 操作区完整位于窗口内 (%s → %s)" % [str(dimensions), str(toolbar.position), str(toolbar_end)])

	state.thinking = true
	_view.apply_state(state)
	_check(not _view.get_board_view().interactive, "AI 思考时棋盘锁定")
	state.thinking = false
	state.finished = true
	_view.apply_state(state)
	_check(undo.disabled and not _view.get_board_view().interactive, "终局时操作状态正确")

	print("对局视图集成检查：通过 %d，失败 %d" % [_pass, _fail])
	_view.queue_free()
	quit(1 if _fail > 0 else 0)


func _check_reference_board_coordinates(dimensions: Vector2) -> void:
	var board_view: BoardView = _view.get_board_view()
	var x_points := [499.0, 552.0, 604.0, 657.0, 710.0, 763.0, 816.0,
		869.0, 923.0, 976.0, 1028.0, 1080.0, 1133.0, 1186.0, 1235.0]
	var y_points := [107.0, 160.0, 214.0, 268.0, 322.0, 376.0, 430.0,
		484.0, 538.0, 593.0, 646.0, 700.0, 754.0, 808.0, 862.0]
	var image_scale := minf(dimensions.x / 1672.0, dimensions.y / 941.0)
	var image_origin := (dimensions - Vector2(1672.0, 941.0) * image_scale) * 0.5
	var to_board := board_view.get_global_transform().affine_inverse()
	var all_correct := true
	for y in _board.size:
		for x in _board.size:
			var point: Vector2 = to_board * (image_origin + Vector2(x_points[x], y_points[y]) * image_scale)
			if board_view.cell_at(point) != Vector2i(x, y):
				all_correct = false
	_check(all_correct, "%s 原型图中全部 225 个交点映射准确" % str(dimensions))
	_check(board_view.cell_at(Vector2.ZERO) == Vector2i(-1, -1),
		"%s 棋盘外点击不落子" % str(dimensions))


func _check_photo_board_coordinates(dimensions: Vector2) -> void:
	var board_view: BoardView = _view.get_board_view()
	var x_points := [1804.0, 2031.0, 2250.0, 2472.0, 2690.0, 2914.0, 3136.0,
		3353.0, 3571.0, 3789.0, 4013.0, 4233.0, 4456.0, 4675.0, 4901.0]
	var y_points := [369.0, 587.0, 801.0, 1019.0, 1237.0, 1453.0, 1674.0,
		1892.0, 2107.0, 2329.0, 2546.0, 2762.0, 2981.0, 3199.0, 3399.0]
	var image_scale := minf(dimensions.x / 6680.0, dimensions.y / 3768.0)
	var image_origin := (dimensions - Vector2(6680.0, 3768.0) * image_scale) * 0.5
	var to_board := board_view.get_global_transform().affine_inverse()
	var all_correct := true
	for y in _board.size:
		for x in _board.size:
			var point: Vector2 = to_board * (image_origin + Vector2(x_points[x], y_points[y]) * image_scale)
			if board_view.cell_at(point) != Vector2i(x, y):
				all_correct = false
	_check(all_correct, "%s 新底图中全部 225 个交点映射准确" % str(dimensions))
	_check(board_view.cell_at(Vector2.ZERO) == Vector2i(-1, -1),
		"%s 棋盘外点击不落子" % str(dimensions))


func _check_non_reference_board_coordinates(dimensions: Vector2) -> void:
	var board_view: BoardView = _view.get_board_view()
	var center := board_view.size * 0.5
	_check(board_view.cell_at(center) == Vector2i(7, 7),
		"%s 紧凑棋盘中心映射准确" % str(dimensions))
	_check(board_view.cell_at(Vector2.ZERO) == Vector2i(-1, -1),
		"%s 棋盘外点击不落子" % str(dimensions))


func _check_texture_bindings(node: Node) -> void:
	var broken := PackedStringArray()
	_collect_missing_textures(node, broken)
	_check(broken.is_empty(), "场景所有贴图引用可加载%s" % ("" if broken.is_empty() else ": " + ", ".join(broken)))


func _collect_missing_textures(node: Node, broken: PackedStringArray) -> void:
	if node is TextureRect and (node as TextureRect).texture == null:
		broken.append(str(node.get_path()))
	elif node is TextureButton and (node as TextureButton).texture_normal == null:
		broken.append(str(node.get_path()))
	elif node is NinePatchRect and (node as NinePatchRect).texture == null:
		broken.append(str(node.get_path()))
	for child in node.get_children():
		_collect_missing_textures(child, broken)


func _check(condition: bool, label: String) -> void:
	if condition:
		_pass += 1
		print("  ✓ " + label)
	else:
		_fail += 1
		push_error("  ✗ " + label)
