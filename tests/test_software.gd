extends Node

# Verificación del mundo de SOFTWARE (sección 2):
# el único nivel con sus SIETE PCs y sus siete minijuegos (descargas,
# controladores, sistema operativo, virus, procesos, cambiar de sistema
# y anuncios), el pendrive, la ficha con los pasos 1-2-3 apilados, la
# sala construida por código y los tutoriales de cada minijuego.

const EXPECTED := ["download", "drivers", "os_install", "virus", "processes", "os_swap", "ads"]

var failures := 0

func _ready() -> void:
	_seccion_y_nivel()
	_ficha_y_pendrive()
	await _minijuegos()
	_tutoriales()
	await _menu()
	await _sala()
	await _regresion()
	_seccion_1_intacta()
	Game.hud = null
	print("test_software: %d comprobaciones fallidas" % failures)
	get_tree().quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------
# Sección, nivel y tareas (todo síncrono: el cronómetro no avanza)
# ------------------------------------------------------------------
func _seccion_y_nivel() -> void:
	_check(Game.unlocked_levels == 2, "la seccion de software esta habilitada")
	_check(Game.SOFTWARE_LEVELS.size() == 1, "el mundo de software trae UN solo nivel")
	_check(Game.SOFTWARE_TUTORIALS.size() == 7, "y SIETE tutoriales propios")

	Game.start_level(1, Game.SECTION_SOFTWARE)
	_check(Game.current_section == 2, "arranca en la seccion 2")
	_check(Game.current_level == 1, "nivel 1 de la seccion 2")
	_check(Game.task_count == 7, "el nivel tiene LAS SIETE PCs")
	_check(Game.current_tasks.size() == 7, "7 tareas generadas")
	_check(Game.time_left == Game.SOFTWARE_LEVELS[0].time, "cronometro del mundo de software")
	_check(Game.uses_software_room(), "usa la sala de software")
	_check(not Game.uses_small_room() and not Game.uses_medium_room(), "no confunde la sala con la de hardware")
	_check(Game.uses_closed_room(), "tambien es una sala cerrada")
	_check(Game.level_parts().is_empty(), "sin repuestos: no hay piezas en este mundo")
	_check(not Game.level_has_trash(), "sin papelera: no hay piezas que botar")
	_check(not Game.level_uses_volt() and not Game.level_uses_solder(), "sin voltimetro ni cautin")

	# Cada PC trae SU minijuego, en el mismo orden en que se colocan.
	for i in EXPECTED.size():
		var task: Dictionary = Game.current_tasks[i]
		_check(task.kind == EXPECTED[i], "tarea %d = %s" % [i + 1, EXPECTED[i]])
		_check(task.fail == EXPECTED[i], "la tarea %d falla en su propio minijuego" % (i + 1))
		_check(int(task.id) == i + 1, "la tarea %d lleva su PC" % (i + 1))
		_check(Game.PART_TITLES.has(task.kind), "y su titulo en el menu")

	# ---- Completar el nivel: las 7 PCs -----------------------------
	for i in 7:
		Game.mark_repaired(i + 1)
		if i < 6:
			_check(Game.state == Game.State.PLAYING, "reparar la PC %d no cierra el nivel" % (i + 1))
	_check(Game.state == Game.State.DONE, "con las 7 PCs el nivel se cierra")
	_check(Game.repaired.size() == 7, "las 7 PCs quedan anotadas")
	_check(Game.score >= 7 * Game.POINTS_PER_TASK - 20 * Game.WRONG_POINT_PENALTY, "7 tareas suman sus puntos")

