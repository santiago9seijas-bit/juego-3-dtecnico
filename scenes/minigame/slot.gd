class_name RepairSlot
extends PanelContainer

signal part_dropped(slot: RepairSlot, data: Dictionary)
signal remove_requested(slot: RepairSlot)
signal examine_requested(slot: RepairSlot)

@export var slot_type := "ram"

var part: Dictionary = {}
var revealed := false

@onready var title_label: Label = $VBox/TitleLabel
@onready var part_label: Label = $VBox/PartLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var remove_button: Button = $VBox/RemoveButton
@onready var examine_button: Button = $VBox/ExamineButton

func _ready() -> void:
	remove_button.pressed.connect(func() -> void: remove_requested.emit(self))
	examine_button.pressed.connect(func() -> void: examine_requested.emit(self))

func set_part(new_part: Dictionary) -> void:
	if new_part.is_empty():
		part = {}
		_refresh()
		return
	part = {
		"name": new_part.get("name", ""),
		"type": new_part.get("type", slot_type),
		"good": new_part.get("good", true),
	}
	_refresh()

func clear_part() -> void:
	part = {}
	_refresh()

func set_revealed(new_value: bool) -> void:
	revealed = new_value
	_refresh()

func is_empty() -> bool:
	return part.is_empty()

func has_broken_part() -> bool:
	return not part.is_empty() and not part.get("good", true)

func _refresh() -> void:
	if part.is_empty():
		part_label.text = "- -"
		part_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		status_label.text = "espacio libre"
		status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		remove_button.visible = false
		examine_button.visible = false
	else:
		remove_button.visible = true
		examine_button.visible = true
		if not revealed:
			part_label.text = "?"
			part_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
			status_label.text = "?"
			status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		else:
			part_label.text = str(part.name)
			part_label.add_theme_color_override("font_color", Color.WHITE)
			if part.get("good", true):
				status_label.text = "OK"
				status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
			else:
				status_label.text = "DAÑADA"
				status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	part_dropped.emit(self, data)