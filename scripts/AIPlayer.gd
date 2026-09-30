extends RefCounted
class_name AIPlayer
## 五子棋 AI（需求文档 §7）。
##
## 三档难度**共享同一套评估函数**，仅通过 搜索深度 / 候选宽度 / 失误概率
## 三个参数区分，避免三套逻辑分叉维护。
##
## 全部搜索在 Board 的副本上进行 —— 对游戏状态零副作用。
## 单步思考受 AI_MAX_THINK_MS 约束，超时即返回当前最优候选（不卡界面）。

# ---------- 方向 ----------
const DIR_X := [1, 0, 1, 1]
const DIR_Y := [0, 1, 1, -1]

# ---------- 棋型分值 ----------
const S_FIVE := 10000000
const S_OPEN_FOUR := 1000000
const S_FOUR := 100000
const S_OPEN_THREE := 50000
const S_THREE := 5000
const S_OPEN_TWO := 3000
const S_TWO := 300
const S_ONE := 10

const INF := 999999999

var _size: int = GameConfig.BOARD_SIZE
var _me: int = GameConfig.BLACK
var _opp: int = GameConfig.WHITE
var _width: int = 8
var _deadline: int = 0
var _timed_out: bool = false


## 主入口：返回 AI 决定落子的坐标。
func choose_move(board: Board, my_color: int, difficulty: int) -> Vector2i:
	var params: Dictionary = GameConfig.DIFFICULTY_PARAMS[difficulty]
	_me = my_color
	_opp = board.opponent_of(my_color)
	_size = board.size
	_width = int(params["width"])
	_blunder = float(params["blunder"])
	_timed_out = false
	_deadline = Time.get_ticks_usec() + GameConfig.AI_MAX_THINK_MS * 1000

	var work := board.clone()
	if work.history.is_empty():
		return Vector2i(_size / 2, _size / 2)   # 空盘走天元

	# 1) 自己能一手成五 → 直接赢（任何难度都会）
	var my_win := _find_winning_move(work, _me)
	if my_win != Vector2i(-1, -1):
		return my_win

	# 2) 对手能一手成五 → 必须堵。
	#    Lv1 有小概率漏看，这正是"新手能赢"的来源（需求 §7.1）。
	var opp_win := _find_winning_move(work, _opp)
	if opp_win != Vector2i(-1, -1):
		if not (_blunder > 0.0 and randf() < _blunder):
			return opp_win

	var best := _search_root(work, int(params["depth"]))
	if best == Vector2i(-1, -1):
		var empties := work.empty_points()
		if not empties.is_empty():
			return empties[0]
	return best


var _blunder: float = 0.0


# ========== 搜索 ==========

func _search_root(work: Board, depth: int) -> Vector2i:
	var cands := _ordered_candidates(work, _me)
	var best_move := Vector2i(-1, -1)
	var best_score := -INF
	var alpha := -INF

	for mv in cands:
		if _time_up():
			break
		work.place(mv.x, mv.y)
		var sc: int
		if work.winner == _me:
			sc = S_FIVE
		else:
			sc = -_negamax(work, depth - 1, -INF, -alpha, _opp)
		work.undo_one()

		if sc > best_score:
			best_score = sc
			best_move = mv
		if sc > alpha:
			alpha = sc

	return best_move


func _negamax(work: Board, depth: int, alpha: int, beta: int, color: int) -> int:
	if work.winner != GameConfig.EMPTY:
		return S_FIVE if work.winner == color else -S_FIVE
	if work.is_draw:
		return 0
	if depth <= 0 or _time_up():
		return _evaluate(work, color)

	var best := -INF
	for mv in _ordered_candidates(work, color):
		work.place(mv.x, mv.y)
		var sc := -_negamax(work, depth - 1, -beta, -alpha, work.opponent_of(color))
		work.undo_one()

		if sc > best:
			best = sc
		if best > alpha:
			alpha = best
		if alpha >= beta:
			break   # beta 剪枝
	return best


func _time_up() -> bool:
	if _timed_out:
		return true
	if Time.get_ticks_usec() > _deadline:
		_timed_out = true
		return true
	return false


# ========== 候选点 ==========

