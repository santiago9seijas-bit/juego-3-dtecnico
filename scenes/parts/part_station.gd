class_name RepairStation
extends Interactable

@export var part_type := "ram"

@onready var label: Label3D = $Label
@onready var highlight_mesh: MeshInstance3D = $Highlight

func _ready() -> void:
	super()
	var title: String = Game.part_title(part_type)
	prompt_text = "Buscar %s" % title
	label.text = title
	if Game.uses_server_room():
		# Los nombres del servidor son más largos que los del taller; un
		# rótulo pequeño sigue entrando completo junto a las cajas.
		label.font_size = 30
		label.outline_size = 6
	highlight_mesh.visible = false

func interact(_player: Node3D) -> void:
	super(_player)
	if Game.uses_server_room():
		var required := Game.server_current_part()
		if required != "" and part_type != required:
			if Game.hud:
				Game.hud.show_message("Primero instala: %s" % Game.part_title(required))
			return
	if Game.hud:
		Game.hud.open_picker(part_type)

func set_highlighted(on: bool) -> void:
	highlight_mesh.visible = on
