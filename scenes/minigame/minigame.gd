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

const HELP_TEXT := "1. Lee el SINTOMA de la PC.\n2. Presiona EXAMINAR en un slot para ver si la pieza esta DAÑADA y que modelo necesita (tienes examinaciones limitadas).\n   Al examinar, una pieza con SOBRETENSIÓN brilla en MORADO y una QUEMADA brilla en NEGRO.\n3. Si el slot dice SOLDAR, elige como arreglarla: SOLDAR directo (si te saliste 3 veces, la pieza queda INSALVABLE) o VOLTAJE (mides los rieles con el voltímetro y luego sueldas sin riesgo).\n4. Si hay que cambiarla, consigue el repuesto correcto en la estacion de su tipo.\n5. Arrastra el repuesto al slot dañado; se abre un mini juego (deslizar / tornillos con teclas 1-2).\n6. Puedes sacar o poner cualquier pieza con el boton SACAR.\n7. Repara todos los slots para ganar puntos y tiempo."

var current_pc: Node = null
var fail_types: Array = []
var remaining := 0
var _slot_nodes: Dictionary = {}
var _expected: Dictionary = {}
var _examines_left := 4
# Cada apertura de una PC invalida los retardos de la apertura anterior.
# Así reiniciar el nivel no puede cerrar el minijuego de otra PC.
var _setup_generation := 0
var _liquid_board: LiquidCoolingMinigame = null

@onready var title_label: Label = $Margin/VBox/Title
@onready var symptom_label: Label = %SymptomLabel
@onready var tray_label: Label = $Margin/VBox/TrayLabel
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

# Lee una propiedad de la PC si existe (los tests crean PCs a mano).
func _prop(node: Node, key: String) -> String:
	if key in node:
		var v = node.get(key)
		return str(v) if v != null else ""
	return ""

func _is_server_assembly() -> bool:
	return Game.uses_server_room() and is_instance_valid(current_pc) and bool(current_pc.get("server_assembly"))

func _is_liquid_game() -> bool:
	if not is_instance_valid(current_pc) or not ("fail_type" in current_pc):
		return false
	return str(current_pc.get("fail_type")) == "liquid" and (_is_server_assembly() or Game.tutorial_mode)

func _ready() -> void:
	for t in SLOT_ORDER:
		var slot: RepairSlot = get_node("Margin/VBox/Slots/Slot%s" % t.to_upper())
		slot.slot_type = t
		slot.part_dropped.connect(_on_part_dropped)
		slot.remove_requested.connect(_on_remove_requested)
		slot.examine_requested.connect(_on_examine_requested)
		slot.repair_requested.connect(_on_repair_requested)
		slot.measure_first_requested.connect(_on_measure_first)
		slot.title_label.text = Game.part_title(t)
		_slot_nodes[t] = slot
	close_button.pressed.connect(_close)
	help_button.pressed.connect(_toggle_help)
	help_close_button.pressed.connect(func() -> void: help_panel.visible = false)
	help_rich.text = HELP_TEXT
	_style_help_button()

