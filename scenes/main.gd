extends Node3D

# Habitación del tutorial: pequeña, con una sola PC y una sola estación.
const ROOM_HALF := 5.0
const ROOM_HEIGHT := 3.0
const ROOM_WALL_THICKNESS := 0.3
const ROOM_FLOOR_TOP := 0.35
const TUTORIAL_DESK_POS := Vector3(0.0, 0.0, -2.5)
# La caja del repuesto va DENTRO de la habitación, detrás y a la derecha del PC.
# (Con el offset viejo caía en z=-5.7: al otro lado de la pared norte.)
const TUTORIAL_STATION_OFFSET := Vector3(2.1, 0.0, -1.4)
const TUTORIAL_SPAWN := Vector3(0.0, 1.4, 3.0)

# Niveles 1-4 (sala pequeña): PCs en fila al fondo, cajas de repuestos
# una al lado de la otra contra la pared este y la papelera AL LADO de la
# fila de escritorios (frente al extremo oeste).
# Niveles 5-6 (sala mediana): 5 PCs en fila, cajas en fila contra la
# pared sur y la papelera AL FRENTE de la fila de escritorios.
const LEVEL_SPAWN := TUTORIAL_SPAWN
const SMALL_DESK_Z := -3.0
const SMALL_DESK_GAP := 2.4
const STATION_ROW_X := 4.0
const STATION_ROW_GAP := 1.6
# Papelera a un paso del primer escritorio (dónde sacas las piezas dañadas).
const TRASH_SMALL_POS := Vector3(-4.1, 0.0, -1.8)

const MED_ROOM_HALF := 6.0
const MED_DESK_Z := -3.4
const MED_DESK_GAP := 2.4
const MED_STATION_POS := Vector3(0.0, 0.0, 4.8)
const MED_STATION_GAP := 1.7
const TRASH_MED_POS := Vector3(-4.6, 0.0, -2.2)

var _desk_shape: BoxShape3D
var _desk_mesh: BoxMesh
var _desk_mat: StandardMaterial3D
var _pc_scene: PackedScene
var _station_scene: PackedScene
var _room_wall_mat: StandardMaterial3D
var _room_floor_mat: StandardMaterial3D
var _env_nodes: Array[Node] = []
var _server_config_pc: SoftwarePC = null
var _server_config_sign: Label3D = null
var _server_slot_lights: Array[MeshInstance3D] = []
var _server_slot_labels: Array[Label3D] = []

@onready var level_root: Node3D = $Level
@onready var player: CharacterBody3D = $Player
@onready var env_scenario: Node3D = $escenario

func _ready() -> void:
	_desk_shape = BoxShape3D.new()
	_desk_shape.size = Vector3(1.3, 0.8, 0.85)
	_desk_mesh = BoxMesh.new()
	_desk_mesh.size = Vector3(1.3, 0.8, 0.85)
	_desk_mat = StandardMaterial3D.new()
	_desk_mat.albedo_color = Color(0.55, 0.4, 0.25)
	_desk_mat.roughness = 0.8
	_pc_scene = load("res://scenes/pc/pc.tscn")
	_station_scene = load("res://scenes/parts/part_station.tscn")
	_build_room_resources()
	_env_nodes = [env_scenario, $WallNorth, $WallSouth, $WallEast, $WallWest]
	Game.game_started.connect(_setup_level)
	if not Game.task_completed.is_connected(_on_server_task_completed):
		Game.task_completed.connect(_on_server_task_completed)

# Prepara los materiales de las habitaciones cerradas (los tamaños de
# pared y suelo se construyen para cada sala al abrirla).
func _build_room_resources() -> void:
	_room_wall_mat = StandardMaterial3D.new()
	_room_wall_mat.albedo_color = Color(0.3, 0.3, 0.38)
	_room_wall_mat.roughness = 0.9
	_room_floor_mat = StandardMaterial3D.new()
	_room_floor_mat.albedo_color = Color(0.42, 0.42, 0.46)
	_room_floor_mat.roughness = 0.95

