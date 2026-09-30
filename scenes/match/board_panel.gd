@tool
extends Control
class_name MatchBoardPanel

var reference_mode := false
var photo_mode := false


func set_reference_mode(value: bool) -> void:
	reference_mode = value
	if is_node_ready():
		_layout_paws()


func set_photo_mode(value: bool) -> void:
	photo_mode = value
	if is_node_ready():
		_layout_paws()


func _ready() -> void:
	resized.connect(_layout_paws)
	_layout_paws()


func _layout_paws() -> void:
	var reference_layout := reference_mode or (size.x > 0.0 and size.y > size.x * 1.05)
	get_node("ReferenceBoard").visible = reference_mode and not photo_mode
	get_node("WoodSurface").visible = not reference_mode and not photo_mode
	get_node("WoodFrame").visible = not reference_mode and not photo_mode
	get_node("CornerPaws").visible = not reference_mode and not photo_mode
	var surface := get_node_or_null("WoodSurface") as TextureRect
	if surface != null:
		var surface_inset := minf(size.x, size.y) * 0.045
		surface.set_anchors_preset(Control.PRESET_TOP_LEFT)
		surface.position = Vector2.ONE * surface_inset
		surface.size = size - Vector2.ONE * surface_inset * 2.0
	var inset := minf(size.x, size.y) * (0.01 if not reference_layout else 0.018)
	var extent := minf(size.x, size.y) * (0.06 if not reference_layout else 0.075)
	var square_top := (size.y - minf(size.x, size.y)) * 0.5
	for name in ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]:
		var paw := get_node_or_null("CornerPaws/" + name) as TextureRect
		if paw == null:
			continue
		paw.set_anchors_preset(Control.PRESET_TOP_LEFT)
		paw.size = Vector2.ONE * extent
		paw.position = Vector2(
			size.x - extent - inset if name.ends_with("Right") else inset,
			square_top + minf(size.x, size.y) - extent - inset
			if name.begins_with("Bottom") else square_top + inset
		)