# La ayuda de la máquina se ve como una bolita "?" con halo neón que
# late despacio, para que la encuentres sin leer nada.
func _style_help_button() -> void:
	help_button.pivot_offset = Vector2(24.0, 24.0)
	var normal := _help_box(Color("0a0f16"), UiStyle.CYAN, 0.35)
	help_button.add_theme_stylebox_override("normal", normal)
	help_button.add_theme_stylebox_override("hover", _help_box(Color("141f33"), UiStyle.MAGENTA, 0.8))
	help_button.add_theme_stylebox_override("pressed", _help_box(Color("05090f"), UiStyle.CYAN_SOFT, 0.5))
	help_button.add_theme_color_override("font_color", UiStyle.CYAN_SOFT)
	help_button.add_theme_color_override("font_hover_color", Color.WHITE)
	help_button.add_theme_font_override("font", UiStyle.neon_font(0.1, 0.32))
	var tween := help_button.create_tween().set_loops()
	tween.tween_property(help_button, "scale", Vector2(1.15, 1.15), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(normal, "shadow_color",
		Color(UiStyle.MAGENTA.r, UiStyle.MAGENTA.g, UiStyle.MAGENTA.b, 0.8), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(help_button, "scale", Vector2.ONE, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(normal, "shadow_color",
		Color(UiStyle.CYAN.r, UiStyle.CYAN.g, UiStyle.CYAN.b, 0.35), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _help_box(bg: Color, border: Color, glow_alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(24)
	box.set_border_width_all(2)
	box.border_color = border
	box.shadow_size = 10
	box.shadow_color = Color(border.r, border.g, border.b, glow_alpha)
	return box

func setup(pc: Node) -> void:
	_setup_generation += 1
	current_pc = pc
	title_label.visible = true
	symptom_label.visible = true
	feedback_label.visible = true
	examine_left_label.visible = true
	result_label.visible = true
	_clear_liquid_board()
	get_node("Margin/VBox/Slots").visible = true
	tray_label.text = "TUS REPUESTOS (arrastra el modelo correcto al slot dañado)"
	tray_label.visible = true
	tray.visible = true
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
			vname = Game.part_default_name(t)
		_expected[t] = {"name": vname, "type": t}
	if _is_liquid_game():
		_setup_liquid_cooling()
		return
	for t in _slot_nodes:
		_slot_nodes[t].title_label.text = Game.part_title(t)
	# Tipo de daño de cada slot: decide el brillo al examinar y si se
	# arregla con el cautín (SOLDAR) o cambiando la pieza.
	for t in _slot_nodes:
		var fault := "swap"
		var fix := "swap"
		if t in fail_types:
			if t == pc.fail_type:
				fault = _prop(pc, "fail_fault")
				fix = _prop(pc, "fail_fix")
			else:
				fault = _prop(pc, "fail_fault2")
				fix = _prop(pc, "fail_fix2")
		_slot_nodes[t].set_fault(fault, fix)
	if _is_server_assembly():
		title_label.text = "ARMADO DEL SERVIDOR"
		help_rich.text = "1. Lee el SÍNTOMA de la torre.\n2. Elige el modelo del siguiente componente en su caja.\n3. Arrástralo al hueco vacío que dice INSTALAR AQUÍ.\n4. Al terminar, la torre pasa al siguiente hueco."
	else:
		title_label.text = "REPARACION DE COMPUTADORA"
		help_rich.text = HELP_TEXT
	symptom_label.text = pc.symptom
	feedback_label.text = "Elige el modelo del siguiente componente y arrástralo al hueco INSTALAR AQUÍ." if _is_server_assembly() else "Examina las piezas para saber cuál está dañada y qué modelo necesita."
	feedback_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	result_label.text = ""
	for t in _slot_nodes:
		_slot_nodes[t].set_revealed(false)
	if _is_server_assembly():
		# La torre se reconstruye desde las piezas ya instaladas; no se
		# guarda un estado de PC tradicional entre tiradas.
		_reset_slots()
	elif pc.repair_state.has(pc.pc_id):
		_load_state(pc.repair_state[pc.pc_id])
	else:
		_reset_slots()
		_save_state()
	_update_remaining()
	_build_tray()
	_examines_left = _exam_limit()
	help_panel.visible = false
	_apply_slot_scope()
	_refresh_examine_label()
	if _is_server_assembly():
		examine_left_label.text = "Componentes instalados: %d/%d" % [Game.server_installed_parts.size(), Game.task_count]
		examine_left_label.add_theme_color_override("font_color", UiStyle.CYAN_SOFT)
	visible = true

func _clear_liquid_board() -> void:
	if is_instance_valid(_liquid_board):
		var parent := _liquid_board.get_parent()
		if parent:
			parent.remove_child(_liquid_board)
		_liquid_board.queue_free()
	_liquid_board = null

func _setup_liquid_cooling() -> void:
	var slots_root := get_node("Margin/VBox/Slots") as Control
	slots_root.visible = false
	# El cuadro grande ya lleva su propio título y ayuda; ocultar los dos
	# encabezados del panel libera espacio para que CERRER quede visible.
	title_label.visible = false
	symptom_label.visible = false
	help_rich.text = "1. Arrastra el kit líquido al cuadro para aparezca el mapa térmico.\n2. Arrastra rectas, L, cruces y piezas CPU/RAM/ROM/GPU/PSU/MB; las rectas también cubren bloques.\n3. Pulsa GIRAR (o usa clic derecho, rueda o R) para cambiar la orientación.\n4. Usa QUITAR ÚLTIMA o clic derecho sobre una pieza colocada para corregir.\n5. Conecta desde IN hasta OUT, bota el líquido en IN y espera el 100%.\n6. Pulsa ENCENDER BOMBA."
	symptom_label.text = current_pc.symptom
	if Game.tutorial_mode:
		feedback_label.text = "Práctica: monta el circuito de refrigeración líquida del servidor."
	else:
		feedback_label.text = "El servidor necesita refrigeración líquida para terminar el armado."
	feedback_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	result_label.text = ""
	tray_label.text = "TUS REPUESTOS (arrastra el kit líquido al circuito)"
	tray_label.visible = true
	tray.visible = true
	if Game.tutorial_mode:
		examine_left_label.text = "PRÁCTICA · TUBERÍAS LÍQUIDAS"
	else:
		examine_left_label.text = "Componentes instalados: %d/%d" % [Game.server_installed_parts.size(), Game.task_count]
	examine_left_label.add_theme_color_override("font_color", UiStyle.CYAN_SOFT)
	help_panel.visible = false

	var vbox := get_node("Margin/VBox") as VBoxContainer
	var board := LiquidCoolingMinigame.new()
	board.name = "LiquidCoolingBoard"
	vbox.add_child(board)
	vbox.move_child(board, tray.get_index())
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.completed.connect(_on_liquid_completed)
	board.kit_placed.connect(_on_liquid_kit_placed)
	board.setup(str(_expected.get("liquid", {}).get("name", "")))
	_liquid_board = board
	_build_tray()
	visible = true

func _on_liquid_kit_placed() -> void:
	# El cuadro tiene sus propios mensajes y la barra; retiramos los duplicados
	# del panel para que CERRER siga visible en el minijuego grande.
	tray_label.visible = false
	tray.visible = false
	feedback_label.visible = false
	examine_left_label.visible = false
	result_label.visible = false


func _on_liquid_completed(data: Dictionary) -> void:
	if not _is_liquid_game() or not is_instance_valid(current_pc):
		return
	_consume_part(data)
	if data in Game.carried_parts:
		Game.remove_carried(data)
	var completed_id := int(current_pc.pc_id)
	Game.mark_repaired(completed_id)
	repaired.emit(completed_id)
	var server_done := Game.repaired.size() >= Game.task_count
	if Game.tutorial_mode:
		feedback_label.text = "Práctica de refrigeración líquida completada."
		result_label.text = "TUTORIAL DE TUBERÍAS COMPLETADO"
	else:
		feedback_label.text = "Servidor armado. Ahora falta configurar el servidor." if server_done else "Refrigeración líquida instalada."
		result_label.text = "SERVIDOR ARMADO" if server_done else "REFRIGERACIÓN LÍQUIDA INSTALADA"
	feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
	result_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
	var generation := _setup_generation
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if generation == _setup_generation and is_instance_valid(current_pc):
			_close()
	)

# En el tutorial solo se ve el hueco de la pieza que hay que arreglar,
# con la pieza dañada ya a la vista (sin necesidad de examinarla).
# En los niveles solo se ven las piezas que aparecen en ese nivel.
func _apply_slot_scope() -> void:
	var only := ""
	if Game.tutorial_mode and fail_types.size() == 1:
		only = fail_types[0]
	var parts: Array = Game.level_parts()
	for t in _slot_nodes:
		var slot: RepairSlot = _slot_nodes[t]
		var show_slot := true
		if only != "":
			show_slot = t == only
		elif not Game.tutorial_mode:
			show_slot = t in parts
		slot.visible = show_slot
	if only != "":
		_slot_nodes[only].set_revealed(true)

func _save_state() -> void:
	if _is_server_assembly():
		return
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
				slot.set_part({"name": Game.part_default_name(t), "type": t, "good": true})

func _reset_slots() -> void:
	for t in SLOT_ORDER:
		var slot: RepairSlot = _slot_nodes[t]
		if _is_server_assembly():
			if t in Game.server_installed_parts:
				slot.set_part({"name": Game.part_default_name(t), "type": t, "good": true})
				slot.set_revealed(true)
			else:
				slot.clear_part()
				slot.set_revealed(false)
				slot.set_install_target(t == str(current_pc.fail_type))
		elif t in fail_types:
			var v: Dictionary = _expected[t]
			slot.set_part({"name": v.name, "type": t, "good": false})
		else:
			slot.set_part({"name": Game.part_default_name(t), "type": t, "good": true})

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
	var title: String = Game.part_title(slot.slot_type)
	if slot.has_broken_part():
		var detail := ""
		if slot.fault == "volt":
			detail = " — SOBRETENSIÓN (brillo MORADO)"
		elif slot.fault == "burn":
			detail = " — QUEMADA (brillo NEGRO)"
		if slot.ruined:
			feedback_label.text = "%s quedó INSALVABLE (fallaste la soldadura sin medir). Hay que reemplazarla por %s — búscalo en la estantería de %s. (Quedan %d examinaciones)" % [title, slot.part.name, title, _examines_left]
			feedback_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif slot.can_solder():
			feedback_label.text = "%s está DAÑADA%s. Elige: SOLDAR directo (si te sales 3 veces se pierde) o VOLTAJE (mides y luego sueldas sin riesgo). (Quedan %d examinaciones)" % [title, detail, _examines_left]
			feedback_label.add_theme_color_override(
				"font_color",
				Color(0.82, 0.46, 1.0) if slot.fault == "volt" else Color(0.86, 0.86, 0.94)
			)
		else:
			feedback_label.text = "%s está DAÑADA%s. Necesitas: %s — búscalo en la estantería de %s. (Quedan %d examinaciones)" % [title, detail, slot.part.name, title, _examines_left]
			feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	else:
		feedback_label.text = "%s está bien, no necesita cambio. (Quedan %d examinaciones)" % [title, _examines_left]
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))

# Botón SOLDAR del slot: la pieza se repara con el cautín sin cambiarla.
# (Si te salías 3 veces sin haber medido, la pieza queda insalvable.)
func _on_repair_requested(slot: RepairSlot) -> void:
	if remaining <= 0:
		return
	if not slot.can_solder():
		return
	if Game.hud:
		Game.hud.open_removal(slot.slot_type, _finish_solder.bind(slot, false), false, "solder")
		return
	_finish_solder(slot, false)

# Botón VOLTAJE del slot: PRIMERO se miden los rieles y DESPUÉS se suelda
# (medir primero hace que un fallo al soldar no destruya la pieza).
func _on_measure_first(slot: RepairSlot) -> void:
	if remaining <= 0:
		return
	if not slot.can_solder():
		return
	if Game.hud:
		Game.hud.open_removal(slot.slot_type, _finish_solder.bind(slot, true), false, "volt_solder")
		return
	_finish_solder(slot, true)

func _finish_solder(slot: RepairSlot, measured := false) -> void:
	var ok := true
	if Game.hud:
		ok = Game.hud.removal_panel.last_solder_ok
	if not ok:
		if measured:
			# Al haber medido antes, la soldadura no daña la pieza: se reintenta.
			_info("La soldadura falló, pero como mediste los rieles la pieza sigue a salvo. Vuelve a pulsar VOLTAJE o SOLDAR.")
			return
		# Sin medir: la pieza queda dañada y NO se puede rescatar.
		slot.ruined = true
		slot.set_revealed(true)
		_miss("¡La soldadura salió mal! La pieza quedó INSALVABLE: habrá que reemplazarla por %s (estantería de %s)." % [slot.part.get("name", ""), slot.title_label.text])
		return
	var old: Dictionary = slot.part
	slot.set_part({
		"name": old.get("name", ""),
		"type": slot.slot_type,
		"good": true,
	})
	slot.set_revealed(true)
	_after_fix(slot, "¡Soldadura lista! Esa pieza quedó reparada sin cambiarla. Sigue con las demás.")

func _expected_for(slot_type: String) -> Dictionary:
	if slot_type in _expected:
		return _expected[slot_type]
	return {"name": Game.part_default_name(slot_type), "type": slot_type}

func _on_part_dropped(slot: RepairSlot, data: Dictionary) -> void:
	if remaining <= 0:
		return
	if _is_server_assembly() and slot.slot_type != str(current_pc.fail_type):
		_miss("El siguiente hueco es %s. Llena primero ese componente." % Game.part_title(str(current_pc.fail_type)))
		return
	if not data.get("good", true):
		_miss("Ese repuesto está DAÑADA: bóotalo en la papelera y toma uno bueno de la estantería.")
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
	var old: Dictionary = slot.part
	slot.set_part(data)
	_consume_part(data)
	_take_out_damaged(old)
	_after_fix(slot, "Bien. Sigue reparando las piezas dañadas.")

# Camino común al terminar una reparación (cambiando la pieza o soldando).
func _after_fix(slot: RepairSlot, next_text: String) -> void:
	_update_remaining()
	if slot.slot_type in fail_types:
		_examines_left = _exam_limit()
		_refresh_examine_label()
	if _is_server_assembly():
		var completed_id := int(current_pc.pc_id)
		Game.mark_repaired(completed_id)
		repaired.emit(completed_id)
		var server_done := Game.repaired.size() >= Game.task_count
		feedback_label.text = "Servidor armado. Ahora falta configurar el servidor." if server_done else "Componente instalado. El siguiente hueco está esperando."
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		result_label.text = "SERVIDOR ARMADO" if server_done else "COMPONENTE INSTALADO"
		result_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		var generation := _setup_generation
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if generation == _setup_generation and is_instance_valid(current_pc):
				_close()
		)
		return
	if remaining <= 0:
		feedback_label.text = "¡Reparado!"
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		result_label.text = "TAREA COMPLETADA"
		result_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		Game.mark_repaired(current_pc.pc_id)
		repaired.emit(current_pc.pc_id)
		var generation := _setup_generation
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if generation == _setup_generation and is_instance_valid(current_pc):
				_close()
		)
	else:
		feedback_label.text = next_text
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))