func _setup_level() -> void:
	if is_instance_valid(player.current_interactable) and player.current_interactable is Interactable:
		player.current_interactable.set_highlighted(false)
	player.current_interactable = null
	for child in level_root.get_children():
		child.free()
	# Todos los niveles se juegan en salas cerradas (sin escenario grande).
	_set_environment_visible(false)
	if Game.tutorial_mode:
		# Cada mundo tiene su propia sala de tutorial.
		if Game.tutorial_part in Game.SOFTWARE_TUTORIALS:
			_setup_software_tutorial_room()
		else:
			_setup_tutorial_room()
		return
	# Mundo de software: la sala con las SIETE computadoras.
	if Game.uses_software_room():
		_setup_software_room()
		return
	if Game.uses_server_room():
		_setup_server_room()
		return
	if Game.uses_medium_room():
		# Niveles 5-6: sala mediana, 5 PCs en fila, cajas juntas y la
		# papelera AL FRENTE de la fila de escritorios.
		_build_closed_room(MED_ROOM_HALF)
		_spawn_desks_row(MED_DESK_Z, MED_DESK_GAP)
		_spawn_stations_row(MED_STATION_POS, Vector3(1, 0, 0), MED_STATION_GAP)
		_spawn_trash(TRASH_MED_POS)
		player.position = LEVEL_SPAWN
		player.velocity = Vector3.ZERO
		return
	# Niveles 1-4: sala pequeña, todo cerca y la papelera junto a los PCs.
	_build_closed_room(ROOM_HALF)
	_spawn_desks_row(SMALL_DESK_Z, SMALL_DESK_GAP)
	_spawn_stations_row(Vector3(STATION_ROW_X, 0.0, 0.0), Vector3(0, 0, 1), STATION_ROW_GAP)
	_spawn_trash(TRASH_SMALL_POS)
	player.position = LEVEL_SPAWN
	player.velocity = Vector3.ZERO

# Escritorios con su PC en una sola fila, pegados unos a otros.
func _spawn_desks_row(z: float, gap: float) -> void:
	var n := Game.task_count
	var start := -float(n - 1) * gap * 0.5
	for i in n:
		var pos := Vector3(start + float(i) * gap, 0.0, z)
		_spawn_desk(pos)
		level_root.add_child(_make_pc(Game.current_tasks[i], pos))

# Las cajas de repuestos del nivel, una al lado de la otra.
func _spawn_stations_row(center: Vector3, axis: Vector3, gap: float) -> void:
	var types: Array = Game.level_parts()
	var n := types.size()
	for i in n:
		var station: Node = _station_scene.instantiate()
		station.part_type = types[i]
		station.position = center + axis * (float(i) - float(n - 1) * 0.5) * gap
		level_root.add_child(station)

func _spawn_trash(pos: Vector3) -> void:
	if not Game.level_has_trash():
		return
	var bin := TrashBin.new()
	level_root.add_child(bin)
	bin.position = pos

func _setup_tutorial_room() -> void:
	_build_closed_room(ROOM_HALF)
	_spawn_desk(TUTORIAL_DESK_POS)
	level_root.add_child(_make_pc(Game.current_tasks[0], TUTORIAL_DESK_POS))
	var station: Node = _station_scene.instantiate()
	station.part_type = Game.tutorial_station_part()
	station.position = TUTORIAL_DESK_POS + TUTORIAL_STATION_OFFSET
	level_root.add_child(station)
	# El tutorial de la papelera necesita la papelera dentro de la sala.
	if Game.tutorial_mechanic == "trash":
		_spawn_trash(TUTORIAL_DESK_POS + Vector3(-2.6, 0.0, 1.4))
	_spawn_tutorial_title()
	player.position = TUTORIAL_SPAWN
	player.velocity = Vector3.ZERO

# ------------------------------------------------------------------
# MUNDO DE SOFTWARE (sección 2): una sala grande cerrada cuyas PCs
# están preparadas para los minijuegos del nivel actual:
#   · INTERNET (descargas) · CONTROLADORES · SISTEMA OPERATIVO
#   · VIRUS · PROCESOS · CAMBIAR DE SISTEMA · ANUNCIOS
# Sin estanterías ni papelera: aquí no se cargan repuestos, se mueve
# el pendrive que baja la PC de internet.
# ------------------------------------------------------------------
const SW_ROOM_HALF := 7.0
# La fila se queda un poco mas adelantada: detras quedan 2,3 m de pasillo
# (el jugador mide 0,8) y ademas, al proyectarse mas cerca, se abre en
# pantalla y deja ver la esquina donde va la PC de internet.
const SW_DESK_Z := -3.2
const SW_DESK_GAP := 1.95
# La PC de INTERNET (la fuente: de ahí bajan drivers y sistemas) ocupa la
# esquina delantera derecha, la más alejada de la fila de PCs dañadas.
# Se gira para que su pantalla y teclado queden orientados al jugador.
const SW_INET_Z := 6.2
const SW_INET_X := 6.0

