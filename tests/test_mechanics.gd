extends Node

var failures := 0

func _ready() -> void:
	var hud_scene: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud_scene)
	var minigame: PanelContainer = hud_scene.get_node("Gameplay/Minigame")

	var pc_scene: PackedScene = load("res://scenes/pc/pc.tscn")
	var pc: Node = pc_scene.instantiate()
	pc.pc_id = 99
	pc.symptom = "test symptom"
	pc.fail_type = "ram"
	hud_scene.add_child(pc)

	minigame.setup(pc)
	var ram_slot: RepairSlot = minigame._slot_nodes["ram"]

	_check(minigame.visible == true, "minijuego visible tras setup")
	_check(ram_slot.has_broken_part() == true, "slot RAM tiene pieza dañada")
	_check(ram_slot.revealed == false, "la pieza no muestra pista hasta examinar")

	minigame._on_examine_requested(ram_slot)
	_check(ram_slot.revealed == true, "examinar revela el estado del slot")

	Game.score = 100
	var time_before: float = Game.time_left
	var score_before: int = Game.score
	Game.carried_parts.append({"name": "Disco SSD 1TB", "type": "hdd", "good": true})
	minigame._on_part_dropped(ram_slot, Game.carried_parts[0])
	_check(Game.hud.removal_panel.visible == true, "instalar pieza INCORRECTA tambien abre el mini-juego en reversa")
	Game.hud._on_removal_done()
	_check(99 not in Game.repaired, "arrastrar repuesto de OTRO tipo NO completa")
	_check(Game.carried_parts.size() == 0, "la pieza equivocada se consume al instalarla")
	_check(Game.time_left < time_before and Game.score < score_before, "equivocarse resta tiempo y puntos")

	time_before = Game.time_left
	score_before = Game.score
	Game.carried_parts.append(Game.PART_VARIANTS["ram"][1])
	minigame._on_part_dropped(ram_slot, Game.carried_parts[0])
	Game.hud._on_removal_done()
	_check(99 not in Game.repaired, "modelo equivocado (DDR4 vs DDR3) NO completa")
	_check(Game.carried_parts.size() == 0, "el modelo equivocado se consume")
	_check(Game.time_left < time_before and Game.score < score_before, "equivocarse de modelo tambien penaliza")

	time_before = Game.time_left
	score_before = Game.score
	Game.carried_parts.append(Game.PART_VARIANTS["ram"][0])
	minigame._on_part_dropped(ram_slot, Game.carried_parts[0])
	_check(Game.hud.removal_panel.visible == true, "instalar correcto abre el mini-juego en reversa")
	Game.hud._on_removal_done()
	_check(99 in Game.repaired, "arrastrar el modelo correcto SI cuenta")
	_check(Game.score > score_before, "instalar correcto suma puntos")
	_check(Game.repaired.count(99) == 1, "no duplica en el contador")

	minigame._on_part_dropped(ram_slot, Game.PART_VARIANTS["ram"][0])
	_check(Game.repaired.count(99) == 1, "post-exito no suma mas")

	Game.carried_parts.clear()
	_check(Game.pick_part_variant(Game.PART_VARIANTS["gpu"][0]), "recoger pieza en la estanteria carga el inventario")
	_check(Game.pick_part_variant(Game.PART_VARIANTS["mb"][1]), "cabe una segunda pieza")
	_check(Game.pick_part_variant(Game.PART_VARIANTS["psu"][2]), "cabe una tercera pieza")
	_check(Game.pick_part_variant(Game.PART_VARIANTS["ram"][0]) == false, "el inventario maximo es 3")
	_check(Game.carried_parts.size() == 3, "quedan 3 piezas cargadas")

	Game.carried_parts.clear()
	var pc2: Node = pc_scene.instantiate()
	pc2.pc_id = 98
	pc2.symptom = "doble falla"
	pc2.fail_type = "ram"
	pc2.fail_type2 = "psu"
	hud_scene.add_child(pc2)
	minigame.setup(pc2)
	var ram_slot2: RepairSlot = minigame._slot_nodes["ram"]
	var psu_slot: RepairSlot = minigame._slot_nodes["psu"]
	_check(ram_slot2.has_broken_part() and psu_slot.has_broken_part(), "PC doble: 2 slots dañados")

	var hdd_slot: RepairSlot = minigame._slot_nodes["hdd"]
	_check(minigame._examines_left == 4, "empieza cada PC con 4 examinaciones")
	minigame._on_examine_requested(psu_slot)
	var left_after: int = minigame._examines_left
	minigame._on_examine_requested(psu_slot)
	_check(minigame._examines_left == left_after, "reexaminar un slot ya visto NO gasta examinaciones")
	for slot_name in ["gpu", "mb", "cpu"]:
		minigame._on_examine_requested(minigame._slot_nodes[slot_name])
	_check(minigame._examines_left == 0, "tras 4 examinaciones el contador llega a 0")
	minigame._on_examine_requested(minigame._slot_nodes["cpu"])
	_check(minigame._examines_left == 0, "no se puede examinar mas de 4 veces")

	minigame._on_remove_requested(hdd_slot)
	_check(Game.hud.removal_panel.visible == true, "se puede sacar una pieza BUENA")
	Game.hud._on_removal_done()
	_check(hdd_slot.is_empty(), "al completar el mini-juego se retira la pieza buena")
	Game.carried_parts.append(Game.PART_VARIANTS["hdd"][2])
	minigame._on_part_dropped(hdd_slot, Game.carried_parts[0])
	Game.hud._on_removal_done()
	_check(hdd_slot.part.get("name", "") == Game.PART_VARIANTS["hdd"][2].name, "se puede PONER una pieza en un slot que no estaba dañado")
	_check(Game.repaired.count(98) == 0, "poner pieza en slot sano NO suma reparación")

	Game.carried_parts.append(Game.PART_VARIANTS["ram"][0])
	minigame._on_part_dropped(ram_slot2, Game.carried_parts[0])
	Game.hud._on_removal_done()
	_check(98 not in Game.repaired, "doble falla: arreglar 1 solo NO completa")
	_check(minigame._examines_left == 4, "las examinaciones se recargan al reparar bien una pieza")

	minigame._close()
	_check(minigame.visible == false, "cerrar el menú al salir a buscar pieza")
	minigame.setup(pc2)
	_check(ram_slot2.part.get("good", false) == true, "al volver se conserva la RAM ya cambiada")
	_check(psu_slot.has_broken_part() == true, "sigue faltando el disco/Fuente por arreglar")
	_check(ram_slot2.revealed == false, "lo no examinado sigue oculto")

	time_before = Game.time_left
	score_before = Game.score
	Game.carried_parts.append(Game.PART_VARIANTS["psu"][1])
	minigame._on_part_dropped(psu_slot, Game.carried_parts[0])
	_check(Game.hud.removal_panel.visible == true, "equivocarse tambien pasa por el mini-juego en reversa")
	Game.hud._on_removal_done()
	_check(98 not in Game.repaired, "equivocarse de modelo NO completa la tarea")
	_check(Game.time_left < time_before, "equivocarse resta tiempo")
	_check(Game.score < score_before, "equivocarse resta puntos")
	_check(psu_slot.part.get("name", "") != Game.PART_VARIANTS["psu"][0].name, "queda instalada la pieza equivocada")
	_check(Game.hud.removal_panel.visible == false, "el mini-juego de desarme inicia oculto")
	minigame._on_remove_requested(psu_slot)
	_check(Game.hud.removal_panel.visible == true, "sacarla abre el mini-juego de desarme")
	_check(psu_slot.is_empty() == false, "la pieza no se retira hasta terminar el mini-juego")
	Game.hud._on_removal_done()
	_check(psu_slot.is_empty(), "al completar el mini-juego se retira la pieza")

	Game.carried_parts.append(Game.PART_VARIANTS["psu"][0])
	minigame._on_part_dropped(psu_slot, Game.carried_parts[0])
	Game.hud._on_removal_done()
	_check(98 in Game.repaired, "corregir con el modelo correcto SI completa la tarea")
	_check(Game.repaired.count(98) == 1, "no duplica en el contador")

	var panel: Node = Game.hud.removal_panel
	panel.open("mb", false)
	_check(panel._driver_buttons.size() == 2, "el selector tiene 2 destornilladores")
	_check(panel._screwdriver == "flat", "arranca con destornillador de llana")
	_check(panel._screw_buttons.size() == panel._screw_total, "se generan todos los tornillos")
	panel._set_screwdriver("phillips")
	_check(panel._screwdriver == "phillips", "cambiar a destornillador de cruz funciona")
	var flat_screw: Node = null
	for b in panel._screw_buttons:
		if b.head_type == "flat":
			flat_screw = b
			break
	_check(flat_screw != null, "hay al menos un tornillo de cabeza plana")
	if flat_screw:
		var antes: int = panel._screws_removed
		flat_screw.toggled.emit(true)
		_check(panel._screws_removed == antes, "un tornillo plano NO sale con destornillador de cruz")
		_check(flat_screw.button_pressed == false, "el tornillo rechazado queda intacto")
		panel._set_screwdriver("flat")
		flat_screw.toggled.emit(true)
		_check(panel._screws_removed == antes + 1, "un tornillo plano SI sale con destornillador de llana")
	for b in panel._screw_buttons:
		if flat_screw and b == flat_screw:
			continue
		panel._set_screwdriver(b.head_type)
		if not b.button_pressed:
			b.toggled.emit(true)
	_check(panel._screws_removed == panel._screw_total, "todos los tornillos salen con su destornillador correcto")
	Game.hud.removal_panel.visible = false

	panel.open("hdd", false)
	var sc: Node = panel._slide_component
	_check(sc != null, "el disco usa el minijuego de deslizar a la derecha")
	var slid := [false]
	panel.done.connect(func() -> void: slid[0] = true)
	_check(sc._delta_x <= 1.0, "el deslizador arranca pegado a la izquierda")
	sc._on_drag(Vector2(sc._max_x(), 0))
	sc._on_release()
	_check(slid[0], "deslizar todo hacia la derecha y soltar completa el desarme")
	panel.open("hdd", true)
	var sc2: Node = panel._slide_component
	_check(absf(sc2._delta_x - sc2._max_x()) <= 1.0, "en reversa arranca pegado a la derecha")
	var slid2 := [false]
	panel.done.connect(func() -> void: slid2[0] = true)
	sc2._on_drag(Vector2(-sc2._max_x(), 0))
	sc2._on_release()
	_check(slid2[0], "en reversa deslizar hacia la izquierda completa la instalacion")
	Game.hud.removal_panel.visible = false

	panel.open("hdd", false)
	var scm: Node = panel._slide_component
	scm.size = Vector2(scm.WIDTH, 90)
	var done_mouse := [false]
	panel.done.connect(func() -> void: done_mouse[0] = true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(60, 45)
	scm._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(400, 45)
	scm._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	scm._gui_input(release)
	_check(done_mouse[0], "deslizar con el raton (click-arrastra-suelta) completa el minijuego")
	Game.hud.removal_panel.visible = false

	panel.open("psu", false)
	_check(panel._screw_buttons.size() > 0, "PSU: primero se desatornillan los tornillos")
	for b in panel._screw_buttons:
		panel._set_screwdriver(b.head_type)
		if not b.button_pressed:
			b.toggled.emit(true)
	_check(panel._slide_component != null, "PSU: despues de los tornillos toca deslizar a la derecha")
	var psu_done := [false]
	panel.done.connect(func() -> void: psu_done[0] = true)
	var sc3: Node = panel._slide_component
	sc3._on_drag(Vector2(sc3._max_x(), 0))
	sc3._on_release()
	_check(psu_done[0], "PSU: deslizar a la derecha completa el desarme")

	panel.open("psu", true)
	_check(panel._slide_component != null, "PSU reversa: primero se desliza a la izquierda")
	var sc4: Node = panel._slide_component
	sc4._on_drag(Vector2(-sc4._max_x(), 0))
	sc4._on_release()
	_check(panel._screw_buttons.size() > 0, "PSU reversa: luego vienen los tornillos")
	var psu_done2 := [false]
	panel.done.connect(func() -> void: psu_done2[0] = true)
	for b in panel._screw_buttons:
		panel._set_screwdriver(b.head_type)
		if b.button_pressed:
			b.set_pressed_no_signal(false)
			b.toggled.emit(false)
	_check(psu_done2[0], "PSU reversa: atornillar todo completa la instalacion")
	Game.hud.removal_panel.visible = false

	minigame.close_button.pressed.emit()
	_check(minigame.visible == false, "boton cerrar sale del minijuego")

	if failures == 0:
		print("TEST: TODOS LOS CHECKS OK")
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