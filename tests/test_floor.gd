extends Node

var failures := 0

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)

	Game.start_game()

	var player: Node3D = main.get_node("Player")
	var initial_y: float = player.global_position.y

	for i in 200:
		await get_tree().physics_frame

	var final_y: float = player.global_position.y
	print("Y inicial: %.2f  Y final: %.2f" % [initial_y, final_y])

	_check(final_y < initial_y, "el player cayo (habia gravedad)")
	_check(final_y > -1.0, "NO se cayo al vacio (piso solido)")
	_check(final_y < 3.0, "NO quedo flotando")

	if failures == 0:
		print("TEST: PISO OK")
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