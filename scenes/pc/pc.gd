extends Interactable

@export var pc_id := 0
@export var symptom := ""
@export_enum("ram", "hdd", "psu", "gpu", "mb", "cpu", "fan") var fail_type := "ram"
@export var fail_type2 := ""
@export var fail_variant := ""
@export var fail_variant2 := ""
# Tipo de daño (volt/quemada/normal) y cómo arreglarlo (soldar/cambiar).
@export var fail_fault := ""
@export var fail_fault2 := ""
@export var fail_fix := ""
@export var fail_fix2 := ""

var repair_state: Dictionary = {}

@onready var highlight: MeshInstance3D = $Highlight

func _ready() -> void:
	super()
	prompt_text = "Reparar PC %d" % pc_id
	highlight.visible = false
	Game.task_completed.connect(_on_completed)

func _on_completed(pc_id: int) -> void:
	if pc_id != self.pc_id:
		return
	visible = false
	highlight.visible = false
	await get_tree().create_timer(5.0).timeout
	if not is_inside_tree():
		return
	_apply_new_task()

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
	prompt_text = "Reparar PC %d" % pc_id
	visible = true

func interact(_player: Node3D) -> void:
	super(_player)
	if pc_id in Game.repaired:
		return
	Game.hud.open_minigame(self)

func set_highlighted(on: bool) -> void:
	highlight.visible = on