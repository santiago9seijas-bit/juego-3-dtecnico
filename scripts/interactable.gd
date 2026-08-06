class_name Interactable
extends StaticBody3D

signal interacted

var prompt_text := "Interactuar"

func _ready() -> void:
	add_to_group("interactables")

func interact(_player: Node3D) -> void:
	interacted.emit()

func set_highlighted(_on: bool) -> void:
	pass