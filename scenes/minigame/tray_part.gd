class_name RepairPart
extends PanelContainer

var part_name := ""
var part_type := ""
var good := true

var part_data: Dictionary = {}

func setup(p_name: String, p_type: String, is_good: bool) -> void:
	part_name = p_name
	part_type = p_type
	good = is_good
	part_data = {"name": p_name, "type": p_type, "good": is_good}

	var label := Label.new()
	label.text = p_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.45, 0.25) if is_good else Color(0.5, 0.2, 0.2)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.9, 0.9, 0.9)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = part_name
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	return part_data