func _setup_software_room() -> void:
	_build_closed_room(SW_ROOM_HALF)
	# La fila: todas MENOS la de internet (esa ocupa la esquina libre).
	var row: Array = []
	var inet: Dictionary = {}
	for t: Dictionary in Game.current_tasks:
		if str(t.get("kind", "")) == "download" and inet.is_empty():
			inet = t
		else:
			row.append(t)
	var n := row.size()
	var start := -float(n - 1) * SW_DESK_GAP * 0.5
	for i in n:
		var pos := Vector3(start + float(i) * SW_DESK_GAP, 0.0, SW_DESK_Z)
		_spawn_desk(pos)
		level_root.add_child(_make_software_pc(row[i], pos))
	if not inet.is_empty():
		var inet_pos := Vector3(SW_INET_X, 0.0, SW_INET_Z)
		_spawn_desk(inet_pos)
		# En la esquina delantera el jugador llega desde -Z: la PC debe mirar
		# hacia dentro para que su monitor y teclado estén orientados a la mira.
		level_root.add_child(_make_software_pc(inet, inet_pos, true))
	# Los rótulos de la pared norte van cada uno a un LADO y arriba del
	# todo: esa banda queda libre porque INTERNET está en la otra punta.
	_spawn_room_sign("MUNDO 2 · PROBLEMAS DE SOFTWARE",
		Vector3(-4.5, 3.1, -(SW_ROOM_HALF - 0.3)), 46)
	# Regla de la casa, a la vista en cuanto entras: el pendrive es lo que
	# une las PCs de este nivel (se baja en INTERNET y se instala en las demás).
	if not inet.is_empty():
		_spawn_room_sign("PENDRIVE: baja en INTERNET y llévalo a las otras PCs",
			Vector3(4.35, 3.1, -(SW_ROOM_HALF - 0.3)), 32, Color(1.0, 0.69, 0.13))
	_spawn_wall_screens()
	player.position = LEVEL_SPAWN
	player.velocity = Vector3.ZERO

# ------------------------------------------------------------------
# MUNDO DE SERVIDORES (sección 3): sala rectangular de prueba.
# ------------------------------------------------------------------
const SERVER_ROOM_HALF_X := 8.0
const SERVER_ROOM_HALF_Z := 5.0
const SERVER_TOWER_POS := Vector3(0.0, 0.0, -3.35)
const SERVER_TOWER_INTERACTION_Z := -2.55
const SERVER_TOWER_WIDTH := 2.2
const SERVER_TOWER_HEIGHT := 3.1
const SERVER_TOWER_SLOT_GAP := 0.4
const SERVER_STATION_POS := Vector3(6.4, 0.0, 0.0)
const SERVER_STATION_GAP := 1.4
const SERVER_CONFIG_POS := Vector3(-5.5, 0.0, 1.1)
const SERVER_POSTER_X := -3.8