# ------------------------------------------------------------------
# La ficha del nivel: los pasos 1, 2, 3… uno debajo del otro
# ------------------------------------------------------------------
func _ficha_y_pendrive() -> void:
	var info := Game.software_level_info_text()
	_check(info.contains("QUÉ HAY EN ESTE NIVEL"), "ficha del nivel del mundo de software")
	_check(info.contains("CONTROLES"), "la ficha explica los controles")
	_check(info.contains("PENDRIVE"), "y explica que el pendrive lleva los archivos")
	_check(info.count("E sobre la PC") == 7, "los 7 pasos explican su movimiento")
	_check(Game.level_info_text(1, Game.SECTION_SOFTWARE).contains("QUÉ HAY"), "la ficha llega por seccion")

	# Los números van en orden y cada uno queda EN SU LÍNEA, con la
	# explicación en la línea de debajo (nunca todo en la misma).
	var prev := -1
	for n in range(1, 8):
		var at := info.find("[b]%d[/b]" % n)
		_check(at > prev, "el paso %d aparece debajo del anterior" % n)
		prev = at

	# ---- El pendrive -----------------------------------------------
	_check(Game.pendrive.is_empty(), "el pendrive arranca VACIO")
	_check(Game.pendrive_names() == "vacío", "y asi se anuncia en el HUD")
	_check(Game.pendrive_add("so_mac"), "se puede cargar un archivo")
	_check(not Game.pendrive_add("so_mac"), "no se carga dos veces")
	_check(Game.pendrive_has("so_mac"), "y se puede consultar")
	_check(Game.pendrive_names().contains("macOS"), "con su rotulo corto")
	Game.pendrive.clear()

