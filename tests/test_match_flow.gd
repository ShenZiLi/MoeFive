extends SceneTree
## Match orchestration regression checks after the view extraction.

var _main: Main
var _pass := 0
var _fail := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_main = load("res://main.tscn").instantiate() as Main
	root.add_child(_main)
	await process_frame
	_main._begin(GameConfig.Mode.PVP, GameConfig.Difficulty.NOVICE)
	_check(_main._match_view != null and _main._board_view != null, "双人模式进入对局")
	_main._on_point_pressed(Vector2i(7, 7))
	_check(_main.board.move_count() == 1 and _main.board.current == GameConfig.WHITE,
		"双人模式落子与行动方")
	_main._do_undo()
	_check(_main.board.move_count() == 0 and _main.board.current == GameConfig.BLACK,
		"双人模式撤至空盘")
	_main._on_surrender_pressed()
	_check(_main._modal != null and _main._modal.get_parent() == _main._match_view,
		"认输确认层在对局场景最上层")
	_main._close_modal()
	await process_frame
	_check(_main._modal == null and not _main.board.is_over(), "取消认输继续对局")
	_main._on_surrender_pressed()
	_main._do_surrender()
	_check(_main.board.is_over() and _main.board.winner == GameConfig.WHITE,
		"确认认输结算")
	_main._begin(GameConfig.Mode.PVP, GameConfig.Difficulty.NOVICE)
	await process_frame
	_check(_main.board.move_count() == 0 and _main._modal == null, "结算后重新开局")
	_main._begin(GameConfig.Mode.PVE, GameConfig.Difficulty.NOVICE)
	_main._on_point_pressed(Vector2i(7, 7))
	_check(_main._ai_busy and _main.board.move_count() == 1
		and not _main._board_view.interactive, "人机思考时棋盘锁定")
	_main._do_undo()
	_check(not _main._ai_busy and _main.board.move_count() == 0
		and _main._board_view.interactive, "思考期间悔棋取消 AI 回合")
	_main._ai_turn()
	_check(_main.board.move_count() == 0, "取消后迟到回调不落子")
	_main._on_point_pressed(Vector2i(7, 7))
	_main._show_home()
	await process_frame
	_main._ai_turn()
	_check(_main._screen == Main.Screen.HOME and _main.board.move_count() == 1
		and _main._match_view == null, "退出后迟到 AI 回调不修改旧棋局")
	_main._begin(GameConfig.Mode.PVP, GameConfig.Difficulty.NOVICE)
	_check(_main.board.move_count() == 0 and _main._match_view != null,
		"退出后再次进入无残留状态")
	print("对局流程检查：通过 %d，失败 %d" % [_pass, _fail])
	_main.queue_free()
	quit(1 if _fail else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_pass += 1
		print("  ✓ " + description)
	else:
		_fail += 1
		push_error("  ✗ " + description)
