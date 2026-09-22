extends Node

var failures := 0

func _ready() -> void:
	_check(Game.state == Game.State.MENU, "empieza en MENU")
	_check(Game.unlocked_levels == 1, "solo la seccion 1 esta habilitada")
	_check(Game.LEVELS.size() == 6, "la seccion 1 se divide en 6 niveles")

	# Nivel 1: sala pequena, piezas basicas, 3 PCs, sin mecánicas técnicas.
	Game.start_level(1)
	_check(Game.current_level == 1, "nivel 1 activo")
	_check(Game.task_count == 3, "nivel 1 tiene 3 PCs")
	_check(Game.current_tasks.size() == 3, "3 tareas generadas")
	_check(Game.time_left == Game.LEVELS[0].time, "tiempo del nivel 1")
	_check(Game.uses_small_room(), "nivel 1 usa la sala pequena")
	_check(not Game.level_uses_volt() and not Game.level_uses_solder(), "nivel 1 sin voltimetro ni soldadura")
	_check(not Game.uses_tech("mb") and not Game.uses_tech("psu"), "nivel 1 no usa la cadena tecnica")

	var symptoms := {}
	var doubles := 0
	for task in Game.current_tasks:
		symptoms[task.symptom] = true
		if task.fail not in ["ram", "hdd", "psu", "gpu", "mb", "cpu", "fan"]:
			failures += 1
			printerr("FAIL: falla invalida %s" % task.fail)
		if task.fail not in Game.level_parts():
			failures += 1
			printerr("FAIL: el nivel 1 no deberia tener la pieza %s" % task.fail)
		if task.fail2 != "":
			doubles += 1
	_check(symptoms.size() == 3, "3 problemas distintos (aleatorios)")
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

	_check_all_levels()

	# Mochila con piezas dañadas + papelera.
	_check_trash()

	var t: Dictionary = Game.new_task()
	_check(t.id > 1000, "tarea nueva genera id propio")
	_check(t.fail in Game.level_parts(), "tarea nueva solo usa piezas del nivel")

	_check_tutorial()

	Game.quit_to_menu()
	_check(Game.state == Game.State.MENU, "quit_to_menu vuelve al menu")

	if failures == 0:
		print("TEST: NIVELES OK")
		get_tree().quit(0)
	else:
		printerr("TEST: %d FALLOS" % failures)
		get_tree().quit(1)