# ------------------------------------------------------------------
# Los 7 minijuegos, de punta a punta, por la ventana del HUD
# ------------------------------------------------------------------
func _minijuegos() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	_check(hud.software_panel != null, "el panel de software existe")
	_check(hud.software_panel.visible == false, "arranca cerrado")
	_check(hud.software_host.visible == false, "y su contenedor TAMBIEN (no tapa los botones del menu)")
	_check(hud.MINIGAMES.size() == 7, "el registro reparte 7 minijuegos por tipo de PC")

	Game.start_level(1, Game.SECTION_SOFTWARE)
	_check(Game.pendrive.is_empty(), "el nivel empieza con el pendrive vacio")

	# ---- PC 1 · INTERNET (navegador con descargas) ------------------
	var pc1 := _pc(0)
	hud.open_software(pc1)
	var browser: Node = _mg(hud)
	_check(browser != null and browser is BrowserMinigame, "la PC 1 abre el NAVEGADOR")
	if browser == null:
		hud.free()
		return
	_check(hud.software_panel.visible, "y su ventana se abre")
	_check(Game.is_minigame_open, "el juego avisa que hay una ventana abierta")
	_check(browser.requested.size() == 5, "pide los 5 archivos que faltan")
	_check(browser.show_ads, "y trae anuncios falsos")
	_check(browser._files.size() == Game.SW_ITEM_ORDER.size(), "la pagina lista los 6 archivos")
	_check(hud.software_pendrive.text.contains("vacío"), "al abrir la PC 1 el pendrive aparece vacio")

	var errs := Game.errors
	browser._on_ad_pressed(0, Button.new())
	_check(Game.errors == errs + 1, "pulsar un anuncio instala malware y penaliza")
	_check(browser._popups_open >= 1, "y aparece una ventana emergente")

	var first: String = browser.requested[0]
	browser._on_row_pressed(first)
	_check(browser._active == first, "la primera descarga arranca")
	browser._on_row_pressed(browser.requested[1])
	_check(browser._active == first, "no se pueden apilar descargas")
	browser._tick(10.0)
	_check(bool(browser._files[first].stalled), "la descarga se traba a mitad de camino")
	browser._on_row_pressed(first)
	_check(not bool(browser._files[first].stalled), "REANUDAR la reanuda")
	browser._tick(10.0)
	_check(bool(browser._files[first].done), "la primera descarga termina")
	_check(Game.pendrive_has(first), "y baja al pendrive")
	_check(Game.repaired.is_empty(), "una sola descarga NO repara la PC")
	_check(not browser._all_requested_done(), "y siguen faltando archivos")

	for id: String in browser.requested:
		_download_all(browser, id)
	_check(browser._all_requested_done(), "el pendrive baja los 5 archivos que piden las otras PCs")
	_check(Game.pendrive.size() == 5, "el pendrive queda cargado")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hud.software_pendrive.text.contains("NVIDIA") and hud.software_pendrive.text.contains("Windows"),
		"el HUD dice lo que lleva el pendrive mientras baja")
	await get_tree().create_timer(1.2).timeout
	_check(hud.software_panel.visible == false, "la ventana se sola al terminar")
	_check(1 in Game.repaired, "con las descargas se repara la PC 1")
	pc1.free()

	# ---- PC 2 · CONTROLADORES (por sección de fabricante) -----------
	var pc2 := _pc(1)
	hud.open_software(pc2)
	var drivers: Node = _mg(hud)
	_check(drivers != null and drivers is DriversMinigame, "la PC 2 abre los CONTROLADORES")
	if drivers == null:
		hud.free()
		return
	_check(drivers.items.size() == 3, "tres secciones: NVIDIA, AMD e Intel")
	_check(not drivers.is_installed("driver_nvidia"), "todavia no hay ninguno instalado")
	_check(_pill_text(drivers, "driver_nvidia") == "EN PENDRIVE", "lo que esta en el pendrive se ve EN PENDRIVE")
	Game.pendrive.erase("driver_nvidia")
	drivers._refresh()
	_check(_pill_text(drivers, "driver_nvidia") == "FALTA · VE A INTERNET", "lo que falta se ve FALTA en su seccion")
	drivers._install("driver_nvidia")
	_check(not drivers.is_installed("driver_nvidia"), "FALTA: sin driver en el pendrive no instala")
	Game.pendrive_add("driver_nvidia")
	drivers._install("driver_nvidia")
	_check(drivers.is_installed("driver_nvidia"), "EN PENDRIVE: ahi si lo instala")
	_check(_pill_text(drivers, "driver_nvidia") == "INSTALADO ✓", "y la seccion pasa a INSTALADO")
	drivers._install("driver_amd")
	drivers._install("driver_intel")
	_check(drivers._all_done(), "los tres controladores instalados")
	await get_tree().create_timer(1.2).timeout
	_check(2 in Game.repaired, "con los drivers se repara la PC 2")
	pc2.free()

	# ---- PC 3 · SISTEMA OPERATIVO (idioma + animación final) -------
	var pc3 := _pc(2)
	hud.open_software(pc3)
	var os_pc: Node = _mg(hud)
	_check(os_pc != null and os_pc is OsInstallMinigame, "la PC 3 abre el instalador de SISTEMA")
	if os_pc == null:
		hud.free()
		return
	_check(_steps_of(os_pc) != null, "el instalador trae los pasos 1, 2 y 3 apilados")
	var flow: Node = os_pc.flow
	flow._pick_os("so_mac")
	_check(str(os_pc.state.get("os_id", "")) == "", "un SO que NO esta en el pendrive no se elige")
	flow._pick_os("so_windows")
	_check(str(os_pc.state.get("os_id", "")) == "so_windows", "elige el SO que SI esta en el pendrive")
	flow._pick_language("es")
	_check(str(os_pc.state.get("lang", "")) == "es", "elige el idioma")
	_check(flow._install_button.disabled == false, "con SO e idioma se habilita INSTALAR")
	flow._start_install()
	flow.tick(6.0)
	_check(bool(os_pc.state.get("installed", false)), "la instalacion termina")
	_check(flow._success.visible, "aparece el cartel verde SISTEMA OPERATIVO INSTALADO")
	await get_tree().create_timer(1.2).timeout
	_check(3 in Game.repaired, "con el sistema instalado se repara la PC 3")
	pc3.free()

	# ---- PC 4 · VIRUS (analizar y poner en cuarentena) --------------
	var pc4 := _pc(3)
	hud.open_software(pc4)
	var virus: Node = _mg(hud)
	_check(virus != null and virus is VirusMinigame, "la PC 4 abre el ANTIVIRUS")
	if virus == null:
		hud.free()
		return
	_check(virus.cards.size() == 8, "4 infectados y 4 buenos en el disco")
	virus.start_scan()
	virus.tick(VirusMinigame.SCAN_TIME + 0.1)
	_check(bool(virus.state.get("scanned", false)), "el analisis termina")
	var sick: Array = []
	var good: Array = []
	for i in virus.cards.size():
		if bool(virus.cards[i].virus):
			sick.append(i)
		else:
			good.append(i)
	_check(sick.size() == 4 and good.size() == 4, "el antivirus distingue los infectados de los buenos")
	errs = Game.errors
	virus.quarantine(good[0])
	_check(Game.errors == errs + 1, "un archivo BUENO en cuarentena penaliza")
	for i: int in sick:
		virus.quarantine(i)
	_check(virus.cleaned_count() == 4, "los 4 virus en cuarentena")
	_check(virus._all_done(), "el disco queda limpio")
	await get_tree().create_timer(1.2).timeout
	_check(4 in Game.repaired, "con el disco limpio se repara la PC 4")
	pc4.free()

	# ---- PC 5 · PROCESOS (más del 50% de CPU) -----------------------
	var pc5 := _pc(4)
	hud.open_software(pc5)
	var procs: Node = _mg(hud)
	_check(procs != null and procs is ProcessesMinigame, "la PC 5 abre el ADMINISTRADOR DE TAREAS")
	if procs == null:
		hud.free()
		return
	_check(procs.required == 3, "hay 3 procesos maliciosos")
	_check(procs._rows.size() == 7, "7 procesos en la lista (3 malos y 4 buenos)")
	var good_idx := -1
	var bad_left := 0
	for i in procs._rows.size():
		if int(procs._rows[i].cpu) > ProcessesMinigame.CPU_LIMIT:
			bad_left += 1
		elif good_idx < 0:
			good_idx = i
	_check(good_idx >= 0 and bad_left == 3, "la regla de CPU separa 3 malos de los buenos")
	errs = Game.errors
	procs._on_kill(good_idx)
	_check(Game.errors == errs + 1, "matar un proceso del sistema penaliza")
	_check(procs._stability == 75, "y baja la estabilidad de la PC")
	for i in procs._rows.size():
		if int(procs._rows[i].cpu) > ProcessesMinigame.CPU_LIMIT \
				and not bool(procs._rows[i].get("done", false)):
			procs._on_kill(i)
	_check(procs._killed == 3, "los 3 maliciosos terminados")
	await get_tree().create_timer(1.2).timeout
	_check(5 in Game.repaired, "con el sistema limpio se repara la PC 5")
	pc5.free()

	# ---- PC 6 · CAMBIAR DE SISTEMA (quitar uno y poner otro) --------
	var pc6 := _pc(5)
	hud.open_software(pc6)
	var swap: Node = _mg(hud)
	_check(swap != null and swap is OsSwapMinigame, "la PC 6 abre CAMBIAR DE SISTEMA")
	if swap == null:
		hud.free()
		return
	_check(swap.flow != null, "trae el flujo para instalar el sistema nuevo")
	swap._start_remove()
	_check(not bool(swap.state.get("removed", false)), "sin marcar la casilla NO se borra nada")
	swap._erase_check.button_pressed = true
	swap._start_remove()
	_check(bool(swap.state.get("removing", false)), "con la casilla confirmada empieza el borrado")
	swap._process(2.0)
	_check(bool(swap.state.get("removed", false)), "el sistema viejo queda fuera")
	_check(swap.flow.visible, "y aparece el instalador del sistema nuevo")
	swap.flow._pick_os("so_linux")
	swap.flow._pick_language("pt")
	swap.flow._start_install()
	swap.flow.tick(6.0)
	_check(bool(swap.state.get("installed", false)), "el sistema nuevo queda instalado")
	_check(swap.flow._success.visible, "con su cartel verde final")
	await get_tree().create_timer(1.2).timeout
	_check(6 in Game.repaired, "con el cambio de sistema se repara la PC 6")
	pc6.free()

	# ---- PC 7 · ANUNCIOS (desinstalar el bloatware, no lo útil) -----
	var pc7 := _pc(6)
	hud.open_software(pc7)
	var ads: Node = _mg(hud)
	_check(ads != null and ads is AdsMinigame, "la PC 7 abre el desinstalador de ANUNCIOS")
	if ads == null:
		hud.free()
		return
	_check(ads.items.size() == 3, "hay 3 programas de publicidad que quitar")
	_check(not bool(AdsMinigame.program("winrar").bloat), "WinRAR es un programa util")
	errs = Game.errors
	ads._on_remove_pressed("winrar")
	_check(Game.errors == errs + 1, "quitar un programa util penaliza")
	_check(bool(ads.state.get("protected", {}).get("winrar", false)), "y queda marcado como util")
	ads._on_remove_pressed("turbo")
	_check(ads._view == "confirm", "muestra el aviso de despedida con su trampa")
	ads._on_trick_no()
	_check(ads.trick_count() == 1, "el boton grande NO desinstala: ahi esta la trampa")
	ads._on_remove_pressed("turbo")
	_check(ads._pending == "turbo", "hay que volver a pedir la desinstalacion")
	ads._on_confirm_yes()
	ads.tick(1.0)
	_check(ads.is_removed("turbo"), "el primero desinstalado de verdad")
	for id: String in ["quickdeal", "videoplus"]:
		ads._on_remove_pressed(id)
		ads._on_confirm_yes()
		ads.tick(1.0)
		_check(ads.is_removed(id), "%s desinstalado" % id)
	_check(ads.removed_count() == 3, "los 3 programas de anuncios fuera")
	_check(ads._all_done(), "la PC queda solo con los programas utiles")
	await get_tree().create_timer(1.2).timeout
	_check(7 in Game.repaired, "con la PC sin anuncios se repara la PC 7")
	_check(Game.repaired.size() == 7, "las 7 PCs del mundo de software quedan reparadas")
	_check(Game.state == Game.State.DONE, "y el nivel se cierra")
	pc7.free()

	hud.free()

