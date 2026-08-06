extends Node3D

const GRID_ROWS := 3
const GRID_COLS := 3
const GRID_SPACING_X := 4.6
const GRID_SPACING_Z := 4.4

const STATION_POSITIONS := {
	"ram": Vector3(-13.0, 0.0, -10.0),
	"hdd": Vector3(13.0, 0.0, -10.0),
	"psu": Vector3(7.0, 0.0, 10.0),
	"gpu": Vector3(-7.0, 0.0, 10.0),
	"mb": Vector3(0.0, 0.0, -13.0),
	"cpu": Vector3(17.0, 0.0, -2.0),
	"fan": Vector3(-17.0, 0.0, -2.0),
}

func _desk_positions() -> Array:
	var positions: Array = []
	for row in GRID_ROWS:
		for col in GRID_COLS:
			positions.append(Vector3(
				(col - 1) * GRID_SPACING_X,
				0,
				-1.5 - row * GRID_SPACING_Z
			))
	return positions

var _desk_shape: BoxShape3D
var _desk_mesh: BoxMesh
var _desk_mat: StandardMaterial3D
var _pc_scene: PackedScene
var _station_scene: PackedScene

@onready var level_root: Node3D = $Level

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
	Game.game_started.connect(_setup_level)

func _setup_level() -> void:
	for child in level_root.get_children():
		child.free()
	_spawn_stations()
	var positions: Array = _desk_positions().slice(0, Game.task_count)
	for i in positions.size():
		var pos: Vector3 = positions[i]
		_spawn_desk(pos)
		var task: Dictionary = Game.current_tasks[i]
		var pc: Node = _pc_scene.instantiate()
		pc.pc_id = task.id
		pc.symptom = task.symptom
		pc.fail_type = task.fail
		pc.fail_type2 = task.fail2
		pc.fail_variant = task.variant
		pc.fail_variant2 = task.variant2
		pc.position = pos + Vector3(0, 1.6, 0)
		level_root.add_child(pc)

func _spawn_stations() -> void:
	for part_type in STATION_POSITIONS:
		var station: Node = _station_scene.instantiate()
		station.part_type = part_type
		station.position = STATION_POSITIONS[part_type]
		level_root.add_child(station)

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