func _setup_server_room() -> void:
	_build_closed_room(SERVER_ROOM_HALF_X, SERVER_ROOM_HALF_Z)
	_server_config_pc = null
	_server_config_sign = null
	_server_slot_lights.clear()
	_server_slot_labels.clear()
	# Una sola torre física contiene los seis componentes. El nodo de
	# reparación permanece delante de ella y va cambiando de tarea después
	# de cada instalación.
	var task: Dictionary = Game.current_tasks[0]
	var tower_interaction_pos := Vector3(0.0, 0.0, SERVER_TOWER_INTERACTION_Z)
	var tower_pc := _make_pc(task, tower_interaction_pos)
	level_root.add_child(tower_pc)
	tower_pc.set_server_tower_mode()
	tower_pc.prompt_text = "Armar %s" % Game.part_title(str(task.fail))
	# Las cajas quedan en una estantería continua contra la pared este:
	# los rótulos largos se leen completos al girar dentro de la sala.
	_spawn_stations_row(SERVER_STATION_POS, Vector3(0, 0, 1), SERVER_STATION_GAP)
	var storage_sign := Label3D.new()
	storage_sign.name = "ServerStorageSign"
	storage_sign.text = "CAJAS DE COMPONENTES"
	storage_sign.font_size = 28
	storage_sign.outline_size = 8
	storage_sign.modulate = Color(1.0, 0.69, 0.13)
	storage_sign.position = SERVER_STATION_POS + Vector3(0, 2.65, 0)
	storage_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_root.add_child(storage_sign)
	_spawn_trash(Vector3(-6.4, 0.0, -0.5))
	_spawn_server_rack()
	_spawn_server_poster()
	# La segunda estación tiene su propio escritorio; la PC permanece
	# oculta y sin colisión hasta completar el servidor.
	_spawn_desk(SERVER_CONFIG_POS)
	_server_config_sign = Label3D.new()
	_server_config_sign.name = "ServerConfigSign"
	_server_config_sign.text = "CONFIGURACIÓN\nDEL SERVIDOR\n(PENDIENTE)"
	_server_config_sign.font_size = 25
	_server_config_sign.outline_size = 7
	_server_config_sign.modulate = Color(1.0, 0.65, 0.2)
	_server_config_sign.position = SERVER_CONFIG_POS + Vector3(0, 2.15, 0)
	_server_config_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_root.add_child(_server_config_sign)
	_server_config_pc = SoftwarePC.new()
	_server_config_pc.name = "ServerConfigPC"
	_server_config_pc.pc_id = Game.SERVER_CONFIG_ID
	_server_config_pc.kind = "server_setup"
	_server_config_pc.symptom = "El servidor está armado: falta terminar su configuración"
	_server_config_pc.task = {
		"id": Game.SERVER_CONFIG_ID,
		"kind": "server_setup",
		"symptom": _server_config_pc.symptom,
		"stages": ["cables", "ports", "programming"],
		"programs": Game.SERVER_PROGRAMS.duplicate(),
	}
	_server_config_pc.state = {}
	_server_config_pc.position = SERVER_CONFIG_POS + Vector3(0, 1.6, 0)
	level_root.add_child(_server_config_pc)
	_server_config_pc.prompt_text = "Configurar el servidor"
	_server_config_pc.set_available(false)
	player.position = LEVEL_SPAWN
	player.velocity = Vector3.ZERO

func _spawn_server_rack() -> void:
	# Una única torre alta. Los seis strips son sus bahías internas: todos
	# empiezan apagados y se van encendiendo conforme se instalan las piezas.
	var rack := StaticBody3D.new()
	rack.name = "ServerRack"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(SERVER_TOWER_WIDTH, SERVER_TOWER_HEIGHT, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.045, 0.065, 0.10)
	mat.metallic = 0.75
	mat.roughness = 0.32
	mesh.material = mat
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	rack.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	rack.add_child(collision)

	var front_mesh := BoxMesh.new()
	front_mesh.size = Vector3(SERVER_TOWER_WIDTH - 0.25, SERVER_TOWER_HEIGHT - 0.3, 0.06)
	var front_mat := StandardMaterial3D.new()
	front_mat.albedo_color = Color(0.07, 0.11, 0.16)
	front_mat.metallic = 0.55
	front_mat.roughness = 0.4
	front_mesh.material = front_mat
	var front := MeshInstance3D.new()
	front.mesh = front_mesh
	front.position = Vector3(0, 0, 0.53)
	rack.add_child(front)

	for i in Game.SERVER_PARTS.size():
		var part_type := str(Game.SERVER_PARTS[i])
		var slot_y := 0.95 - float(i) * SERVER_TOWER_SLOT_GAP
		var strip := MeshInstance3D.new()
		strip.name = "ServerSlot%d" % (i + 1)
		var strip_mesh := BoxMesh.new()
		strip_mesh.size = Vector3(SERVER_TOWER_WIDTH - 0.4, 0.10, 0.04)
		var strip_mat := StandardMaterial3D.new()
		strip_mat.albedo_color = Color(0.12, 0.16, 0.20)
		strip_mat.emission_enabled = true
		strip_mat.emission = Color(0.03, 0.08, 0.12)
		strip_mat.emission_energy_multiplier = 0.45
		strip_mesh.material = strip_mat
		strip.mesh = strip_mesh
		strip.position = Vector3(0, slot_y, 0.57)
		rack.add_child(strip)
		_server_slot_lights.append(strip)

		var label := Label3D.new()
		label.name = "ServerSlotLabel%d" % (i + 1)
		label.text = Game.part_title(part_type)
		label.font_size = 18
		label.outline_size = 6
		label.modulate = Color(0.45, 0.65, 0.75)
		label.position = Vector3(1.45, 1.65 + slot_y, SERVER_TOWER_POS.z + 0.65)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		level_root.add_child(label)
		_server_slot_labels.append(label)

	rack.position = SERVER_TOWER_POS + Vector3(0, SERVER_TOWER_HEIGHT * 0.5 + 0.1, 0)
	level_root.add_child(rack)
	_update_server_tower_slots()

