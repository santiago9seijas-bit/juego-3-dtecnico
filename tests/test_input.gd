extends Node

var failures := 0

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Game.start_game()
	Game.hud._end_tutorial()
	await get_tree().physics_frame

	var player: Node3D = main.get_node("Player")
	var camera: Node3D = player.get_node("Camera3D")
	var yaw0: float = player.rotation.y
	var pitch0: float = camera.rotation.x

	for i in 10:
		var ev := InputEventMouseMotion.new()
		ev.relative = Vector2(60, 25)
		ev.position = get_viewport().get_visible_rect().size / 2.0
		get_viewport().push_input(ev)
		await get_tree().process_frame

	var moved := player.rotation.y != yaw0 or camera.rotation.x != pitch0
	_check(moved, "el mouse rota la camara al jugar")

	if failures == 0:
		print("TEST: INPUT MOUSE OK")
		get_tree().quit(0)
	else:
		printerr("TEST: %d FALLOS" % failures)
		get_tree().quit(1)

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		failures += 1
		printerr("FAIL: ", name)