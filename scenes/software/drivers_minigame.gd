class_name DriversMinigame
extends VBoxContainer

# Instalación de CONTROLADORES desde el pendrive, dividido por SECCIÓN
# de fabricante (NVIDIA / AMD / Intel). Cada sección dice en su pastilla
# si el driver está en el pendrive o si FALTA: si falta, hay que volver
# a la PC de INTERNET a descargarlo. El progreso (ya instalados) se
# guarda en `state`, uno por PC.

signal finished

const PILL_OK := Color(0.3, 1, 0.5)
const PILL_DECK := Color(0.49, 0.98, 1.0)
const PILL_MISSING := Color(1, 0.4, 0.4)

var state: Dictionary = {}
var items: Array = []
var _rows := {}
var _status: Label
var _emitted := false

func setup(new_state: Dictionary, task: Dictionary) -> void:
	state = new_state if new_state != null else {}
	items = SwUI.str_array(task.get("items", ["driver_nvidia", "driver_amd", "driver_intel"]))
	add_theme_constant_override("separation", 8)

	add_child(SwUI.section_header("Controladores de esta PC", UiStyle.CYAN))
	add_child(SwUI.steps([
		{"n": 1, "text": "Mira las pastillas: FALTA significa que ese driver todavía no está en el pendrive."},
		{"n": 2, "text": "Si alguno falta, ve a la PC de INTERNET, descárgalo y vuelve aquí."},
		{"n": 3, "text": "Pulsa INSTALAR en cada sección que diga EN PENDRIVE."},
	]))
	if Game.tutorial_mode:
		add_child(SwUI.rich(
			"[color=#ffb020]En el nivel real[/color] hay tres secciones y los drivers se bajan en la otra PC; " +
			"aquí el pendrive ya viene cargado."))

	for id in items:
		var info: Dictionary = Game.SW_ITEMS.get(id, {})
		add_child(SwUI.section_header("Sección %s" % str(info.get("vendor", "DRIVER")), UiStyle.MAGENTA))

		var row := SwUI.hbox(12)
		var name := SwUI.label("%s  ·  %s" % [str(info.get("name", id)), str(info.get("size", ""))], 16, UiStyle.TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)

		var pill := SwUI.pill("…", UiStyle.CYAN)
		row.add_child(pill)

		var progress := SwUI.bar(UiStyle.CYAN, 14.0)
		progress.custom_minimum_size = Vector2(130, 14)
		row.add_child(progress)

		var button := SwUI.button("INSTALAR", Vector2(140, 38), 15)
		button.pressed.connect(_install.bind(id))
		row.add_child(button)

		_rows[id] = {"pill": pill, "bar": progress, "button": button}
		add_child(row)

	_status = SwUI.label("Empieza por la primera sección del fabricante.", 15, UiStyle.TEXT_DIM)
	add_child(_status)
	_refresh()
	if _all_done():
		_set_status("¡TODOS LOS DRIVERS INSTALADOS! Esta PC ya reconoce su hardware.", PILL_OK)
		_schedule_finish()

func is_installed(id: String) -> bool:
	return bool(state.get("installed", {}).get(id, false))

func _install(id: String) -> void:
	if is_installed(id) or _emitted:
		return
	if id not in Game.pendrive:
		_set_status(
			"FALTA «%s»: no está en el pendrive. Baja ese driver en la PC de INTERNET y vuelve." % str(Game.SW_ITEMS.get(id, {}).get("name", id)),
			Color(1, 0.4, 0.4))
		return
	var installed: Dictionary = state.get("installed", {})
	installed[id] = true
	state.installed = installed
	_set_status("«%s» instalado correctamente." % str(Game.SW_ITEMS.get(id, {}).get("name", id)), PILL_OK)
	_refresh()
	if _all_done():
		_set_status("¡TODOS LOS DRIVERS INSTALADOS! Esta PC ya reconoce su hardware.", PILL_OK)
		_schedule_finish()

func _all_done() -> bool:
	if items.is_empty():
		return false
	for id in items:
		if not is_installed(id):
			return false
	return true

func _refresh() -> void:
	for id in _rows:
		var row: Dictionary = _rows[id]
		var on_deck: bool = id in Game.pendrive
		var done: bool = is_installed(id)
		var pill: PanelContainer = row.pill
		var pill_text: Label = pill.get_child(0) as Label
		var color := PILL_MISSING
		if done:
			pill_text.text = "INSTALADO ✓"
			color = PILL_OK
			(row.bar as ProgressBar).value = 100.0
		elif on_deck:
			pill_text.text = "EN PENDRIVE"
			color = PILL_DECK
			(row.bar as ProgressBar).value = 0.0
		else:
			pill_text.text = "FALTA · VE A INTERNET"
			color = PILL_MISSING
			(row.bar as ProgressBar).value = 0.0
		pill_text.add_theme_color_override("font_color", color)
		_style_pill(pill, color)
		var button: Button = row.button
		button.disabled = done or not on_deck
		button.text = "INSTALADO ✓" if done else ("INSTALAR" if on_deck else "SIN DRIVER")

func _style_pill(pill: PanelContainer, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.14)
	style.set_border_width_all(1)
	style.border_color = color
	style.set_corner_radius_all(9)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	pill.add_theme_stylebox_override("panel", style)

func _schedule_finish() -> void:
	if _emitted or not is_inside_tree():
		return
	_emitted = true
	get_tree().create_timer(0.7).timeout.connect(_emit)

func _emit() -> void:
	if not is_inside_tree():
		# Ventana cerrada antes de tiempo: se suelta el guard para poder
		# reprogramar el aviso cuando se vuelva a abrir (setup()).
		_emitted = false
		return
	finished.emit()

func _set_status(text: String, color: Color) -> void:
	if _status:
		_status.text = text
		_status.add_theme_color_override("font_color", color)