# Cada nivel tiene sus PCs, sus piezas y sus mecánicas; la sección 2 y la
# 3 (que son otras secciones del menú) siguen bloqueadas.
func _check_all_levels() -> void:
	var expect_pc := [3, 3, 4, 4, 5, 5]
	var rooms := ["small", "small", "small", "small", "medium", "medium"]
	var with_tech := [false, false, true, true, true, true]
	for i in Game.LEVELS.size():
		var idx := i + 1
		Game.start_level(idx)
		_check(Game.task_count == expect_pc[i], "nivel %d tiene %d PCs" % [idx, expect_pc[i]])
		_check(Game.current_tasks.size() == expect_pc[i], "nivel %d genera sus tareas" % idx)
		_check(Game.time_left == Game.LEVELS[i].time, "nivel %d usa su propio cronometro" % idx)
		_check(Game.uses_small_room() == (rooms[i] == "small"), "nivel %d sala %s" % [idx, rooms[i]])
		_check(Game.uses_medium_room() == (rooms[i] == "medium"), "nivel %d sala mediana %s" % [idx, "si" if rooms[i] == "medium" else "no"])
		_check(Game.uses_closed_room(), "nivel %d se juega en sala cerrada" % idx)
		_check(Game.level_uses_volt() == with_tech[i] and Game.level_uses_solder() == with_tech[i], "nivel %d mecánicas %s" % [idx, "tecnicas" if with_tech[i] else "basicas"])
		_check(Game.uses_tech("mb") == with_tech[i] and Game.uses_tech("psu") == with_tech[i], "nivel %d cadena de soldadura/voltimetro %s" % [idx, "activa" if with_tech[i] else "inactiva"])
		_check(not Game.uses_tech("ram"), "la cadena tecnica solo aplica a placa y fuente")
		_check(Game.level_has_trash(), "en el nivel hay papelera para las piezas danadas")
		var info := Game.level_info_text(idx)
		_check(info.contains("QUÉ HAY EN ESTE NIVEL") and info.contains("CONTROLES"), "ficha del nivel %d con sintaxis y espacio para imagen" % idx)
		var parts: Array = Game.level_parts()
		var seen := {}
		var faults_ok := true
		for task in Game.current_tasks:
			seen[task.symptom] = true
			if not task.has("fault") or not task.has("fix"):
				faults_ok = false
			if task.get("fault", "swap") not in ["volt", "burn", "swap"]:
				faults_ok = false
			if task.get("fix", "swap") not in ["solder", "swap"]:
				faults_ok = false
			if task.fail not in parts:
				failures += 1
				printerr("FAIL: nivel %d con pieza fuera de su lista: %s" % [idx, task.fail])
			if task.get("fail2", "") != "" and task.fail2 not in parts:
				failures += 1
				printerr("FAIL: nivel %d con 2da pieza fuera de su lista: %s" % [idx, task.fail2])
		_check(seen.size() >= 2, "nivel %d trae problemas variados" % idx)
		_check(faults_ok, "nivel %d: cada falla dice su tipo de daño y su arreglo" % idx)
		# Sin voltímetro/cautín (niveles 1-2) no aparecen daños de voltaje
		# ni reparaciones soldando.
		if not with_tech[i]:
			for task in Game.current_tasks:
				if task.fault != "swap" or task.fix != "swap":
					failures += 1
					printerr("FAIL: nivel %d con fallos de mecanica que no tiene" % idx)
		else:
			var kinds := {}
			for task in Game.current_tasks:
				kinds[task.fault] = true
			_check(kinds.size() >= 1, "nivel %d con tipos de daño asignados" % idx)
		if idx in [1, 2]:
			_check(parts == Game.BASIC_PARTS, "nivel %d: solo piezas basicas (sin cpu ni fan)" % idx)
		elif idx in [3, 4]:
			_check(parts == Game.BOARD_PARTS, "nivel %d: solo placas y fuentes" % idx)
			for task in Game.current_tasks:
				if task.fail not in ["psu", "mb"]:
					failures += 1
					printerr("FAIL: nivel %d deberia ser solo placa/fuente" % idx)
		else:
			_check(parts == Game.ALL_PARTS, "nivel %d: todas las piezas" % idx)

	# Terminar un nivel no abre otras secciones del menú.
	_finish_level()
	_check(Game.state == Game.State.DONE, "el tiempo agotado termina la partida")
	_check(Game.unlocked_levels == 1, "los niveles no desbloquean otras secciones")

# Mochila: las piezas dañadas se marcan y la papelera las bota.
func _check_trash() -> void:
	Game.start_level(1)
	Game.carried_parts.clear()
	_check(Game.add_damaged({"name": "RAM quemada", "type": "ram"}), "una pieza danada entra en la mochila")
	_check(Game.damaged_count() == 1, "el inventario cuenta la pieza danada")
	_check(Game.pick_part_variant(Game.PART_VARIANTS["ram"][0]), "cabe un repuesto bueno")
	_check(Game.pick_part_variant(Game.PART_VARIANTS["hdd"][0]), "cabe un segundo repuesto")
	_check(not Game.pick_part_variant(Game.PART_VARIANTS["gpu"][0]), "la mochila admite solo 3 piezas")
	_check(Game.trash_damaged() == 1, "la papelera bota la pieza danada")
	_check(Game.damaged_count() == 0, "ya no quedan piezas danadas")
	_check(Game.carried_parts.size() == 2, "la papelera NO bota los repuestos buenos")
	Game.carried_parts.clear()
	Game.tutorial_mode = true
	_check(not Game.add_damaged({"name": "RAM quemada", "type": "ram"}), "en el tutorial no hay piezas danadas")
	Game.tutorial_mode = false