func _finish_wrong_install(slot: RepairSlot, data: Dictionary, expected_name: String) -> void:
	var old: Dictionary = slot.part
	slot.set_part(data)
	_consume_part(data)
	_take_out_damaged(old)
	Game.penalize()
	_miss("Repuesto incorrecto. Pierdes tiempo y puntos. Sácalo e instala el correcto: %s." % expected_name)

func _on_remove_requested(slot: RepairSlot) -> void:
	if remaining <= 0:
		return
	if _is_server_assembly() and slot.slot_type in Game.server_installed_parts:
		_info("Ese componente ya está instalado en el servidor.")
		return
	if slot.is_empty():
		_info("Ese slot está vacío, no hay nada que sacar.")
		return
	if slot.has_broken_part() and Game.carried_parts.size() >= Game.MAX_CARRIED:
		_miss("Mochila llena: bota la pieza dañada a la papelera para poder sacar esta pieza.")
		return
	if Game.hud:
		Game.hud.open_removal(slot.slot_type, _finish_removal.bind(slot))
		return
	_finish_removal(slot)

func _finish_removal(slot: RepairSlot) -> void:
	var old: Dictionary = slot.part
	slot.clear_part()
	_take_out_damaged(old)
	_update_remaining()
	feedback_label.text = "Pieza retirada. Arrastra el repuesto correcto al slot."
	feedback_label.add_theme_color_override("font_color", Color(1, 0.8, 0.4))

# La pieza dañada que sale del slot queda en la mochila marcada como
# dañada: hay que botarla a la papelera para seguir cargando repuestos.
func _take_out_damaged(old: Dictionary) -> void:
	if old.is_empty() or old.get("good", true):
		return
	if not Game.add_damaged(old):
		return
	_build_tray()
	if Game.hud:
		Game.hud.show_message("Pieza dañada en la mochila: bóotala en la papelera.")

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
	if is_instance_valid(current_pc):
		_save_state()
	visible = false
	Game.is_minigame_open = false