# Baja un archivo del navegador (arranca, aguanta la traba y reanuda).
func _download_all(browser: Node, id: String) -> void:
	var guard := 0
	while not bool(browser._files.get(id, {}).get("done", false)) and guard < 8:
		guard += 1
		if bool(browser._files.get(id, {}).get("stalled", false)):
			browser._on_row_pressed(id)
		elif browser._active != id:
			browser._on_row_pressed(id)
		browser._tick(10.0)

# ------------------------------------------------------------------
# Los 7 tutoriales (uno por minijuego) + los de hardware intactos
# ------------------------------------------------------------------
func _tutoriales() -> void:
	for part: String in Game.SOFTWARE_TUTORIALS:
		Game.pendrive.clear()
		Game.start_tutorial(part)
		var soft: Dictionary = Game.SOFTWARE_TUTORIAL_TASKS[part]
		_check(Game.tutorial_mode and Game.current_section == 2, "%s: tutorial de la seccion 2" % part)
		_check(Game.tutorial_part == part, "%s: su tutorial activo" % part)
		_check(Game.current_tasks.size() == 1, "%s: UNA sola tarea" % part)
		var task: Dictionary = Game.current_tasks[0]
		_check(task.kind == part, "%s: su tarea abre ese minijuego" % part)
		_check(task.fail == part, "%s: y falla en ese minijuego" % part)
		_check(int(task.count) == int(soft.get("count", -1)), "%s: tarea suave (menos acciones)" % part)
		_check(not bool(task.decoy), "%s: sin trampas en la practica" % part)
		_check(Array(task.items).size() == Array(soft.get("items", [])).size(), "%s: sus archivos" % part)
		_check(Game.PART_TITLES.has(part) and Game.PART_INFO.has(part), "%s: tiene su ficha" % part)
		_check(Game.SOFTWARE_TUTORIAL_TEXT.get(part, "") != "", "%s: tiene su texto de practica" % part)
		_check(Game.part_long_text(part).contains("EN EL TUTORIAL"), "%s: y su explicacion" % part)
		_check(Game.level_parts().is_empty(), "%s: sin repuestos" % part)
		_check(not Game.level_has_trash(), "%s: sin papelera" % part)
		_check(Game.random_variant(part).has("name"), "%s: no revienta la variante de la pieza" % part)
		for id: String in soft.get("prefill", []):
			_check(Game.pendrive_has(id), "%s: el pendrive YA trae %s" % [part, id])
		Game.finish_tutorial()

	# Un tutorial de hardware sigue abriendo la seccion 1 y no toca el pendrive.
	Game.pendrive.clear()
	Game.start_tutorial("ram")
	_check(Game.tutorial_mode, "el tutorial de piezas entra en modo tutorial")
	_check(Game.current_section == 1, "los tutoriales de piezas siguen en la seccion 1")
	_check(Game.tutorial_part == "ram", "y su pieza sigue siendo la RAM")
	_check(Game.pendrive.is_empty(), "el tutorial de hardware NO usa el pendrive")
	Game.finish_tutorial()