func _check_tutorial() -> void:
	Game.start_tutorial("ram")
	_check(Game.tutorial_mode, "el tutorial activa el modo sin cronometro")
	_check(Game.state == Game.State.PLAYING, "el tutorial arranca en PLAYING (se puede mover e interactuar)")
	_check(Game.task_count == 1 and Game.current_tasks.size() == 1, "el tutorial tiene UNA sola PC")
	_check(Game.current_tasks[0].fail == "ram", "el tutorial usa la pieza elegida")
	_check(Game.current_tasks[0].fail2 == "", "el tutorial es de falla unica")
	_check(Game.current_tasks[0].variant != "", "el tutorial trae su modelo de repuesto")
	_check(Game.PART_INFO.has("ram") and Game.PART_INFO["ram"].use != "", "cada pieza tiene su ficha de uso")

	# Tutoriales de mecánica: voltímetro, cautín y papelera.
	for mech in Game.MECHANIC_TUTORIALS:
		Game.start_tutorial(mech)
		_check(Game.tutorial_mechanic == mech, "tutorial de mecanica %s activo" % mech)
		_check(Game.current_tasks[0].fail == Game.MECHANIC_PART[mech], "tutorial %s usa su pieza base" % mech)
		_check(Game.PART_TITLES.has(mech) and Game.PART_INFO.has(mech), "tutorial %s tiene titulo y ficha" % mech)
		_check(Game.part_long_text(mech).contains("EN EL TUTORIAL"), "ficha del tutorial %s explicada" % mech)
		if mech == "volt":
			_check(Game.level_uses_volt() and Game.level_uses_solder(), "tutorial voltimetro activa voltimetro y cautin")
			_check(Game.uses_tech("mb"), "tutorial voltimetro usa la cadena de soldadura/voltimetro")
			_check(Game.current_tasks[0].fault == "volt", "tutorial voltimetro enseña el daño de voltaje")
		elif mech == "solder":
			_check(Game.current_tasks[0].fault == "burn" and Game.current_tasks[0].fix == "solder", "tutorial cautin se arregla soldando")
		else:
			_check(Game.level_has_trash(), "tutorial papelera tiene papelera")
			_check(Game.add_damaged({"name": "RAM quemada", "type": "ram"}), "tutorial papelera guarda la pieza danada")
			_check(Game.damaged_count() == 1, "tutorial papelera cuenta la pieza danada")
			Game.trash_damaged()
		_check(Game.tutorial_station_part() != mech, "tutorial %s usa una pieza real en la estanteria" % mech)
	Game.finish_tutorial()
	Game.start_tutorial("ram")
	_check(Game.tutorial_mechanic == "", "un tutorial de pieza no activa mecanicas")

	var clock: float = Game.time_left
	Game._process(0.5)
	_check(Game.time_left == clock, "EN TUTORIAL NO BAJA EL CRONOMETRO")

	var pc_id: int = Game.current_tasks[0].id
	Game.mark_repaired(pc_id)
	_check(Game.state == Game.State.PLAYING, "completar el tutorial NO termina la partida")
	_check(pc_id not in Game.repaired, "el tutorial deja la PC lista para repetir")

	Game.finish_tutorial()
	_check(Game.tutorial_mode == false, "finish_tutorial apaga el modo tutorial")
	_check(Game.state == Game.State.MENU, "finish_tutorial vuelve al menu")
	Game.start_level(1)

func _finish_level() -> void:
	Game.time_left = 0.0
	Game._process(0.1)

func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		failures += 1
		printerr("FAIL: ", name)
