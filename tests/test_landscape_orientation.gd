extends SceneTree
## Mobile orientation stays landscape while the device may be held in portrait.
## Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_landscape_orientation.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var orientation := int(ProjectSettings.get_setting(
		"display/window/handheld/orientation", -1
	))
	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	var window_width := int(ProjectSettings.get_setting("display/window/size/window_width_override", 0))
	var window_height := int(ProjectSettings.get_setting("display/window/size/window_height_override", 0))
	var passed := true
	passed = _check(orientation == DisplayServer.SCREEN_SENSOR_LANDSCAPE,
		"移动设备使用传感器横屏方向") and passed
	passed = _check(width > height,
		"逻辑画布保持横屏 (%d×%d)" % [width, height]) and passed
	passed = _check(window_width >= 1920 and window_height >= 1080,
		"默认窗口分辨率至少为 1920×1080 (%d×%d)" % [window_width, window_height]) and passed

	var main := load("res://main.tscn").instantiate() as Main
	root.add_child(main)
	await process_frame
	var min_size := main.get_window().min_size
	passed = _check(min_size.x >= 1920 and min_size.y >= 1080,
		"桌面窗口不能缩小到 1920×1080 以下 (%d×%d)" % [min_size.x, min_size.y]) and passed
	main.queue_free()
	quit(0 if passed else 1)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("  ✓ ", description)
	else:
		push_error("  ✗ " + description)
	return condition
