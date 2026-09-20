extends SceneTree
## 冒烟测试：主场景能否正常加载、实例化、空跑若干帧。
##
## 运行：
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_smoke.gd
##
## 用于捕获 GDScript 解析错误、节点构建异常、主题/字体加载失败等
## 无法在纯逻辑测试中暴露的问题。

var _frames := 0
var _failed := false


func _initialize() -> void:
	print("")
	print("========== MoeFive 冒烟测试 ==========")

	if not ResourceLoader.exists("res://main.tscn"):
		print("  ✗ 找不到 res://main.tscn")
		_failed = true
		quit(1)
		return

	var ps: PackedScene = load("res://main.tscn")
	if ps == null:
		print("  ✗ 主场景加载失败")
		_failed = true
		quit(1)
		return
	print("  ✓ 主场景加载成功")

	var node: Node = ps.instantiate()
	if node == null:
		print("  ✗ 主场景实例化失败")
		_failed = true
		quit(1)
		return
	print("  ✓ 主场景实例化成功")

	root.add_child(node)
	print("  ✓ 加入场景树")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false

	print("  ✓ 空跑 %d 帧无异常" % _frames)
	var main_node := root.get_child(root.get_child_count() - 1)
	print("  ✓ 根节点：%s（子节点 %d 个）" % [main_node.name, main_node.get_child_count()])
	print("--------------------------------------")
	if _failed:
		print("结果：失败")
	else:
		print("结果：通过")
	print("======================================")
	print("")
	quit(1 if _failed else 0)
	return true
