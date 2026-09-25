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
# MUNDO DE SOFTWARE (sección 2): una sala grande cerrada con SIETE
# escritorios en fila, cada uno con su PC y su minijuego:
#   · INTERNET (descargas) · CONTROLADORES · SISTEMA OPERATIVO
#   · VIRUS · PROCESOS · CAMBIAR DE SISTEMA · ANUNCIOS
# Sin estanterías ni papelera: aquí no se cargan repuestos, se mueve
# el pendrive que baja la PC de internet.
# ------------------------------------------------------------------
const SW_ROOM_HALF := 7.0
const SW_DESK_Z := -4.4
const SW_DESK_GAP := 1.95
# La PC de INTERNET (la fuente: de ahí bajan drivers y sistemas) va
# DETRÁS de la fila, centrada y separada: se llega por los lados.
const SW_INET_Z := -6.0

func _setup_software_room() -> void:
	_build_closed_room(SW_ROOM_HALF)
	# La fila: todas MENOS la de internet (esa va detrás y aparte).
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
		var inet_pos := Vector3(0.0, 0.0, SW_INET_Z)
		_spawn_desk(inet_pos)
		level_root.add_child(_make_software_pc(inet, inet_pos))
	# Los dos rótulos van uno a cada LADO y arriba del todo, en su propia
	# banda: el centro lo ocupa el rótulo de la PC de INTERNET de detrás y
	# por debajo quedan libres los rótulos de la fila.
	_spawn_room_sign("MUNDO 2 · PROBLEMAS DE SOFTWARE",
		Vector3(-4.4, 3.1, -(SW_ROOM_HALF - 0.3)), 46)
	# Regla de la casa, a la vista en cuanto entras: el pendrive es lo que
	# une las siete PCs (se baja en INTERNET y se instala en las demás).
	_spawn_room_sign("PENDRIVE: baja en INTERNET y llévalo a las otras PCs",
		Vector3(4.35, 3.1, -(SW_ROOM_HALF - 0.3)), 32, Color(1.0, 0.69, 0.13))
	_spawn_wall_screens()
	player.position = LEVEL_SPAWN
	player.velocity = Vector3.ZERO

# Tutorial de una tarea de software: un solo escritorio con su PC.
func _setup_software_tutorial_room() -> void:
	_build_closed_room(ROOM_HALF)
	_spawn_desk(TUTORIAL_DESK_POS)
	level_root.add_child(_make_software_pc(Game.current_tasks[0], TUTORIAL_DESK_POS))
	_spawn_room_sign("TALLER DE SOFTWARE", Vector3(0.0, 2.75, -(ROOM_HALF - 0.3)))
	_spawn_tutorial_title()
	player.position = TUTORIAL_SPAWN
	player.velocity = Vector3.ZERO

func _make_software_pc(task: Dictionary, pos: Vector3) -> Node:
	var pc := SoftwarePC.new()
	pc.pc_id = int(task.get("id", 0))
	pc.kind = str(task.get("kind", "download"))
	pc.symptom = str(task.get("symptom", ""))
	pc.task = task
	# El estado (descargas hechas, drivers instalados, archivos en
	# cuarentena…) vive en la propia PC: cerrar la ventana no lo pierde.
	pc.state = {}
	pc.position = pos + Vector3(0, 1.6, 0)
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
# pared SUR (detrás del punto de entrada): en la norte ya están los dos
# rótulos, uno a cada lado, y el centro lo ocupa la PC de INTERNET.
func _spawn_wall_screens() -> void:
	var wall_z := SW_ROOM_HALF - 0.28
	for x: float in [-5.7, -3.4, 3.4, 5.7]:
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

# Habitación cerrada: la usan el tutorial (10x10) y los niveles
# (10x10 en los pequeños y 12x12 en los medianos).
func _build_closed_room(half: float) -> void:
	var inner := half * 2.0
	var wall_y := ROOM_FLOOR_TOP + ROOM_HEIGHT / 2.0
	# Cada eje necesita su propia forma: las paredes este/oeste van a lo largo de Z.
	var shape_ns := BoxShape3D.new()
	shape_ns.size = Vector3(inner + ROOM_WALL_THICKNESS * 2.0, ROOM_HEIGHT, ROOM_WALL_THICKNESS)
	var shape_ew := BoxShape3D.new()
	shape_ew.size = Vector3(ROOM_WALL_THICKNESS, ROOM_HEIGHT, inner + ROOM_WALL_THICKNESS * 2.0)
	var mesh_ns := BoxMesh.new()
	mesh_ns.size = Vector3(inner + ROOM_WALL_THICKNESS * 2.0, ROOM_HEIGHT, ROOM_WALL_THICKNESS)
	var mesh_ew := BoxMesh.new()
	mesh_ew.size = Vector3(ROOM_WALL_THICKNESS, ROOM_HEIGHT, inner)
	var ns_poses: Array = [Vector3(0, wall_y, -half), Vector3(0, wall_y, half)]
	var ew_poses: Array = [Vector3(-half, wall_y, 0), Vector3(half, wall_y, 0)]
	for pose: Vector3 in ns_poses:
		level_root.add_child(_make_room_wall(pose, mesh_ns, shape_ns))
	for pose: Vector3 in ew_poses:
		level_root.add_child(_make_room_wall(pose, mesh_ew, shape_ew))
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(inner, 0.3, inner)
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