extends RefCounted
class_name MatchViewState

var player_two_name: String = "玩家二"
var black_count: int = 0
var white_count: int = 0
var active_side: int = GameConfig.BLACK
var thinking: bool = false
var finished: bool = false
var can_undo: bool = false
var status: String = ""
var quote: String = ""