# ------------------------------------------------------------------
# El menú: 7 botones de software, sección 2 y su único nivel
# ------------------------------------------------------------------
func _menu() -> void:
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	_check(menu._tut_part_buttons.size() == 17, "10 tutoriales de hardware y 7 de software")
	_check(menu._tut_software_buttons.size() == 7, "un boton por minijuego")

	menu._current_section = 2
	menu._open_tutorials_pick()
	for part: String in Game.SOFTWARE_TUTORIALS:
		_check(menu._tut_software_buttons[part].visible, "se ve el tutorial de %s" % Game.PART_TITLES[part])
	_check(not menu.tut_ram_button.visible, "en la seccion 2 NO se ven los tutoriales de piezas")
	_check(menu.mechanics_header.visible == false, "el encabezado de mecanicas se oculta")
	_check(menu.pick_title.text.contains("SOFTWARE"), "el titulo del menu indica el mundo")
	await get_tree().process_frame

	menu._current_section = 1
	menu._open_tutorials_pick()
	_check(menu.tut_ram_button.visible, "en la seccion 1 se ven los tutoriales de piezas")
	_check(not menu._tut_software_buttons["download"].visible, "y NO se ven los de software")
	await get_tree().process_frame

	# Entrar al mundo por el menú: sección 2 → su título, su ficha y su nivel.
	menu._select_section(2)
	_check(menu.section_title.text.contains("SOFTWARE"), "el menu de seccion anuncia el mundo de software")
	_check(menu.section_level_buttons[0].visible, "su UNICO nivel se ve")
	_check(not menu.section_level_buttons[1].visible, "no hay un nivel 2 que no existe")
	_check(not menu.section_level_buttons[5].visible, "y no hereda los 6 niveles del taller")
	menu._play_level(1)
	_check(Game.state == Game.State.PLAYING, "JUGAR arranca la partida")
	_check(Game.current_section == 2, "desde el menu se entra en la seccion 2")
	_check(Game.uses_software_room(), "y el nivel es el del mundo de software")
	Game.quit_to_menu()

	menu._select_section(1)
	_check(menu.section_title.text.contains("REPARACIÓN"), "la seccion 1 sigue anunciando su taller")
	_check(menu.section_level_buttons[5].visible, "y sigue teniendo sus 6 niveles")
	menu.free()

