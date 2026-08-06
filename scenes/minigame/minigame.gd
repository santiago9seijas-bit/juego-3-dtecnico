extends PanelContainer

signal repaired(pc_id: int)

const SLOT_INFO := {
	"ram": {"title": "RAM", "good": "Memoria RAM 8GB", "bad": "RAM quemada"},
	"hdd": {"title": "Disco Duro", "good": "Disco SSD 1TB", "bad": "Disco con sectores dañados"},
	"psu": {"title": "Fuente", "good": "Fuente 550W", "bad": "Fuente quemada"},
	"gpu": {"title": "Grafica", "good": "Grafica GTX 3060", "bad": "Grafica dañada"},
	"mb": {"title": "Placa Madre", "good": "Placa B550", "bad": "Placa con circuito quemado"},
	"cpu": {"title": "Procesador", "good": "Procesador i5-12400", "bad": "Procesador dañado"},
	"fan": {"title": "Fancooler", "good": "Fancooler 120mm", "bad": "Fancooler atascado"},
}
const SLOT_ORDER := ["ram", "hdd", "psu", "gpu", "mb", "cpu", "fan"]

const HELP_TEXT := "1. Lee el SINTOMA de la PC.\n2. Presiona EXAMINAR en un slot para ver si la pieza esta DAÑADA y que modelo necesita (tienes examinaciones limitadas).\n3. Consigue el repuesto correcto en la estacion de su tipo.\n4. Arrastra el repuesto al slot dañado; se abre un mini juego (deslizar / tornillos con teclas 1-2).\n5. Puedes sacar o poner cualquier pieza con el boton SACAR.\n6. Repara todos los slots para ganar puntos y tiempo."

var current_pc: Node = null
var fail_types: Array = []
var remaining := 0
var _slot_nodes: Dictionary = {}
var _expected: Dictionary = {}
var _examines_left := 4

@onready var symptom_label: Label = %SymptomLabel
@onready var tray: VBoxContainer = %Tray
@onready var feedback_label: Label = %FeedbackLabel
@onready var result_label: Label = %ResultLabel
@onready var close_button: Button = %CloseButton
@onready var examine_left_label: Label = %ExamineLeftLabel
@onready var help_button: Button = %HelpButton
@onready var help_panel: PanelContainer = %HelpPanel
@onready var help_close_button: Button = %HelpCloseButton
@onready var help_rich: RichTextLabel = %HelpRich

func _exam_limit() -> int:
	return Game.examine_limit()

func _ready() -> void:
	for t in SLOT_ORDER:
		var slot: RepairSlot = get_node("Margin/VBox/Slots/Slot%s" % t.to_upper())
		slot.slot_type = t
		slot.part_dropped.connect(_on_part_dropped)
		slot.remove_requested.connect(_on_remove_requested)
		slot.examine_requested.connect(_on_examine_requested)
		_slot_nodes[t] = slot
	close_button.pressed.connect(_close)
	help_button.pressed.connect(_toggle_help)
	help_close_button.pressed.connect(func() -> void: help_panel.visible = false)
	help_rich.text = HELP_TEXT

func setup(pc: Node) -> void:
	current_pc = pc
	fail_types = [pc.fail_type]
	if "fail_type2" in pc and pc.fail_type2 != "":
		fail_types.append(pc.fail_type2)
	_expected.clear()
	for t in fail_types:
		var vname: String = ""
		if t == pc.fail_type and "fail_variant" in pc:
			vname = pc.fail_variant
		elif t != pc.fail_type and "fail_variant2" in pc:
			vname = pc.fail_variant2
		if vname == "":
			vname = Game.PART_VARIANTS[t][0].name
		_expected[t] = {"name": vname, "type": t}
	symptom_label.text = pc.symptom
	feedback_label.text = "Examina las piezas para saber cuál está dañada y qué modelo necesita."
	feedback_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	result_label.text = ""
	for t in _slot_nodes:
		_slot_nodes[t].set_revealed(false)
	if pc.repair_state.has(pc.pc_id):
		_load_state(pc.repair_state[pc.pc_id])
	else:
		_reset_slots()
		_save_state()
	_update_remaining()
	_build_tray()
	_examines_left = _exam_limit()
	help_panel.visible = false
	_refresh_examine_label()
	visible = true

func _save_state() -> void:
	var snap: Dictionary = {}
	for t in SLOT_ORDER:
		var slot: RepairSlot = _slot_nodes[t]
		snap[t] = {"revealed": slot.revealed, "part": slot.part}
	current_pc.repair_state[current_pc.pc_id] = snap

func _load_state(snap: Dictionary) -> void:
	for t in SLOT_ORDER:
		var slot: RepairSlot = _slot_nodes[t]
		if t in snap:
			slot.set_part(snap[t].part)
			slot.set_revealed(snap[t].revealed)
		else:
			if t in fail_types:
				var v: Dictionary = _expected[t]
				slot.set_part({"name": v.name, "type": t, "good": false})
			else:
				slot.set_part({"name": SLOT_INFO[t].good, "type": t, "good": true})

