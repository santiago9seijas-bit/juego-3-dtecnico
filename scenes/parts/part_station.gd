class_name RepairStation
extends Interactable

@export var part_type := "ram"

@onready var label: Label3D = $Label
@onready var highlight_mesh: MeshInstance3D = $Highlight

func _ready() -> void:
	super()
	var title: String = Game.PART_TITLES.get(part_type, part_type)
	prompt_text = "Buscar %s" % title
	label.text = title
	highlight_mesh.visible = false

func interact(_player: Node3D) -> void:
	super(_player)
	if Game.hud:
		Game.hud.open_picker(part_type)

func set_highlighted(on: bool) -> void:
	highlight_mesh.visible = on