func _update_server_tower_slots() -> void:
	for i in _server_slot_lights.size():
		var part_type := str(Game.SERVER_PARTS[i]) if i < Game.SERVER_PARTS.size() else ""
		var installed := part_type != "" and Game.server_installed_parts.has(part_type)
		var strip := _server_slot_lights[i]
		var strip_mesh := strip.mesh as BoxMesh
		var strip_mat := strip_mesh.material as StandardMaterial3D
		if installed:
			strip_mat.albedo_color = Color(0.08, 0.65, 0.32)
			strip_mat.emission = Color(0.08, 0.9, 0.35)
			strip_mat.emission_energy_multiplier = 1.5
		else:
			strip_mat.albedo_color = Color(0.12, 0.16, 0.20)
			strip_mat.emission = Color(0.03, 0.08, 0.12)
			strip_mat.emission_energy_multiplier = 0.45
		if i < _server_slot_labels.size():
			var label := _server_slot_labels[i]
			label.text = "%s · %s" % [Game.part_title(part_type), "LISTO" if installed else "VACÍO"]
			label.modulate = Color(0.35, 1.0, 0.55) if installed else Color(0.45, 0.65, 0.75)

func _spawn_server_poster() -> void:
	var panel := MeshInstance3D.new()
	panel.name = "ServerPoster"
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(6.2, 2.2, 0.08)
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.025, 0.045, 0.08)
	panel_mat.emission_enabled = true
	panel_mat.emission = Color(0.02, 0.16, 0.25)
	panel_mat.emission_energy_multiplier = 0.7
	panel_mesh.material = panel_mat
	panel.mesh = panel_mesh
	panel.position = Vector3(SERVER_POSTER_X, 2.05, -SERVER_ROOM_HALF_Z + 0.18)
	level_root.add_child(panel)
	var title := Label3D.new()
	title.text = "SERVIDOR"
	title.font_size = 96
	title.outline_size = 16
	title.modulate = Color(0.2, 0.9, 1.0)
	title.position = Vector3(SERVER_POSTER_X, 2.7, -SERVER_ROOM_HALF_Z + 0.28)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	level_root.add_child(title)

func _on_server_task_completed(_pc_id: int) -> void:
	if not Game.uses_server_room() or Game.server_config_done:
		return
	_update_server_tower_slots()
	if Game.repaired.size() >= Game.task_count:
		Game.prepare_server_setup()
		if is_instance_valid(_server_config_pc):
			_server_config_pc.set_available(true)
		if is_instance_valid(_server_config_sign):
			_server_config_sign.text = "CONFIGURACIÓN\nDEL SERVIDOR"
			_server_config_sign.modulate = Color(0.7, 0.45, 1.0)
		if Game.hud:
			Game.hud.show_message("Servidor armado: configura la PC con cables, puertos y programación.")

# Tutorial de una tarea de software: un solo escritorio con su PC.
func _setup_software_tutorial_room() -> void:
	_build_closed_room(ROOM_HALF)
	_spawn_desk(TUTORIAL_DESK_POS)
	level_root.add_child(_make_software_pc(Game.current_tasks[0], TUTORIAL_DESK_POS))
	_spawn_room_sign("TALLER DE SOFTWARE", Vector3(0.0, 2.75, -(ROOM_HALF - 0.3)))
	_spawn_tutorial_title()
	player.position = TUTORIAL_SPAWN
	player.velocity = Vector3.ZERO

func _make_software_pc(task: Dictionary, pos: Vector3, face_player := false) -> Node:
	var pc := SoftwarePC.new()
	pc.pc_id = int(task.get("id", 0))
	pc.kind = str(task.get("kind", "download"))
	pc.symptom = str(task.get("symptom", ""))
	pc.task = task
	# El estado (descargas hechas, drivers instalados, archivos en
	# cuarentena…) vive en la propia PC: cerrar la ventana no lo pierde.
	pc.state = {}
	pc.position = pos + Vector3(0, 1.6, 0)
	if face_player:
		pc.rotation.y = PI
	return pc

# Rótulo fijo en la pared norte (no gira con la cámara).
func _spawn_room_sign(text: String, pos: Vector3, size := 54, color := Color(0.15, 0.9, 1.0)) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 10
	label.modulate = color
	label.position = pos
	level_root.add_child(label)