func _reset_slots() -> void:
	for t in SLOT_ORDER:
		var slot: RepairSlot = _slot_nodes[t]
		if t in fail_types:
			var v: Dictionary = _expected[t]
			slot.set_part({"name": v.name, "type": t, "good": false})
		else:
			slot.set_part({"name": SLOT_INFO[t].good, "type": t, "good": true})

func _update_remaining() -> void:
	remaining = fail_types.size()
	for t in fail_types:
		var slot: RepairSlot = _slot_nodes[t]
		var expected: Dictionary = _expected[t]
		if not slot.part.is_empty() and slot.part.get("name", "") == expected.name and slot.has_broken_part() == false:
			remaining -= 1

func _build_tray() -> void:
	for child in tray.get_children():
		child.free()
	for data in Game.carried_parts:
		_add_part(data)

func _add_part(data: Dictionary) -> void:
	var part := RepairPart.new()
	part.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	part.custom_minimum_size = Vector2(0, 64)
	part.setup(data.name, data.type, data.get("good", true))
	tray.add_child(part)

func _refresh_examine_label() -> void:
	var limit := _exam_limit()
	if _examines_left <= 0:
		examine_left_label.text = "Examinaciones agotadas. Repara una PC bien para recargar."
		examine_left_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	else:
		examine_left_label.text = "Examinaciones restantes: %d / %d" % [_examines_left, limit]
		examine_left_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1))

func _toggle_help() -> void:
	help_panel.visible = not help_panel.visible

func _on_examine_requested(slot: RepairSlot) -> void:
	if remaining <= 0:
		return
	if slot.revealed:
		feedback_label.text = "Este slot ya lo revisaste." 
		feedback_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
		return
	if _examines_left <= 0:
		feedback_label.text = "Te quedaste sin examinaciones. Repara una PC correctamente para recargarlas."
		feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		return
	_examines_left -= 1
	_refresh_examine_label()
	slot.set_revealed(true)
	var title: String = SLOT_INFO[slot.slot_type].title
	if slot.has_broken_part():
		feedback_label.text = "%s está DAÑADA. Necesitas: %s — búscalo en la estantería de %s. (Quedan %d examinaciones)" % [title, slot.part.name, title, _examines_left]
		feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	else:
		feedback_label.text = "%s está bien, no necesita cambio. (Quedan %d examinaciones)" % [title, _examines_left]
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))

func _expected_for(slot_type: String) -> Dictionary:
	if slot_type in _expected:
		return _expected[slot_type]
	return {"name": SLOT_INFO[slot_type].good, "type": slot_type}

func _on_part_dropped(slot: RepairSlot, data: Dictionary) -> void:
	if remaining <= 0:
		return
	var expected: Dictionary = _expected_for(slot.slot_type)
	if data.name != expected.name:
		if Game.hud:
			Game.hud.open_removal(slot.slot_type, _finish_wrong_install.bind(slot, data, expected.name), true)
			return
		_finish_wrong_install(slot, data, expected.name)
		return
	if slot.part.get("good", false) and slot.part.get("name", "") == expected.name:
		_miss("Ese slot ya está reparado.")
		return
	if Game.hud:
		Game.hud.open_removal(slot.slot_type, _finish_install.bind(slot, data), true)
		return
	_finish_install(slot, data)

func _finish_install(slot: RepairSlot, data: Dictionary) -> void:
	slot.set_part(data)
	_consume_part(data)
	_update_remaining()
	if slot.slot_type in fail_types:
		_examines_left = _exam_limit()
		_refresh_examine_label()
	if remaining <= 0:
		feedback_label.text = "¡Reparado!"
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		result_label.text = "TAREA COMPLETADA"
		result_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		Game.mark_repaired(current_pc.pc_id)
		repaired.emit(current_pc.pc_id)
		get_tree().create_timer(1.2).timeout.connect(_close)
	else:
		feedback_label.text = "Bien. Sigue reparando las piezas dañadas."
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))

func _finish_wrong_install(slot: RepairSlot, data: Dictionary, expected_name: String) -> void:
	slot.set_part(data)
	_consume_part(data)
	Game.penalize()
	_miss("Repuesto incorrecto. Pierdes tiempo y puntos. Sácalo e instala el correcto: %s." % expected_name)

func _on_remove_requested(slot: RepairSlot) -> void:
	if remaining <= 0:
		return
	if slot.is_empty():
		_info("Ese slot está vacío, no hay nada que sacar.")
		return
	if Game.hud:
		Game.hud.open_removal(slot.slot_type, _finish_removal.bind(slot))
		return
	_finish_removal(slot)

func _finish_removal(slot: RepairSlot) -> void:
	slot.clear_part()
	_update_remaining()
	feedback_label.text = "Pieza retirada. Arrastra el repuesto correcto al slot."
	feedback_label.add_theme_color_override("font_color", Color(1, 0.8, 0.4))

func _consume_part(data: Dictionary) -> void:
	for child in tray.get_children():
		var part := child as RepairPart
		if part and part.part_data == data:
			part.queue_free()
			break
	Game.remove_carried(data)

func _info(text: String) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))

func _miss(text: String) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))

func _close() -> void:
	if current_pc:
		_save_state()
	visible = false
	Game.is_minigame_open = false