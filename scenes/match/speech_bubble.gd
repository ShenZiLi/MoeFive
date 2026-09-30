extends Control
class_name MatchSpeechBubble

@onready var _text: Label = $Text
@onready var _timer: Timer = $DismissTimer

var _persistent: String = ""
func _ready() -> void:
	_timer.timeout.connect(_on_timeout)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.text = ""
	visible = false


func show_message(message: String, persistent := false) -> void:
	_timer.stop()
	_text.text = message
	visible = not message.is_empty()
	if persistent:
		_persistent = message
	elif not message.is_empty():
		_persistent = ""
		_timer.start(2.5)


func show_temporary(message: String, fallback: String) -> void:
	show_message(message)
	_persistent = fallback


func set_persistent(message: String) -> void:
	_persistent = message
	show_message(message, true)


func _on_timeout() -> void:
	if _persistent.is_empty():
		visible = false
	else:
		_text.text = _persistent