# ------------------------------------------------------------------
# La sala: 7 PCs construidas por código, mira del jugador y tecla E
# ------------------------------------------------------------------
func _sala() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	# El nivel se arranca DESPUÉS para que la sala se construya con las 7 PCs.
	Game.start_level(1, Game.SECTION_SOFTWARE)
	await get_tree().create_timer(0.6).timeout
	_check(Game.state == Game.State.PLAYING, "el nivel de software arranca en PLAYING")
	_check(Game.time_left > 0.0, "el cronometro corre en el mundo de software")
	_check(Game.current_tasks.size() == 7, "sigue habiendo 7 tareas tras cargar la sala")
	_check(Game.hud == main.get_node("HUD"), "el HUD de la sala toma el control")

	var level: Node = main.get_node("Level")
	var pcs: Array = []
	for child in level.get_children():
		if child is SoftwarePC:
			pcs.append(child)
	_check(pcs.size() == 7, "la sala construye LAS SIETE PCs")
	pcs.sort_custom(func(a, b) -> bool: return (a as Node3D).position.x < (b as Node3D).position.x)
	for i in pcs.size():
		var pos: Vector3 = (pcs[i] as Node3D).position
		_check(pcs[i].pc_id == i + 1, "la PC %d ocupa su sitio en la fila" % (i + 1))
		_check(pcs[i].kind == EXPECTED[i], "la PC %d abre %s" % [i + 1, EXPECTED[i]])
		_check(is_equal_approx(pos.z, -4.4), "la PC %d esta pegada a la pared" % (i + 1))
		_check(pcs[i].task is Dictionary and pcs[i].task.get("kind", "") == EXPECTED[i],
			"la PC %d guarda su tarea" % (i + 1))
		if i > 0:
			var gap: float = pos.x - (pcs[i - 1] as Node3D).position.x
			_check(is_equal_approx(gap, 1.95), "la PC %d respeta el paso de la fila" % (i + 1))
	_check(is_equal_approx((pcs[3] as Node3D).position.x, 0.0), "la fila queda centrada en la sala")

	# El jugador camina, mira cada PC y la abre con E (flujo real de juego).
	var pl: Node3D = main.get_node("Player")
	var hud: Node = main.get_node("HUD")
	await _aim_at(pl, pcs[0])
	_check(pl.current_interactable is SoftwarePC and pl.current_interactable.pc_id == 1, "la mira alcanza la PC 1 (INTERNET)")
	pl._try_interact()
	_check(hud.software_panel.visible, "la tecla E abre la ventana de la PC 1")
	_check(Game.is_minigame_open, "y bloquea la camara mientras esta abierta")
	_check(hud.software_content.get_child(0) is BrowserMinigame, "la PC 1 abre el NAVEGADOR")
	hud.close_software()
	_check(Game.is_minigame_open == false, "al cerrar vuelve el control al jugador")

	await _aim_at(pl, pcs[3])
	_check(pl.current_interactable is SoftwarePC and pl.current_interactable.pc_id == 4, "la mira alcanza la PC 4 (VIRUS)")
	pl._try_interact()
	_check(hud.software_content.get_child(0) is VirusMinigame, "la PC 4 abre el ANTIVIRUS")
	hud.close_software()

	await _aim_at(pl, pcs[6])
	_check(pl.current_interactable is SoftwarePC and pl.current_interactable.pc_id == 7, "la mira alcanza la PC 7 (ANUNCIOS)")
	pl._try_interact()
	_check(hud.software_content.get_child(0) is AdsMinigame, "la PC 7 abre el DESINSTALADOR")
	hud.close_software()

	# Cerrar con ESC no deja el ratón suelto.
	hud.software_panel.visible = true
	hud.software_host.visible = true
	Game.is_minigame_open = true
	hud.close_top_menu()
	_check(hud.software_panel.visible == false, "ESC cierra la ventana de software")
	_check(hud.software_host.visible == false, "y esconde también su contenedor")
	_check(Game.is_minigame_open == false, "y devuelve el control al juego")

	_sala_guard = main

