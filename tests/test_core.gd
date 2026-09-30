extends SceneTree
## M1 核心逻辑自测（无需图形界面）
##
## 运行：
##   C:\Dev\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_core.gd
##
## 覆盖 docs/需求文档.md §10.1 的可自动化条目：
##   落子合法性 / 四方向成五 / 长连 / 悔棋完整回退 / 悔棋后可再判胜 /
##   人机回合悔棋 / AI 合法性 / AI 必堵活四 / AI 取成五点 / AI 耗时预算 / AI 零副作用

var _pass := 0
var _fail := 0
var _failed_names: Array = []


func _initialize() -> void:
	randomize()
	print("")
	print("========== MoeFive 核心逻辑自测 ==========")

	_test_initial_state()
	_test_place_and_reject()
	_test_win_horizontal()
	_test_win_vertical()
	_test_win_diagonal_down()
	_test_win_diagonal_up()
	_test_long_line()
	_test_undo_basic()
	_test_undo_after_win()
	_test_undo_to_empty()
	_test_undo_turn_pve()
	_test_undo_turn_before_ai_reply()
	_test_ai_opens_center()
	_test_ai_blocks_four()
	_test_ai_takes_win()
	_test_ai_does_not_mutate()
	_test_ai_time_budget()
	_test_ai_selfplay()

	print("------------------------------------------")
	print("通过 %d / 失败 %d" % [_pass, _fail])
	if _fail > 0:
		print("失败项：")
		for n in _failed_names:
			print("  ✗ " + n)
	print("==========================================")
	print("")
	quit(1 if _fail > 0 else 0)


# ========== 断言 ==========

func _check(cond: bool, name: String) -> void:
	if cond:
		_pass += 1
		print("  ✓ " + name)
	else:
		_fail += 1
		_failed_names.append(name)
		print("  ✗ " + name)


# ========== 用例 ==========

func _test_initial_state() -> void:
	print("[初始状态]")
	var b := Board.new()
	_check(b.size == 15, "棋盘 15 × 15")
	_check(b.current == GameConfig.BLACK, "先手为黑")
	_check(b.move_count() == 0, "开局无落子")
	_check(not b.is_over(), "开局未终局")
	_check(b.empty_points().size() == 225, "空点为 225")


func _test_place_and_reject() -> void:
	print("[落子与非法落子]")
	var b := Board.new()
	_check(b.place(7, 7), "天元可落子")
	_check(b.get_cell(7, 7) == GameConfig.BLACK, "落子颜色写入正确")
	_check(b.current == GameConfig.WHITE, "落子后轮到后手")
	_check(not b.place(7, 7), "同点重复落子被拒")
	_check(b.move_count() == 1, "被拒落子不改变手数")
	_check(b.current == GameConfig.WHITE, "被拒落子不改变行动方")
	_check(not b.place(-1, 0), "越界落子被拒")
	_check(not b.place(15, 15), "越界落子被拒（正方向）")


func _test_win_horizontal() -> void:
	print("[横向五连]")
	var b := Board.new()
	for i in 5:
		b.place(i, 0)
		if i < 4:
			b.place(i, 1)
	_check(b.winner == GameConfig.BLACK, "横向五连判胜")
	_check(b.winning_line.size() == 5, "连珠坐标数为 5")
	_check(b.is_over(), "终局标记生效")
	_check(not b.place(10, 10), "终局后禁止继续落子")


func _test_win_vertical() -> void:
	print("[竖向五连]")
	var b := Board.new()
	for i in 5:
		b.place(0, i)
		if i < 4:
			b.place(1, i)
	_check(b.winner == GameConfig.BLACK, "竖向五连判胜")


func _test_win_diagonal_down() -> void:
	print("[斜向五连 · 撇]")
	var b := Board.new()
	for i in 5:
		b.place(i, i)
		if i < 4:
			b.place(10, i)
	_check(b.winner == GameConfig.BLACK, "撇向五连判胜")


func _test_win_diagonal_up() -> void:
	print("[斜向五连 · 捺]")
	var b := Board.new()
	for i in 5:
		b.place(i, 10 - i)
		if i < 4:
			b.place(12, i)
	_check(b.winner == GameConfig.BLACK, "捺向五连判胜")


