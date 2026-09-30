extends HBoxContainer
class_name MatchActionToolbar

signal undo_requested
signal surrender_requested
signal return_requested

@onready var undo_button: TextureButton = $UndoButton
@onready var surrender_button: TextureButton = $SurrenderButton
@onready var return_button: TextureButton = $ReturnButton
var _motions: Dictionary = {}


func set_compact(value: bool) -> void:
	var extent := 72.0 if value else 44.0
	custom_minimum_size = Vector2(232, 72) if value else Vector2(148, 48)
	add_theme_constant_override("separation", 8 if value else 4)
	for button in [undo_button, surrender_button, return_button]:
		button.custom_minimum_size = Vector2.ONE * extent


func set_photo() -> void:
	custom_minimum_size = Vector2(290, 94)
	add_theme_constant_override("separation", 4)
	for button in [undo_button, surrender_button, return_button]:
		button.custom_minimum_size = Vector2.ONE * 94.0


func _ready() -> void:
	undo_button.pressed.connect(func(): undo_requested.emit())
	surrender_button.pressed.connect(func(): surrender_requested.emit())
	return_button.pressed.connect(func(): return_requested.emit())
	for button in [undo_button, surrender_button, return_button]:
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("#fff0ca")
		focus.set_border_width_all(3)
		focus.set_corner_radius_all(36)
		button.add_theme_stylebox_override("focus", focus)
		button.mouse_entered.connect(_on_hover.bind(button))
		button.mouse_exited.connect(_on_release.bind(button))
		button.button_down.connect(_on_down.bind(button))
		button.button_up.connect(_on_release.bind(button))
	set_compact(false)


func set_undo_available(value: bool) -> void:
	undo_button.disabled = not value
	undo_button.modulate = Color.WHITE if value else Color(0.55, 0.55, 0.55, 0.8)


func _on_hover(button: TextureButton) -> void:
	if not button.disabled:
		_animate(button, Vector2(1.04, 1.04))


func _on_down(button: TextureButton) -> void:
	_animate(button, Vector2(0.94, 0.94))


func _on_release(button: TextureButton) -> void:
	_animate(button, Vector2.ONE)


func _animate(button: TextureButton, target: Vector2) -> void:
	var previous: Tween = _motions.get(button)
	if previous and previous.is_running():
		previous.kill()
	var tween := create_tween()
	_motions[button] = tween
	tween.tween_property(button, "scale", target, 0.12)
