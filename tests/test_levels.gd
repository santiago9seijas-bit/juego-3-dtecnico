extends Node

var failures := 0

func _ready() -> void:
	_check(Game.state == Game.State.MENU, "empieza en MENU")
	_check(Game.unlocked_levels == 1, "solo nivel 1 desbloqueado")

	Game.start_level(1)
	_check(Game.current_level == 1, "nivel 1 activo")
	_check(Game.task_count == 9, "nivel 1 tiene 9 PCs (grid 3x3)")
	_check(Game.current_tasks.size() == 9, "9 tareas generadas")
	_check(Game.time_left == Game.LEVELS[0].time, "tiempo del nivel 1")

	var symptoms := {}
	var doubles := 0
	for task in Game.current_tasks:
		symptoms[task.symptom] = true
		if task.fail not in ["ram", "hdd", "psu", "gpu", "mb", "cpu", "fan"]:
			failures += 1
			printerr("FAIL: falla invalida %s" % task.fail)
		if task.fail2 != "":
			doubles += 1
	_check(symptoms.size() == 9, "9 problemas distintos (aleatorios)")
	_check(doubles >= 1, "al menos un PC con doble falla")

	var variants_ok := true
	for task in Game.current_tasks:
		if task.variant == "":
			variants_ok = false
		if task.fail2 != "" and task.variant2 == "":
			variants_ok = false
	_check(variants_ok, "cada falla lleva su modelo especifico de repuesto")

	Game.mark_repaired(1)
	Game.mark_repaired(2)
	_check(Game.state == Game.State.PLAYING, "reparar PCs no termina la partida")
	_check(Game.score == Game.POINTS_PER_TASK * 2, "puntaje acumulado por reparo")
	_check(Game.time_left > Game.LEVELS[0].time - 1.0, "reparar suma segundos al timer")

	_finish_level()
	_check(Game.state == Game.State.DONE, "el tiempo agotado termina la partida")
	_check(Game.unlocked_levels == 2, "terminar nivel 1 desbloquea nivel 2")

	Game.start_level(2)
	_check(Game.task_count == 9, "nivel 2 tiene 9 PCs")
	_check(Game.current_tasks.size() == 9, "9 tareas generadas")

	_finish_level()
	_check(Game.unlocked_levels == 3, "terminar nivel 2 desbloquea nivel 3")

	Game.start_level(3)
	_check(Game.task_count == 9, "nivel 3 tiene 9 PCs")
	_finish_level()
	_check(Game.unlocked_levels == 3, "nivel 3 no desbloquea mas")

	var t: Dictionary = Game.new_task()
	_check(t.id > 1000, "tarea nueva genera id propio")
	_check(t.fail in ["ram", "hdd", "psu", "gpu", "mb", "cpu", "fan"], "tarea nueva tiene falla valida")

	Game.quit_to_menu()
	_check(Game.state == Game.State.MENU, "quit_to_menu vuelve al menu")

	if failures == 0:
		print("TEST: NIVELES OK")
		get_tree().quit(0)
	else:
		printerr("TEST: %d FALLOS" % failures)
		get_tree().quit(1)

func _finish_level() -> void:
	Game.time_left = 0.0
	Game._process(0.1)

	if failures == 0:
		print("TEST: NIVELES OK")
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