func _test_long_line() -> void:
	print("[长连]")
	var b := Board.new()
	for i in 6:
		b.cells[b.idx(i, 5)] = GameConfig.BLACK
	var line := b.find_line(3, 5)
	_check(line.size() == 6, "6 连长连被识别为连珠")
	b.reset()
	for i in 5:
		b.cells[b.idx(i, 8)] = GameConfig.WHITE
	_check(b.find_line(0, 8).size() == 5, "恰好 5 连被识别")
	b.reset()
	b.cells[b.idx(0, 0)] = GameConfig.BLACK
	b.cells[b.idx(1, 0)] = GameConfig.BLACK
	_check(b.find_line(0, 0).is_empty(), "4 连不算连珠")


func _test_undo_basic() -> void:
	print("[悔棋 · 基本回退]")
	var b := Board.new()
	b.place(7, 7)
	b.place(7, 8)
	_check(b.move_count() == 2, "已下 2 手")
	var pos := b.undo_one()
	_check(pos == Vector2i(7, 8), "撤掉的是最后一手")
	_check(b.get_cell(7, 8) == GameConfig.EMPTY, "该点恢复为空")
	_check(b.move_count() == 1, "手数减 1")
	_check(b.current == GameConfig.WHITE, "行动权回到被撤方")
	_check(b.get_cell(7, 7) == GameConfig.BLACK, "前一手未受影响")


func _test_undo_after_win() -> void:
	print("[悔棋 · 胜负判定完整回退 —— 重点回归项]")
	var b := Board.new()
	for i in 5:
		b.place(i, 0)
		if i < 4:
			b.place(i, 1)
	_check(b.winner == GameConfig.BLACK, "前置：黑方已成五")

	var pos := b.undo_one()
	_check(pos == Vector2i(4, 0), "撤掉胜方最后一手")
	_check(b.winner == GameConfig.EMPTY, "悔棋后胜负判定被清除")
	_check(b.winning_line.is_empty(), "连珠高亮坐标被清除")
	_check(not b.is_over(), "对局恢复为进行中")
	_check(b.current == GameConfig.BLACK, "行动权回到胜方")

	_check(b.place(4, 0), "同一位置可再次落子")
	_check(b.winner == GameConfig.BLACK, "悔棋后再次成五仍正确判胜（重点回归）")

	# 连撤多手直至不成五
	b.undo_one()
	b.undo_one()
	b.undo_one()
	b.undo_one()
	b.undo_one()
	_check(b.winner == GameConfig.EMPTY, "连续悔棋后胜负判定保持清除")


func _test_undo_to_empty() -> void:
	print("[悔棋 · 撤至空盘]")
	var b := Board.new()
	for i in 9:
		b.place(i % 7, i / 7)
	var n := 0
	while b.can_undo():
		b.undo_one()
		n += 1
	_check(n == 9, "共撤掉 9 手")
	_check(b.move_count() == 0, "回到空盘")
	_check(b.current == GameConfig.BLACK, "空盘后先手为黑")
	_check(b.empty_points().size() == 225, "全盘皆空点")
	_check(b.undo_one() == Vector2i(-1, -1), "空盘继续悔棋安全返回")


func _test_undo_turn_pve() -> void:
	print("[悔棋 · 人机模式撤一回合]")
	var b := Board.new()
	b.place(7, 7)          # 玩家
	b.place(7, 8)          # AI 应手
	_check(b.current == GameConfig.BLACK, "AI 应手后轮到玩家")
	var n := b.undo_turn_for(GameConfig.BLACK)
	_check(n == 2, "撤一回合 = 撤 2 手（玩家手 + AI 应手）")
	_check(b.move_count() == 0, "回到玩家上次决策前（空盘）")
	_check(b.current == GameConfig.BLACK, "行动权在玩家")


func _test_undo_turn_before_ai_reply() -> void:
	print("[悔棋 · AI 未应手时的边界]")
	var b := Board.new()
	b.place(7, 7)
	_check(b.current == GameConfig.WHITE, "玩家落子后轮到 AI")
	var n := b.undo_turn_for(GameConfig.BLACK)
	_check(n == 1, "AI 未应手时只撤 1 手")
	_check(b.move_count() == 0, "回到空盘")
	_check(b.undo_turn_for(GameConfig.BLACK) == 0, "空盘时撤回合安全返回 0")


func _test_ai_opens_center() -> void:
	print("[AI · 空盘开局]")
	var ai := AIPlayer.new()
	var b := Board.new()
	_check(ai.choose_move(b, GameConfig.WHITE, GameConfig.Difficulty.EXPERT) == Vector2i(7, 7), "空盘走天元")