# Pantallas encendidas, para que la sala se vea de taller. Van en la
# pared SUR (detrás del punto de entrada); falta la de la esquina derecha
# porque ahí está la PC de INTERNET y su rótulo iría encima.
func _spawn_wall_screens() -> void:
	var wall_z := SW_ROOM_HALF - 0.28
	for x: float in [-5.7, -3.4, 3.4]:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.2, 1.2, 0.06)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.03, 0.06, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(0.05, 0.5, 0.7)
		mat.emission_energy_multiplier = 0.8
		mesh.material = mat
		var screen := MeshInstance3D.new()
		screen.mesh = mesh
		screen.position = Vector3(x, 2.3, wall_z)
		level_root.add_child(screen)

func _make_pc(task: Dictionary, pos: Vector3) -> Node:
	var pc: Node = _pc_scene.instantiate()
	pc.pc_id = task.id
	pc.symptom = task.symptom
	pc.fail_type = task.fail
	pc.fail_type2 = task.fail2
	pc.fail_variant = task.variant
	pc.fail_variant2 = task.variant2
	pc.fail_fault = task.get("fault", "")
	pc.fail_fault2 = task.get("fault2", "")
	pc.fail_fix = task.get("fix", "")
	pc.fail_fix2 = task.get("fix2", "")
	pc.position = pos + Vector3(0, 1.6, 0)
	return pc

# Oculta el escenario grande (y sus paredes): todos los niveles y el
# tutorial se juegan en habitaciones cerradas.
func _set_environment_visible(on: bool) -> void:
	for node in _env_nodes:
		if node:
			node.visible = on

# Habitación cerrada: la usan el tutorial (10x10), los niveles
# (10x10 en los pequeños y 12x12 en los medianos) y la sala rectangular
# de servidores (16x10).
func _build_closed_room(half: float, half_z: float = -1.0) -> void:
	var inner := half * 2.0
	var depth_half := half if half_z < 0.0 else half_z
	var depth := depth_half * 2.0
	var wall_y := ROOM_FLOOR_TOP + ROOM_HEIGHT / 2.0
	# Cada eje necesita su propia forma: las paredes este/oeste van a lo largo de Z.
	var shape_ns := BoxShape3D.new()
	shape_ns.size = Vector3(inner + ROOM_WALL_THICKNESS * 2.0, ROOM_HEIGHT, ROOM_WALL_THICKNESS)
	var shape_ew := BoxShape3D.new()
	shape_ew.size = Vector3(ROOM_WALL_THICKNESS, ROOM_HEIGHT, depth + ROOM_WALL_THICKNESS * 2.0)
	var mesh_ns := BoxMesh.new()
	mesh_ns.size = Vector3(inner + ROOM_WALL_THICKNESS * 2.0, ROOM_HEIGHT, ROOM_WALL_THICKNESS)
	var mesh_ew := BoxMesh.new()
	mesh_ew.size = Vector3(ROOM_WALL_THICKNESS, ROOM_HEIGHT, depth)
	var ns_poses: Array = [Vector3(0, wall_y, -depth_half), Vector3(0, wall_y, depth_half)]
	var ew_poses: Array = [Vector3(-half, wall_y, 0), Vector3(half, wall_y, 0)]
	for pose: Vector3 in ns_poses:
		level_root.add_child(_make_room_wall(pose, mesh_ns, shape_ns))
	for pose: Vector3 in ew_poses:
		level_root.add_child(_make_room_wall(pose, mesh_ew, shape_ew))
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(inner, 0.3, depth)
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.material_override = _room_floor_mat
	floor.position = Vector3(0, ROOM_FLOOR_TOP - 0.15, 0)
	level_root.add_child(floor)

func _make_room_wall(pos: Vector3, mesh: Mesh, shape: BoxShape3D) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = pos
	var col := CollisionShape3D.new()
	col.shape = shape
	wall.add_child(col)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _room_wall_mat
	wall.add_child(mesh_instance)
	return wall

func _spawn_tutorial_title() -> void:
	var label := Label3D.new()
	label.text = "TUTORIAL: %s" % Game.PART_TITLES.get(Game.tutorial_part, "").to_upper()
	label.font_size = 64
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = TUTORIAL_DESK_POS + Vector3(0, 2.7, 0)
	level_root.add_child(label)

func _spawn_desk(pos: Vector3) -> void:
	var desk := StaticBody3D.new()
	desk.position = pos + Vector3(0, 0.75, 0)
	var col := CollisionShape3D.new()
	col.shape = _desk_shape
	desk.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _desk_mesh
	mesh.material_override = _desk_mat
	desk.add_child(mesh)
	level_root.add_child(desk)