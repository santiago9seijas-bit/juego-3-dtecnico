class_name ServerSetupMinigame
extends VBoxContainer

# Configuración directa del servidor, sin dispositivos extra:
#   1) cables de la torre hacia la computadora;
#   2) conexiones de puertos;
#   3) programación de la secuencia de arranque.
# Cada etapa es un minijuego distinto y la torre solo termina cuando las
# tres quedan completadas.

signal finished

const OK_COLOR := Color(0.3, 1.0, 0.5)
const MISS_COLOR := Color(1.0, 0.42, 0.42)
const CABLE_COLOR := Color(1.0, 0.7, 0.15)
const PORT_COLOR := Color(0.45, 0.85, 1.0)
const CODE_COLOR := Color(0.72, 0.5, 1.0)

var pc_id := 0
var state: Dictionary = {}
var _stage_holder: VBoxContainer
var _status: Label
var _stage_index := 0
var _emitted := false
var _cable_sources := {}
var _cable_targets := {}
var _cable_done := {}
var _port_sources := {}
var _port_targets := {}
var _port_done := {}
var _programming: ProgrammingBoard = null
var _programs: Array[String] = []

class LinkEndpoint:
	extends PanelContainer
	signal linked(item_id: String)

	var group_id := ""
	var item_id := ""
	var side := "source"
	var connected_state := false
	var label: Label

	func setup(new_group: String, new_item: String, new_side: String, text: String, accent: Color) -> void:
		group_id = new_group
		item_id = new_item
		side = new_side
		custom_minimum_size = Vector2(190, 48)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.1, 0.15, 0.95)
		style.border_color = accent
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		add_theme_stylebox_override("panel", style)
		label = Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", accent)
		add_child(label)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if side != "source" or connected_state:
			return null
		var preview := Label.new()
		preview.text = "CABLE / CONECTOR"
		preview.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		set_drag_preview(preview)
		return {"group": group_id, "item": item_id, "side": "source"}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if connected_state or not (data is Dictionary):
			return false
		var payload: Dictionary = data
		return str(payload.get("group", "")) == group_id \
			and str(payload.get("item", "")) == item_id \
			and str(payload.get("side", "")) == "source"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not _can_drop_data(Vector2.ZERO, data):
			return
		mark_connected()
		linked.emit(item_id)

	func mark_connected() -> void:
		if connected_state:
			return
		connected_state = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if label:
			label.text = "✓ " + label.text
			label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))

class ProgrammingBoard:
	extends VBoxContainer
	signal completed

	const COMMANDS := [
		"INSTALAR SISTEMA",
		"ACTIVAR RED",
		"MONTAR ALMACEN",
		"CONFIGURAR BACKUP",
		"ARRANCAR SERVICIOS",
	]
	var _expected := [
		"INSTALAR SISTEMA",
		"ACTIVAR RED",
		"MONTAR ALMACEN",
		"CONFIGURAR BACKUP",
		"ARRANCAR SERVICIOS",
	]
	var _next := 0
	var _status: Label
	var _progress: Label

	func setup() -> void:
		add_theme_constant_override("separation", 8)
		var hint := Label.new()
		hint.text = "Ordena los comandos para encender el servidor y habilitar sus servicios."
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", UiStyle.TEXT)
		add_child(hint)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 8)
		add_child(grid)
		for command in ["ARRANCAR SERVICIOS", "MONTAR ALMACEN", "INSTALAR SISTEMA", "CONFIGURAR BACKUP", "ACTIVAR RED"]:
			var button := Button.new()
			button.text = str(command)
			button.custom_minimum_size = Vector2(230, 42)
			button.pressed.connect(_choose.bind(str(command)))
			grid.add_child(button)
		_progress = Label.new()
		_progress.text = " PROGRESO: 0/5"
		_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_progress.add_theme_color_override("font_color", Color(0.72, 0.5, 1.0))
		add_child(_progress)
		_status = Label.new()
		_status.text = "Pulsa los comandos en el orden correcto."
		_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_status.add_theme_font_size_override("font_size", 14)
		_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		add_child(_status)

	func _choose(command: String) -> void:
		if _next >= _expected.size():
			return
		if command != _expected[_next]:
			_status.text = "Ese comando va después de %s." % _expected[_next]
			_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
			return
		_next += 1
		_progress.text = " PROGRESO: %d/%d" % [_next, _expected.size()]
		_status.text = "Comando aceptado: %s" % command
		_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
		if _next >= _expected.size():
			_status.text = " PROGRAMA DEL SERVIDOR CORRECTO"
			completed.emit()

	func complete_for_test() -> void:
		while _next < _expected.size():
			_choose(_expected[_next])

