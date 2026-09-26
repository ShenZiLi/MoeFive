extends SceneTree
## 人机入口检查：主页按钮应直接开始高手档人机对局。
## Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_pve_entry.gd

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := load("res://main.tscn").instantiate() as Main
	root.add_child(main)
	await process_frame

	var pve_button: Button
	for candidate in main._layer.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button.text.begins_with("人机对战"):
			pve_button = button
			break
	_check(pve_button != null, "主页人机入口存在")
	if pve_button == null:
		quit(1)
		return

	pve_button.pressed.emit()
	await process_frame
	_check(main.mode == GameConfig.Mode.PVE, "主页人机入口直接开始人机模式")
	_check(main.difficulty == GameConfig.Difficulty.EXPERT, "人机默认难度为高手")
	_check(main._screen == Main.Screen.GAME, "点击人机入口后直接进入对局")
	_check(main.get_node_or_null("MatchView") is MatchView, "高手人机对局场景已创建")
	_check(not _contains_label(main, "选择对手"), "场景树中不再创建选择对手页")

	print("人机入口检查：通过 %d，失败 %d" % [_checks - _failures, _failures])
	main.queue_free()
	quit(1 if _failures > 0 else 0)


func _contains_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _contains_label(child, text):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ ", description)
	else:
		_failures += 1
		push_error("  ✗ " + description)
