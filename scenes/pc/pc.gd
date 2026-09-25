extends Interactable

@export var pc_id := 0
@export var symptom := ""
@export_enum("ram", "hdd", "psu", "gpu", "mb", "cpu", "fan", "liquid") var fail_type := "ram"
@export var fail_type2 := ""
@export var fail_variant := ""
@export var fail_variant2 := ""
# Tipo de daño (volt/quemada/normal) y cómo arreglarlo (soldar/cambiar).
@export var fail_fault := ""
@export var fail_fault2 := ""
@export var fail_fix := ""
@export var fail_fix2 := ""

var repair_state: Dictionary = {}
# En el mundo de servidores una sola torre contiene las seis tareas.
var server_assembly := false

@onready var highlight: MeshInstance3D = $Highlight
@onready var body_collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	super()
	prompt_text = "Reparar PC %d" % pc_id
	highlight.visible = false
	Game.task_completed.connect(_on_completed)

# En la sala de servidores este nodo es la única torre. Se ocultan la
# carcasa y la pantalla de PC, pero conserva una colisión grande para poder
# abrir el mismo minijuego de reparación en cada componente.
func set_server_tower_mode() -> void:
	server_assembly = true
	var case_mesh := get_node_or_null("Case") as MeshInstance3D
	var screen_mesh := get_node_or_null("Screen") as MeshInstance3D
	if case_mesh:
		case_mesh.visible = false
	if screen_mesh:
		screen_mesh.visible = false
	if body_collision:
		var source_shape := body_collision.shape as BoxShape3D
		if source_shape:
			# Duplica la forma para no cambiar la colisión de los PCs del
			# taller que comparten el recurso de la escena.
			var tower_shape: BoxShape3D = source_shape.duplicate() as BoxShape3D
			tower_shape.size = Vector3(2.0, 2.8, 0.8)
			body_collision.shape = tower_shape

func _on_completed(pc_id: int) -> void:
	if pc_id != self.pc_id:
		return
	if Game.uses_server_room() and server_assembly:
		# La torre permanece en la sala: cada instalación avanza al siguiente
		# componente. Solo desaparece después del quinto.
		if pc_id >= Game.task_count:
			visible = false
			highlight.visible = false
			if body_collision:
				body_collision.disabled = true
		else:
			_advance_server_task()
		return
	visible = false
	highlight.visible = false
	await get_tree().create_timer(5.0).timeout
	if not is_inside_tree():
		return
	_apply_new_task()

func _advance_server_task() -> void:
	var next_id := pc_id + 1
	if next_id > Game.task_count:
		return
	var task: Dictionary = Game.current_tasks[next_id - 1]
	pc_id = int(task.get("id", next_id))
	symptom = str(task.get("symptom", ""))
	fail_type = str(task.get("fail", "ram"))
	fail_type2 = str(task.get("fail2", ""))
	fail_variant = str(task.get("variant", ""))
	fail_variant2 = str(task.get("variant2", ""))
	fail_fault = str(task.get("fault", ""))
	fail_fix = str(task.get("fix", ""))
	fail_fault2 = str(task.get("fault2", ""))
	fail_fix2 = str(task.get("fix2", ""))
	repair_state.clear()
	if body_collision:
		body_collision.disabled = false
	prompt_text = "Armar %s" % Game.part_title(fail_type)
	highlight.visible = false
	visible = true

func _apply_new_task() -> void:
	var task: Dictionary = Game.new_task()
	pc_id = task.id
	symptom = task.symptom
	fail_type = task.fail
	fail_type2 = task.fail2
	fail_variant = task.variant
	fail_variant2 = task.variant2
	fail_fault = task.get("fault", "")
	fail_fault2 = task.get("fault2", "")
	fail_fix = task.get("fix", "")
	fail_fix2 = task.get("fix2", "")
	repair_state.clear()
	if body_collision:
		body_collision.disabled = false
	prompt_text = "Reparar PC %d" % pc_id
	visible = true

func interact(_player: Node3D) -> void:
	super(_player)
	if pc_id in Game.repaired:
		return
	Game.hud.open_minigame(self)

func set_highlighted(on: bool) -> void:
	# La torre se gestiona con el prompt y los LEDs; el highlight
	# rectangular de PC la haría parecer una pieza ya instalada.
	highlight.visible = false if Game.uses_server_room() and server_assembly else on