func setup(new_state: Dictionary, task: Dictionary, new_pc_id := 0) -> void:
	pc_id = new_pc_id
	state = new_state if new_state != null else {}
	_programs.clear()
	var configured_programs: Array = task.get("programs", Game.SERVER_PROGRAMS) if task != null else Game.SERVER_PROGRAMS
	for program: Variant in configured_programs:
		_programs.append(str(program))
	if _programs.is_empty():
		for program: Variant in Game.SERVER_PROGRAMS:
			_programs.append(str(program))
	_emitted = false
	_stage_index = 0
	if bool(state.get("cables_done", false)):
		_stage_index = 1
	if bool(state.get("ports_done", false)):
		_stage_index = 2
	if bool(state.get("programming_done", false)):
		_stage_index = 3
	add_theme_constant_override("separation", 8)
	for child in get_children():
		child.queue_free()
	add_child(SwUI.section_header("CONFIGURACIÓN DIRECTA DEL SERVIDOR", CODE_COLOR))
	add_child(SwUI.label("El servidor está armado. Configúralo aquí mismo: cables, puertos y programación.", 16, UiStyle.TEXT))
	add_child(SwUI.steps([
		{"n": 1, "text": "Conecta los cables de la torre con la computadora."},
		{"n": 2, "text": "Conecta los puertos de red, datos y administración."},
		{"n": 3, "text": "Ejecuta la secuencia que instala y activa los programas del servidor."},
	]))
	_stage_holder = VBoxContainer.new()
	_stage_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_stage_holder)
	_status = SwUI.label("", 15, UiStyle.TEXT_DIM)
	add_child(_status)
	_show_stage()

func refresh_usb() -> void:
	# La configuración es directa; se conserva el método por compatibilidad.
	pass

func _show_stage() -> void:
	if _stage_holder == null:
		return
	for child in _stage_holder.get_children():
		child.queue_free()
	_cable_sources.clear()
	_cable_targets.clear()
	_cable_done.clear()
	_port_sources.clear()
	_port_targets.clear()
	_port_done.clear()
	_programming = null
	if _stage_index >= 3:
		_set_status("CONFIGURACIÓN COMPLETA · servidor listo", OK_COLOR)
		_schedule_finish()
		return
	if _stage_index == 0:
		_build_cable_stage()
	elif _stage_index == 1:
		_build_port_stage()
	else:
		_build_programming_stage()