## 按启发值排序，取前 _width 个。
func _ordered_candidates(board: Board, color: int) -> Array:
	var scored: Array = []
	for y in board.size:
		for x in board.size:
			if board.cells[board.idx(x, y)] != GameConfig.EMPTY:
				continue
			if not _has_neighbor(board, x, y):
				continue
			scored.append([_heuristic(board, x, y, color), Vector2i(x, y)])

	scored.sort_custom(_cmp_scored)

	var out: Array = []
	var n: int = mini(_width, scored.size())
	for i in n:
		out.append(scored[i][1])
	return out


func _cmp_scored(a: Array, b: Array) -> bool:
	return int(a[0]) > int(b[0])


## 邻域剪枝：2 格内有棋子才纳入候选，避免在空盘角落浪费时间。
func _has_neighbor(board: Board, x: int, y: int) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if board.in_bounds(nx, ny) and board.cells[board.idx(nx, ny)] != GameConfig.EMPTY:
				return true
	return false


## 启发值 = 我方进攻价值 + 对方防守价值（略偏防守）。
func _heuristic(board: Board, x: int, y: int, color: int) -> int:
	var atk := _point_score(board, x, y, color)
	var dfn := _point_score(board, x, y, board.opponent_of(color))
	return atk + int(dfn * 0.9)


## 查找某方的"一手成五点"，无则返回 (-1, -1)。
func _find_winning_move(board: Board, color: int) -> Vector2i:
	for y in board.size:
		for x in board.size:
			if board.cells[board.idx(x, y)] != GameConfig.EMPTY:
				continue
			if not _has_neighbor(board, x, y):
				continue
			if _point_score(board, x, y, color) >= S_FIVE:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


# ========== 评估 ==========

## 以 color 视角的局面分。
func _evaluate(board: Board, color: int) -> int:
	if board.winner != GameConfig.EMPTY:
		return S_FIVE if board.winner == color else -S_FIVE
	var mine := _side_score(board, color)
	var theirs := _side_score(board, board.opponent_of(color))
	return mine - int(theirs * 1.15)


## 某方全部棋型分之和。只从"串头"起算，避免同一串被重复计数。
func _side_score(board: Board, color: int) -> int:
	var total := 0
	for pos in board.history:
		var x: int = pos.x
		var y: int = pos.y
		if board.cells[board.idx(x, y)] != color:
			continue
		for k in 4:
			var dx: int = DIR_X[k]
			var dy: int = DIR_Y[k]
			var bx := x - dx
			var by := y - dy
			if board.in_bounds(bx, by) and board.cells[board.idx(bx, by)] == color:
				continue   # 不是串头
			total += _line_value(board, x, y, dx, dy, color)
	return total


## 单点棋型分：假设 (x, y) 处为 color，统计该点所在棋串的棋型。
## 会临时占用该格再还原，调用方无需担心副作用。
func _point_score(board: Board, x: int, y: int, color: int) -> int:
	var i := board.idx(x, y)
	var old := board.cells[i]
	board.cells[i] = color
	var total := 0
	for k in 4:
		total += _line_value(board, x, y, DIR_X[k], DIR_Y[k], color)
	board.cells[i] = old
	return total


## 从 (x, y) 出发沿 (dx, dy) 的双向棋串评分。
func _line_value(board: Board, x: int, y: int, dx: int, dy: int, color: int) -> int:
	var count := 1
	var open_ends := 0

	var px := x + dx
	var py := y + dy
	while board.in_bounds(px, py) and board.cells[board.idx(px, py)] == color:
		count += 1
		px += dx
		py += dy
	if board.in_bounds(px, py) and board.cells[board.idx(px, py)] == GameConfig.EMPTY:
		open_ends += 1

	px = x - dx
	py = y - dy
	while board.in_bounds(px, py) and board.cells[board.idx(px, py)] == color:
		count += 1
		px -= dx
		py -= dy
	if board.in_bounds(px, py) and board.cells[board.idx(px, py)] == GameConfig.EMPTY:
		open_ends += 1

	return _pattern_value(count, open_ends)


func _pattern_value(count: int, open_ends: int) -> int:
	if count >= 5:
		return S_FIVE
	match count:
		4:
			if open_ends == 2:
				return S_OPEN_FOUR
			if open_ends == 1:
				return S_FOUR
		3:
			if open_ends == 2:
				return S_OPEN_THREE
			if open_ends == 1:
				return S_THREE
		2:
			if open_ends == 2:
				return S_OPEN_TWO
			if open_ends == 1:
				return S_TWO
		1:
			if open_ends == 2:
				return S_ONE
	return 0