# ------------------------------------------------------------------
# REGRESIÓN: la ventana de software NO puede tapar los botones del menú
# ------------------------------------------------------------------
var _sala_guard: Node = null

func _regresion() -> void:
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var mm: Node = hud.get_node("MainMenu")
	Game.state = Game.State.MENU
	mm.visible = true
	mm._show_screen(mm.main_screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var play: Button = mm.play_button
	var rect: Rect2 = play.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0, "el botón JUGAR ocupa sitio en pantalla")
	_check(play.is_visible_in_tree(), "el botón JUGAR se ve")

	# Regresión: dentro del HUD nada puede quedar encima del menú, o sea
	# que el control que recibiría el clic tiene que ser el propio botón.
	var top := _control_at(hud, rect.get_center())
	_check(top == play, "el ratón ALCANZA el botón JUGAR (no lo tapa nada)")

	Game.quit_to_menu()
	if _sala_guard:
		_sala_guard.free()
		_sala_guard = null
	hud.free()

# ------------------------------------------------------------------
# La sección 1 no se rompe
# ------------------------------------------------------------------
func _seccion_1_intacta() -> void:
	Game.start_level(1)
	_check(Game.current_section == 1, "vuelve a la seccion 1 por defecto")
	_check(Game.uses_small_room(), "el nivel 1 sigue usando la sala pequena")
	_check(Game.task_count == 3, "el nivel 1 sigue teniendo 3 PCs")
	_check(Game.level_parts().size() > 0, "el nivel 1 sigue teniendo repuestos")
	_check(Game.level_has_trash(), "el nivel 1 sigue teniendo papelera")
	_check(Game.task_count == Game.LEVELS[0].pc_count, "el nivel 1 sigue midiendo sus PCs igual")
	_check(Game.LEVELS.size() == 6, "el taller sigue teniendo sus 6 niveles")
	_check(Game.level_info_text(1, 1).contains("QUÉ HAY EN ESTE NIVEL"), "y su propia ficha")

