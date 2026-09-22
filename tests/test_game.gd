extends Node

var failures := 0

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var hud: Node = main.get_node("HUD")
	var minigame: PanelContainer = hud.get_node("Gameplay/Minigame")

	_check(Game.state == Game.State.MENU, "empieza en MENU")

	Game.start_game()
	_check(Game.state == Game.State.PLAYING, "start_game pasa a PLAYING")
	_check(Game.score == 0, "score inicia en 0")
	_check(Game.time_left == Game.LEVELS[0].time, "timer arranca al maximo")

	_check(Game.tutorial_active == false, "el nivel arranca sin explicacion (ya no se muestra)")

	await get_tree().create_timer(0.1).timeout
	_check(Game.time_left < Game.LEVELS[0].time, "el cronometro DESCIENDE")

	Game.pause_game()
	_check(Game.state == Game.State.PAUSED, "pause_game pasa a PAUSED")
	var frozen: float = Game.time_left
	await get_tree().create_timer(0.1).timeout
	_check(Game.time_left == frozen, "el timer se detiene en pausa")
	Game.resume_game()
	_check(Game.state == Game.State.PLAYING, "resume_game vuelve a PLAYING")

	_check(Game.task_count == 3, "nivel 1 tiene 3 PCs")

	var pcs := {
		1: "psu",
		2: "ram",
		3: "hdd",
	}
	for pc_id in pcs:
		var pc: Node = load("res://scenes/pc/pc.tscn").instantiate()
		pc.pc_id = pc_id
		pc.symptom = "sintoma %d" % pc_id
		pc.fail_type = pcs[pc_id]
		main.add_child(pc)
		minigame.setup(pc)
		var slot: RepairSlot = minigame._slot_nodes[pcs[pc_id]]
		# Cargamos el repuesto bueno y lo soltamos al slot: la mochila ya
		# puede tener piezas dañadas de la PC anterior (por eso no se usa [0]).
		_check(Game.pick_part_variant(Game.PART_VARIANTS[pcs[pc_id]][0]), "se toma el repuesto de la estanteria")
		minigame._on_part_dropped(slot, Game.carried_parts.back())
		Game.hud._on_removal_done()

	_check(Game.repaired.size() == 3, "3 PCs reparados")
	_check(Game.score == Game.POINTS_PER_TASK * 3, "puntaje de los 3 PCs")
	_check(Game.state == Game.State.DONE, "reparar todas termina la partida")
	_check(Game.time_left >= Game.LEVELS[0].time - 1.0, "las reparaciones sumaron tiempo")
	_check(Game.damaged_count() == 3, "las 3 piezas salidas quedan marcadas como dañadas en la mochila")

	if failures == 0:
		print("TEST: PARTIDA OK")
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