func _test_ai_blocks_four() -> void:
	print("[AI · 必堵活四（Lv2 不漏活四）]")
	var ai := AIPlayer.new()
	var b := Board.new()
	# 玩家在 (3,7)-(6,7) 形成四连，两端 (2,7)/(7,7) 为空
	b.place(3, 7)
	b.place(0, 0)
	b.place(4, 7)
	b.place(0, 1)
	b.place(5, 7)
	b.place(0, 2)
	b.place(6, 7)
	_check(b.current == GameConfig.WHITE, "前置：轮到 AI")

	var mv := ai.choose_move(b, GameConfig.WHITE, GameConfig.Difficulty.NORMAL)
	var ok := (mv == Vector2i(7, 7)) or (mv == Vector2i(2, 7))
	_check(ok, "AI 落子于活四端点（实际 %s）" % str(mv))


func _test_ai_takes_win() -> void:
	print("[AI · 有成五点必取]")
	var ai := AIPlayer.new()
	var b := Board.new()
	# AI 执黑，黑方 (3,7)-(6,7) 四连且轮到黑走
	b.place(3, 7)
	b.place(0, 0)
	b.place(4, 7)
	b.place(0, 1)
	b.place(5, 7)
	b.place(0, 2)
	b.place(6, 7)
	b.place(1, 0)
	_check(b.current == GameConfig.BLACK, "前置：轮到 AI（黑）")

	var mv := ai.choose_move(b, GameConfig.BLACK, GameConfig.Difficulty.EXPERT)
	var ok := (mv == Vector2i(7, 7)) or (mv == Vector2i(2, 7))
	_check(ok, "AI 直接成五取胜（实际 %s）" % str(mv))


func _test_ai_does_not_mutate() -> void:
	print("[AI · 搜索对局面零副作用]")
	var ai := AIPlayer.new()
	var b := Board.new()
	b.place(7, 7)
	b.place(7, 8)
	b.place(8, 8)
	var cells_before := b.cells.duplicate()
	var count_before := b.move_count()
	var current_before := b.current
	ai.choose_move(b, GameConfig.WHITE, GameConfig.Difficulty.EXPERT)
	_check(b.move_count() == count_before, "手数未变")
	_check(b.current == current_before, "行动方未变")
	_check(b.cells == cells_before, "棋盘内容未变")


func _test_ai_time_budget() -> void:
	print("[AI · 思考耗时预算 ≤ %d ms]" % GameConfig.AI_MAX_THINK_MS)
	var ai := AIPlayer.new()
	var b := Board.new()
	# 摆一个中型局面，逼出真实搜索量
	for i in 6:
		b.place(5 + i % 3, 5 + i % 4)
		b.place(8 - i % 3, 8 - i % 4)

	for d in 3:
		var t0 := Time.get_ticks_msec()
		ai.choose_move(b, GameConfig.WHITE, d)
		var dt := Time.get_ticks_msec() - t0
		_check(dt <= GameConfig.AI_MAX_THINK_MS + 300,
			"Lv%d 耗时 %d ms（含超时降级余量）" % [d + 1, dt])


func _test_ai_selfplay() -> void:
	print("[AI · 自我对弈至终局 —— 抓非法落子与死循环]")
	var ai := AIPlayer.new()
	var b := Board.new()
	var guard := 0
	var bad := false

	while not b.is_over() and guard < 225:
		var mv := ai.choose_move(b, b.current, GameConfig.Difficulty.NORMAL)
		if mv == Vector2i(-1, -1):
			_check(false, "AI 返回非法坐标（第 %d 手）" % (guard + 1))
			bad = true
			break
		if not b.place(mv.x, mv.y):
			_check(false, "AI 落在非法位置 %s（第 %d 手）" % [str(mv), guard + 1])
			bad = true
			break
		guard += 1

	if bad:
		return

	_check(b.is_over(), "自对弈走到终局（共 %d 手）" % b.move_count())
	_check(b.move_count() > 6, "对局有实际交手，非秒杀")
	var who := "和棋"
	if b.winner == GameConfig.BLACK:
		who = "黑胜"
	elif b.winner == GameConfig.WHITE:
		who = "白胜"
	print("    → 终局：%s" % who)

	# 终局后悔棋应能恢复对局
	if b.winner != GameConfig.EMPTY:
		b.undo_one()
		_check(not b.is_over(), "终局后悔棋可恢复对局")
