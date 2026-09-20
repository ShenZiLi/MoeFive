extends RefCounted
class_name Board
## 棋盘状态机 —— MoeFive 的核心。
##
## 设计约束（需求文档 §3.3）：
## 悔棋必须让棋盘状态**完整回退**，禁止只在 UI 层擦除棋子。
## 本类的全部状态 = cells + history + current + winner + is_draw，
## 因此任意一手都可无损回滚，胜负判定也随之正确回退。

## 四个方向：横 / 竖 / 撇 / 捺
const DIR_X := [1, 0, 1, 1]
const DIR_Y := [0, 1, 1, -1]

var size: int = GameConfig.BOARD_SIZE
var cells := PackedInt32Array()
var history: Array = []        ## Array[Vector2i]，按落子先后
var current: int = GameConfig.BLACK   ## 下一手该谁走
var winner: int = GameConfig.EMPTY    ## 0 = 未分胜负
var winning_line: Array = []          ## 构成五连的坐标
var is_draw: bool = false


func _init(board_size: int = GameConfig.BOARD_SIZE) -> void:
	size = board_size
	reset()


func reset() -> void:
	cells = PackedInt32Array()
	cells.resize(size * size)
	cells.fill(GameConfig.EMPTY)
	history.clear()
	winning_line.clear()
	current = GameConfig.BLACK
	winner = GameConfig.EMPTY
	is_draw = false


# ========== 查询 ==========

func idx(x: int, y: int) -> int:
	return y * size + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < size and y >= 0 and y < size


func get_cell(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return -1
	return cells[idx(x, y)]


func is_empty_point(x: int, y: int) -> bool:
	return get_cell(x, y) == GameConfig.EMPTY


func is_over() -> bool:
	return winner != GameConfig.EMPTY or is_draw


func move_count() -> int:
	return history.size()


func last_move() -> Vector2i:
	if history.is_empty():
		return Vector2i(-1, -1)
	return history[history.size() - 1]


func opponent_of(color: int) -> int:
	return GameConfig.WHITE if color == GameConfig.BLACK else GameConfig.BLACK


# ========== 落子与胜负 ==========

## 落子。成功返回 true；非法（已占用 / 已终局）返回 false 且不改变任何状态。
func place(x: int, y: int) -> bool:
	if is_over():
		return false
	if not is_empty_point(x, y):
		return false

	var color := current
	cells[idx(x, y)] = color
	history.append(Vector2i(x, y))

	var line := find_line(x, y)
	if not line.is_empty():
		winner = color
		winning_line = line
	elif history.size() >= size * size:
		is_draw = true

	current = opponent_of(color)
	return true


## 以 (x, y) 为中心，检查四个方向是否形成五连及以上。
## 返回构成连珠的坐标数组（空数组 = 未成五）。
func find_line(x: int, y: int) -> Array:
	var color := get_cell(x, y)
	if color == GameConfig.EMPTY or color == -1:
		return []

	for i in 4:
		var dx: int = DIR_X[i]
		var dy: int = DIR_Y[i]
		var line: Array = [Vector2i(x, y)]

		var px := x + dx
		var py := y + dy
		while in_bounds(px, py) and get_cell(px, py) == color:
			line.append(Vector2i(px, py))
			px += dx
			py += dy

		px = x - dx
		py = y - dy
		while in_bounds(px, py) and get_cell(px, py) == color:
			line.push_front(Vector2i(px, py))
			px -= dx
			py -= dy

		if line.size() >= 5:
			return line

	return []


# ========== 悔棋（需求 §3.3）==========

func can_undo() -> bool:
	return not history.is_empty()


## 撤一手。返回被撤坐标；无棋可撤时返回 (-1, -1)。
## 同步回退：棋盘 → 行动方 → 胜负/连珠 → 和棋标记。
func undo_one() -> Vector2i:
	if history.is_empty():
		return Vector2i(-1, -1)

	var pos: Vector2i = history.pop_back()
	var color := cells[idx(pos.x, pos.y)]
	cells[idx(pos.x, pos.y)] = GameConfig.EMPTY
	current = color          # 撤销后，轮到刚下这一手的人重新走
	winner = GameConfig.EMPTY
	winning_line.clear()
	is_draw = false
	return pos


## 人机模式：撤一回合（玩家上一手 + AI 应手），回到玩家上次决策前。
## 返回实际撤掉的手数。
func undo_turn_for(player_color: int) -> int:
	if history.is_empty():
		return 0

	var n := 0
	undo_one()   # 先撤掉最后一手（通常是 AI 的应手）
	n += 1
	while not history.is_empty() and current != player_color:
		undo_one()
		n += 1
	return n


# ========== 副本（供 AI 搜索，零副作用）==========

func clone() -> Board:
	var b := Board.new(size)
	b.cells = cells.duplicate()
	b.history = history.duplicate()
	b.current = current
	b.winner = winner
	b.winning_line = winning_line.duplicate()
	b.is_draw = is_draw
	return b


## 空点坐标列表（供 AI 与非法落子提示使用）
func empty_points() -> Array:
	var out: Array = []
	for y in size:
		for x in size:
			if cells[idx(x, y)] == GameConfig.EMPTY:
				out.append(Vector2i(x, y))
	return out
