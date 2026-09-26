@tool
extends Control
class_name MatchPlayerPanel

@export var is_black: bool = true

@onready var _card: TextureRect = $Card
@onready var _pet: TextureRect = $Pet
@onready var _name: Label = $Name
@onready var _count: Label = $Count
@onready var _stone: TextureRect = $Stone
@onready var _bubble: MatchSpeechBubble = $SpeechBubble

var _active: bool = false
var _compact: bool = false
var _thinking: bool = false
var _motion: Tween
var _last_quote: String = ""


func _ready() -> void:
	for node in [_card, _pet, _name, _count, _stone]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 内置手写字体的 0 接近方框；计数使用清晰的数字字形。
	_count.add_theme_font_override("font", ThemeDB.fallback_font)
	resized.connect(_layout)
	_layout()


func set_compact(value: bool) -> void:
	_compact = value
	if is_node_ready():
		_layout()


func apply(name_text: String, count: int, active: bool, thinking: bool) -> void:
	_name.text = name_text
	_count.text = "× %d" % count
	_thinking = thinking
	if _active != active:
		_active = active
		if _motion and _motion.is_running():
			_motion.kill()
		_motion = create_tween()
		_motion.tween_property(_pet, "position:y", _pet.position.y - (4.0 if active else -4.0), 0.20)
	modulate = Color.WHITE if active else Color(0.94, 0.94, 0.94)
	if thinking:
		if not _compact:
			_bubble.set_persistent("让我想想…")


func set_quote(message: String) -> void:
	_last_quote = message
	if not _thinking and not _compact:
		_bubble.show_message(message)


func show_feedback(message: String) -> void:
	if not _compact:
		_bubble.show_temporary(message, _last_quote)


func _layout() -> void:
	if _compact:
		_card.position = Vector2(88, 8)
		_card.size = Vector2(maxf(220, size.x - 94), 84)
		_pet.position = Vector2.ZERO
		_pet.size = Vector2(120, 100)
		_name.position = Vector2(115, 17)
		_name.size = Vector2(size.x - 145, 30)
		_count.position = Vector2(160, 49)
		_count.size = Vector2(size.x - 180, 28)
		_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_stone.position = Vector2(115, 49)
		_stone.size = Vector2(30, 30)
		_bubble.visible = false
	else:
		_card.position = Vector2(0, 119 if is_black else 150)
		_card.size = Vector2(size.x, 260 if is_black else 241)
		_pet.position = Vector2(-30, -40)
		_pet.size = Vector2(size.x + 60, 250)
		_name.position = Vector2(18, 190 if is_black else 211)
		_name.size = Vector2(size.x - 36, 37)
		_count.position = Vector2(136 if is_black else 152, 250 if is_black else 262)
		_count.size = Vector2(size.x - 110, 35)
		_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_stone.position = Vector2(67 if is_black else 64, 234 if is_black else 234)
		_stone.size = Vector2(60 if is_black else 80, 60 if is_black else 80)
		var bubble_width := 120.0
		_bubble.position = Vector2((size.x - bubble_width) * 0.5 + (42 if is_black else 0), 318 if is_black else 348)
		_bubble.size = Vector2(bubble_width, 58)
