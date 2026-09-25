extends Node

var failures := 0

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame

	_check(Game.SECTION_SERVER == 3, "la sección 3 es la de servidores")
	_check(Game.SERVER_LEVELS.size() == 1, "servidores tiene un solo nivel")
	_check(Game.unlocked_levels >= 3, "la sección de servidores está habilitada")
	var menu: Node = main.get_node("HUD/MainMenu")
	menu._open_levels()
	menu._select_section(3)
	_check(menu.level_buttons[2].disabled == false, "el botón de servidores está habilitado")
	_check(menu.section_level_buttons[0].visible, "el único nivel de servidores se ve")
	_check(menu.section_tutorials_button.visible == false, "servidores no muestra tutoriales de otra sección")

	Game.start_level(1, Game.SECTION_SERVER)
	await get_tree().create_timer(0.2).timeout
	_check(Game.uses_server_room(), "el nivel usa la sala de servidores")
	_check(Game.task_count == 6, "el nivel tiene seis componentes")
	_check(Game.level_parts() == Game.SERVER_PARTS, "usa las seis piezas de servidor")
	_check(Game.SERVER_PARTS == ["mb", "psu", "cpu", "hdd", "ram", "liquid"], "el orden del armado es placa, fuente, CPU, ROM, RAM y líquido")
	var ram_names: Array = []
	for variant: Dictionary in Game.SERVER_PART_VARIANTS["ram"]:
		ram_names.append(str(variant.name))
	var ram_text := " ".join(ram_names)
	_check(not ("32GB" in ram_text) and not ("64GB" in ram_text), "la RAM del servidor usa más de 64GB")
	_check(Game.pendrive.is_empty(), "el pendrive empieza vacío")

	var level: Node = main.get_node("Level")
	var component_pcs := 0
	var stations := 0
	var component_nodes: Array[Node] = []
	var config: SoftwarePC = null
	for child in level.get_children():
		var script: Script = child.get_script()
		if script and str(script.resource_path) == "res://scenes/pc/pc.gd":
			component_pcs += 1
			component_nodes.append(child)
		if child is RepairStation:
			stations += 1
		if child is SoftwarePC and child.kind == "server_setup":
			config = child
	_check(component_pcs == 1, "hay una sola torre de componentes")
	var visible_towers := 0
	for component in component_nodes:
		var case_mesh := component.get_node("Case") as MeshInstance3D
		if case_mesh.visible:
			visible_towers += 1
	_check(visible_towers == 0, "lasbahías no muestran torres de PC")
	_check(stations == 6, "hay seis cajas de piezas")
	var rack: StaticBody3D = level.get_node("ServerRack")
	var rack_visual := rack.get_child(0) as MeshInstance3D
	var rack_size: Vector3 = (rack_visual.mesh as BoxMesh).size
	_check(rack_size.y > rack_size.x and rack_size.y >= 2.5, "el servidor es una sola torre grande")
	_check(rack.get_node_or_null("ServerSlot6") != null, "la torre tiene la sexta bahía de refrigeración")
	_check(level.get_node_or_null("ServerPoster") != null, "la sala tiene el cuadro del servidor")
	_check(config != null and not config.visible, "la PC de configuración aparece después")
	_check(Game.pc_display_name(Game.SERVER_CONFIG_ID) == "CONFIGURACIÓN DEL SERVIDOR", "la PC de configuración no muestra un ID interno")
	var config_shape: CollisionShape3D = config.get_node("InteractionShape")
	_check(config_shape.disabled, "la PC oculta no se puede interactuar")

	# El primer componente se resuelve por el camino real: abrir la PC,
	# escoger un repuesto del servidor y terminar el minijego de instalación.
	var hud: Node = main.get_node("HUD")
	var first_pc: Node = component_nodes[0]
	var repair_minigame: Node = hud.get_node("Gameplay/Minigame")
	hud.open_minigame(first_pc)
	var first_slot: RepairSlot = repair_minigame._slot_nodes[str(first_pc.fail_type)]
	var first_variant: Dictionary = Game.part_variants(str(first_pc.fail_type))[0]
	_check(Game.pick_part_variant(first_variant), "el servidor usa los modelos de repuesto")
	repair_minigame._on_part_dropped(first_slot, Game.carried_parts.back())
	hud._on_removal_done()
	await get_tree().process_frame
	_check(Game.repaired.size() == 1 and first_pc.visible and int(first_pc.pc_id) == 2, "el primer componente se instala y la torre queda para el siguiente")

	for i in range(2, 6):
		Game.mark_repaired(i)
	await get_tree().process_frame
	_check(Game.repaired.size() == 5 and not Game.server_parts_ready and not config.visible, "la configuración sigue bloqueada hasta instalar la refrigeración líquida")
	# El sexto componente usa el minijuego propio de refrigeración líquida.
	hud.open_minigame(first_pc)
	var liquid_board: LiquidCoolingMinigame = repair_minigame._liquid_board
	_check(liquid_board != null, "se abre el minijuego de refrigeración líquida")
	var liquid_variant: Dictionary = Game.part_variants("liquid")[0]
	_check(Game.pick_part_variant(liquid_variant), "se toma el kit líquido")
	liquid_board.insert_for_test(Game.carried_parts.back())
	var has_gpu := false
	for component: Dictionary in liquid_board._board.components:
		if str(component.get("id", "")) == "gpu":
			has_gpu = true
	_check(has_gpu, "el cuadro incluye la GPU pequeña")
	_check(liquid_board._board.remaining_for("gpu") > 0, "hay una pieza específica para la GPU")
	_check(liquid_board._board.remaining_for("straight") >= 32, "hay suficientes rectas para completar el cuadro")
	var first_piece_card = liquid_board._piece_cards[0]
	first_piece_card.rotate()
	_check(first_piece_card.piece_rotation == 1, "las piezas se pueden rotar")
	first_piece_card.rotate()
	first_piece_card.rotate()
	first_piece_card.rotate()
	var removable_cell := Vector2i(1, 0)
	var special_cell := Vector2i(2, 0)
	liquid_board._board._drop_data(liquid_board._board._cell_center(special_cell), {"pipe_piece": true, "type": "cpu", "rotation": 0})
	_check(liquid_board._board.placed_count() == 0, "una pieza CPU sin vecina no se puede colocar")
	liquid_board._board._drop_data(liquid_board._board._cell_center(removable_cell), {"pipe_piece": true, "type": "straight", "rotation": 0})
	liquid_board._board._drop_data(liquid_board._board._cell_center(special_cell), {"pipe_piece": true, "type": "cpu", "rotation": 0})
	_check(liquid_board._board.placed_count() == 2, "la CPU se coloca cuando una recta la conecta")
	_check(liquid_board._board.remove_at(special_cell), "las piezas especiales se pueden quitar")
	_check(liquid_board._board.remove_at(removable_cell), "las piezas colocadas se pueden quitar")
	liquid_board.connect_for_test()
	_check(liquid_board._board.network_is_solved(), "las tuberías conectan el cuadro desde IN hasta OUT")
	_check(liquid_board._board.covered_component_count() == liquid_board._board.components.size(), "las piezas calientes quedan cubiertas")
	_check(liquid_board._liquid_added, "el refrigerante se coloca dentro del reservorio")
	_check(liquid_board._route.connected_points == liquid_board._connectors.size(), "las tuberías pasan por los puntos del servidor")
	_check(liquid_board._progress.value == 100.0, "la barra del ducto llega al 100%")
	liquid_board.pump_for_test()
	_check(liquid_board._route.flowing, "la bomba hace circular el refrigerante por el tablero")
	await get_tree().process_frame
	for index in component_nodes.size():
		var component: Node = component_nodes[index]
		var collision := component.get_node("CollisionShape3D") as CollisionShape3D
		_check(collision != null and collision.disabled, "la torre ya no bloquea la mira al terminar")
	_check(Game.state == Game.State.PLAYING, "el armado no termina el nivel")
	_check(Game.server_parts_ready, "el servidor queda listo para configurar")
	_check(Game.server_installed_parts.size() == Game.SERVER_PARTS.size(), "la torre contiene los seis componentes")
	_check(Game.pendrive.is_empty(), "el servidor no usa pendrive")
	_check(Game.usb_needed("server_setup") == false, "la configuración no pide USB")
	_check(config.visible and not config_shape.disabled, "la PC de configuración se revela")

	hud.open_software(config)
	var mg: Node = hud.software_content.get_child(0)
	_check(mg is ServerSetupMinigame, "la configuración usa minijuegos directos de PC")
	_check(hud.software_tab_error.text == "CONFIGURACIÓN", "la PC muestra la pestaña de configuración, no la del pendrive")
	for cable_id in ["power", "data", "ethernet"]:
		mg.connect_cable_for_test(cable_id)
	await get_tree().process_frame
	for port_id in ["net", "data", "admin"]:
		mg.connect_port_for_test(port_id)
	await get_tree().process_frame
	mg.complete_programming_for_test()
	await get_tree().create_timer(1.0).timeout
	_check(Game.server_config_done, "la configuración del servidor se completa")
	_check((config.get_node("Label") as Label3D).text == "LISTA", "la PC de configuración se marca como lista")
	_check(Game.state == Game.State.DONE, "el nivel de servidores termina")

	if failures == 0:
		print("TEST: SERVIDORES OK")
		get_tree().quit(0)
	else:
		printerr("TEST: %d FALLOS" % failures)
		get_tree().quit(1)

func _check(condition: bool, name: String) -> void:
	if condition:
		print("PASS: ", name)
	else:
		failures += 1
		printerr("FAIL: ", name)