# ------------------------------------------------------------------
# Auxiliares
# ------------------------------------------------------------------
# Una PC del mundo de software con la tarea que le toca en este nivel.
func _pc(idx: int) -> Node:
	var task: Dictionary = Game.current_tasks[idx]
	var pc: Node = load("res://scenes/pc/software_pc.gd").new()
	pc.pc_id = idx + 1
	pc.kind = str(task.kind)
	pc.symptom = str(task.symptom)
	pc.task = task
	pc.state = {}
	return pc

# El minijuego abierto en la ventana (null si no hay ninguno).
func _mg(hud: Node) -> Node:
	if hud.software_content.get_child_count() == 0:
		return null
	return hud.software_content.get_child(0)

# Coloca al jugador delante del objetivo y lo hace mirarlo de lleno.
func _aim_at(pl: Node3D, target: Node3D) -> void:
	pl.rotation = Vector3.ZERO
	pl.velocity = Vector3.ZERO
	pl.position = Vector3(target.global_position.x, pl.position.y, target.global_position.z + 3.0)
	# El rayo de interacción se actualiza al final de cada paso físico.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var aim: Vector3 = target.global_position
	var cam: Vector3 = pl.camera.global_position
	pl.rotation.y = atan2(-(aim.x - cam.x), -(aim.z - cam.z))
	await get_tree().physics_frame
	cam = pl.camera.global_position
	var dx := aim.x - cam.x
	var dz := aim.z - cam.z
	pl.camera.rotation.x = atan2(aim.y - cam.y, sqrt(dx * dx + dz * dz))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

# Texto de la pastilla de una sección de controladores.
func _pill_text(drivers: Node, id: String) -> String:
	var row: Dictionary = drivers._rows.get(id, {})
	if row.is_empty():
		return ""
	return str((row.pill as PanelContainer).get_child(0).text)

# La caja de pasos 1-2-3 apilados: número arriba, explicación debajo.
func _steps_of(node: Node) -> Node:
	if node is VBoxContainer and node.get_child_count() >= 9:
		var first := node.get_child(0)
		var second := node.get_child(3)
		var third := node.get_child(6)
		if first is Label and second is Label and third is Label \
				and (first as Label).text == "1" \
				and (second as Label).text == "2" \
				and (third as Label).text == "3" \
				and node.get_child(1) is MarginContainer \
				and node.get_child(4) is MarginContainer \
				and node.get_child(7) is MarginContainer:
			return node
	for child in node.get_children():
		var found := _steps_of(child)
		if found:
			return found
	return null

# ¿Qué Control recibirá el ratón en este punto? Recorre el árbol al revés
# (lo que se dibuja encima va primero) y descarta los que dejan pasar el
# ratón (MOUSE_FILTER_IGNORE) o los que no se ven.
func _control_at(from: Node, pos: Vector2) -> Control:
	var children := from.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child: Node = children[i]
		var found := _control_at(child, pos)
		if found:
			return found
		if child is Control:
			var ctrl := child as Control
			if ctrl.visible and ctrl.is_visible_in_tree() \
					and ctrl.mouse_filter != Control.MOUSE_FILTER_IGNORE \
					and ctrl.get_global_rect().has_point(pos):
				return ctrl
	return null

func _check(condition: bool, label: String) -> void:
	if condition:
		print("ok  - %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)