func _build_cable_stage() -> void:
	_stage_holder.add_child(_stage_title("1 · CABLES EXTERNOS TORRE → PC", CABLE_COLOR))
	_stage_holder.add_child(SwUI.label("Arrastra cada cable externo de la torre hasta el conector del mismo nombre en la PC.", 14, UiStyle.TEXT))
	var items := [
		{"id": "power", "name": "ALIMENTACIÓN"},
		{"id": "data", "name": "DATOS"},
		{"id": "ethernet", "name": "ETHERNET"},
	]
	for raw in items:
		var item: Dictionary = raw
		var row := SwUI.hbox(12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var source := LinkEndpoint.new()
		source.setup("cable", str(item.id), "source", "TORRE · " + str(item.name), CABLE_COLOR)
		var target := LinkEndpoint.new()
		target.setup("cable", str(item.id), "target", "PC · " + str(item.name), CABLE_COLOR)
		source.custom_minimum_size = Vector2(210, 48)
		target.custom_minimum_size = Vector2(210, 48)
		row.add_child(source)
		var wire := ColorRect.new()
		wire.custom_minimum_size = Vector2(80, 5)
		wire.color = CABLE_COLOR
		row.add_child(wire)
		row.add_child(target)
		_stage_holder.add_child(row)
		_cable_sources[str(item.id)] = source
		_cable_targets[str(item.id)] = target
		target.linked.connect(_on_cable_linked.bind(str(item.id)))
	_set_status("Conecta los tres cables para continuar.", UiStyle.TEXT_DIM)

func _build_port_stage() -> void:
	_stage_holder.add_child(_stage_title("2 · PUERTOS EXTERNOS DE LA PC", PORT_COLOR))
	_stage_holder.add_child(SwUI.label("Conecta cada ficha con el puerto de la computadora que le corresponde.", 14, UiStyle.TEXT))
	var items := [
		{"id": "net", "name": "RED / ETHERNET"},
		{"id": "data", "name": "DATOS / USB"},
		{"id": "admin", "name": "ADMINISTRACIÓN"},
	]
	for raw in items:
		var item: Dictionary = raw
		var row := SwUI.hbox(12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var source := LinkEndpoint.new()
		source.setup("port", str(item.id), "source", "CONECTOR · " + str(item.name), PORT_COLOR)
		var target := LinkEndpoint.new()
		target.setup("port", str(item.id), "target", "PUERTO · " + str(item.name), PORT_COLOR)
		row.add_child(source)
		var wire := ColorRect.new()
		wire.custom_minimum_size = Vector2(80, 5)
		wire.color = PORT_COLOR
		row.add_child(wire)
		row.add_child(target)
		_stage_holder.add_child(row)
		_port_sources[str(item.id)] = source
		_port_targets[str(item.id)] = target
		target.linked.connect(_on_port_linked.bind(str(item.id)))
	_set_status("Conecta los tres puertos para continuar.", UiStyle.TEXT_DIM)

func _build_programming_stage() -> void:
	_stage_holder.add_child(_stage_title("3 · PROGRAMACIÓN DEL SERVIDOR", CODE_COLOR))
	_stage_holder.add_child(SwUI.label("Programas a activar: %s" % ", ".join(_programs), 14, UiStyle.TEXT_DIM))
	_stage_holder.add_child(SwUI.label("Ejecuta los comandos en orden para instalar el sistema, la red, el almacén y el backup.", 14, UiStyle.TEXT))
	_programming = ProgrammingBoard.new()
	_programming.completed.connect(_on_programming_completed)
	_stage_holder.add_child(_programming)
	_programming.setup()
	_set_status("Ejecuta los comandos en orden.", UiStyle.TEXT_DIM)

func _stage_title(text: String, color: Color) -> Label:
	var label := SwUI.label(text, 19, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _on_cable_linked(_linked_id: String, item_id: String) -> void:
	if _cable_done.has(item_id):
		return
	_cable_done[item_id] = true
	var source: LinkEndpoint = _cable_sources.get(item_id)
	var target: LinkEndpoint = _cable_targets.get(item_id)
	if source:
		source.mark_connected()
	if target:
		target.mark_connected()
	_set_status("Cables conectados: %d/3" % _cable_done.size(), Color(0.3, 1.0, 0.55))
	if _cable_done.size() >= 3:
		state["cables_done"] = true
		call_deferred("_advance_stage")

func _on_port_linked(_linked_id: String, item_id: String) -> void:
	if _port_done.has(item_id):
		return
	_port_done[item_id] = true
	var source: LinkEndpoint = _port_sources.get(item_id)
	var target: LinkEndpoint = _port_targets.get(item_id)
	if source:
		source.mark_connected()
	if target:
		target.mark_connected()
	_set_status("Puertos conectados: %d/3" % _port_done.size(), Color(0.3, 1.0, 0.55))
	if _port_done.size() >= 3:
		state["ports_done"] = true
		call_deferred("_advance_stage")

func _on_programming_completed() -> void:
	if bool(state.get("programming_done", false)):
		return
	state["programming_done"] = true
	_set_status("PROGRAMACIÓN CORRECTA · servidor configurado", OK_COLOR)
	_schedule_finish()

func _advance_stage() -> void:
	_stage_index += 1
	_show_stage()

func _set_status(text: String, color: Color) -> void:
	if _status:
		_status.text = text
		_status.add_theme_color_override("font_color", color)

func _schedule_finish() -> void:
	if _emitted or not is_inside_tree():
		return
	_emitted = true
	get_tree().create_timer(0.7).timeout.connect(_emit)

func _emit() -> void:
	if not is_inside_tree():
		_emitted = false
		return
	finished.emit()

# Ayuda para pruebas; el jugador usa el arrastre, los conectores y los botones.
func connect_cable_for_test(item_id: String) -> void:
	_on_cable_linked("", item_id)

func connect_port_for_test(item_id: String) -> void:
	_on_port_linked("", item_id)

func complete_programming_for_test() -> void:
	if _programming:
		_programming.complete_for_test()

func complete_all_for_test() -> void:
	state["cables_done"] = true
	state["ports_done"] = true
	state["programming_done"] = true
	_stage_index = 3
	_show_stage()
