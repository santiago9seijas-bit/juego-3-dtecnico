class_name OsFlow
extends VBoxContainer

# Flujo compartido por "instalar sistema operativo" y "cambiar de
# sistema": elegir el SO (tiene que estar en el pendrive), elegir el
# idioma, instalar con una mini-animación de terminal y rematar con el
# cartel verde "SISTEMA OPERATIVO INSTALADO".
#
# Todo el progreso vive en el diccionario `state` (uno por PC), así que
# cerrar y volver a abrir la ventana no pierde nada. Los botones NO se
# guardan ahí: se recrean en cada construcción.

signal installed

const LANGUAGES := [
	{"id": "es", "name": "Español (España)"},
	{"id": "en", "name": "English (United States)"},
	{"id": "pt", "name": "Português (Brasil)"},
]
# Pasos de la instalación: cada línea es un "tick" de la mini-animación.
const BOOT_LINES := [
	"copiando archivos del sistema…",
	"preparando la partición…",
	"configurando el registro…",
	"instalando controladores…",
	"aplicando los ajustes del usuario…",
	"reiniciando por primera vez…",
]
const LINE_TIME := 0.45

var state: Dictionary = {}
var items: Array = []

var _installing := false
var _line_index := 0
var _line_timer := 0.0
var _pulse := 0.0
var _emitted := false

var _os_buttons := {}
var _lang_buttons := {}
var _progress_entry: Dictionary = {}
var _install_button: Button
var _lines_box: VBoxContainer
var _success: VBoxContainer
var _status: Label

func setup(new_state: Dictionary, wanted_items: Array) -> void:
	state = new_state if new_state != null else {}
	items = wanted_items
	_build()
	if _done():
		# Ya estaba instalada: se repinta el cartel final sin repetir el
		# trabajo (y se reprograma el aviso de reparación por si acaso).
		_show_success()
		_schedule_finish()
	else:
		_refresh()

func _build() -> void:
	_os_buttons.clear()
	_lang_buttons.clear()
	add_theme_constant_override("separation", 8)

	# ---- Paso 1 · elegir sistema operativo --------------------------
	add_child(SwUI.section_header("Paso 1 · Sistema operativo", UiStyle.CYAN))
	var os_box := SwUI.vbox(6)
	add_child(os_box)
	for id in items:
		var info: Dictionary = Game.SW_ITEMS.get(id, {})
		var row := SwUI.hbox(12)
		var name := SwUI.label("%s  ·  %s" % [str(info.get("name", id)), str(info.get("size", ""))], 16, UiStyle.TEXT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var pick := SwUI.button("USAR ESTE", Vector2(150, 36), 14)
		pick.pressed.connect(_pick_os.bind(id))
		row.add_child(pick)
		_os_buttons[id] = pick
		os_box.add_child(row)

	# ---- Paso 2 · idioma y teclado ---------------------------------
	add_child(SwUI.section_header("Paso 2 · Idioma y teclado", UiStyle.CYAN))
	var lang_box := SwUI.hbox(10)
	add_child(lang_box)
	for lang in LANGUAGES:
		var pick := SwUI.button(str(lang.name), Vector2(215, 40), 14)
		pick.pressed.connect(_pick_language.bind(str(lang.id)))
		lang_box.add_child(pick)
		_lang_buttons[str(lang.id)] = pick

	# ---- Paso 3 · instalar -----------------------------------------
	add_child(SwUI.section_header("Paso 3 · Instalación", UiStyle.CYAN))
	add_child(SwUI.steps([
		{"n": 1, "text": "Elige un sistema de la lista de arriba: tiene que estar en el pendrive."},
		{"n": 2, "text": "Elige el idioma y el teclado con el que arrancará el equipo."},
		{"n": 3, "text": "Pulsa INSTALAR y espera a que termine la copia de archivos."},
	]))

	_install_button = SwUI.button("INSTALAR SISTEMA OPERATIVO", Vector2(430, 46), 17)
	_install_button.pressed.connect(_start_install)
	add_child(_install_button)

	_progress_entry = SwUI.bar_row("Instalando", UiStyle.CYAN)
	_progress_entry.row.visible = false
	add_child(_progress_entry.row)

	_lines_box = SwUI.vbox(2)
	add_child(_lines_box)

	_success = SwUI.vbox(4)
	_success.visible = false
	var ok := SwUI.label("✔  SISTEMA OPERATIVO INSTALADO", 27, Color(0.3, 1, 0.5))
	ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success.add_child(ok)
	_success.add_child(SwUI.label("El equipo ya puede arrancar. Puedes cerrar esta ventana.", 15, UiStyle.TEXT_DIM))
	add_child(_success)

	_status = SwUI.label("Selecciona el sistema y el idioma para habilitar el botón INSTALAR.", 15, UiStyle.TEXT_DIM)
	add_child(_status)

# ------------------------------------------------------------------
# Selección
# ------------------------------------------------------------------
func _pick_os(id: String) -> void:
	if _installing or _done():
		return
	if id not in Game.pendrive:
		_set_status(
			"Falta «%s»: no está en el pendrive. Baja esa imagen en la PC de INTERNET." % str(Game.SW_ITEMS.get(id, {}).get("name", id)),
			Color(1, 0.4, 0.4))
		return
	state.os_id = id
	_set_status("Sistema elegido: %s." % str(Game.SW_ITEMS.get(id, {}).get("name", id)), UiStyle.CYAN_SOFT)
	_refresh()

func _pick_language(id: String) -> void:
	if _installing or _done():
		return
	state.lang = id
	_set_status("Idioma: %s." % _language_name(), UiStyle.CYAN_SOFT)
	_refresh()

func _language_name() -> String:
	for lang in LANGUAGES:
		if str(lang.id) == str(state.get("lang", "")):
			return str(lang.name)
	return ""

func _language_button_text(id: String) -> String:
	for lang in LANGUAGES:
		if str(lang.id) == id:
			return str(lang.name)
	return id

func _done() -> bool:
	return bool(state.get("installed", false))

func _refresh() -> void:
	if _install_button == null:
		return
	var chosen := str(state.get("os_id", ""))
	var lang := str(state.get("lang", ""))
	for id in _os_buttons:
		var b: Button = _os_buttons[id]
		var on_deck: bool = id in Game.pendrive
		b.disabled = (not on_deck) or _installing or _done()
		b.text = "USAR ESTE" if on_deck else "NO ESTÁ EN PENDRIVE"
		if id == chosen and not _done():
			b.text = "ELEGIDO ✓"
	for id in _lang_buttons:
		var b: Button = _lang_buttons[id]
		b.disabled = _installing or _done()
		b.text = "ELEGIDO ✓" if id == lang else _language_button_text(id)
	_install_button.disabled = _installing or _done() or chosen == "" or lang == ""
	_install_button.text = "INSTALADO ✓" if _done() else "INSTALAR SISTEMA OPERATIVO"

func _start_install() -> void:
	if _installing or _done():
		return
	if str(state.get("os_id", "")) not in Game.pendrive:
		_set_status("Ese sistema ya no está en el pendrive: vuelve a bajarlo en la PC de INTERNET.", Color(1, 0.4, 0.4))
		return
	_installing = true
	_line_index = 0
	_line_timer = 0.0
	for child in _lines_box.get_children():
		child.queue_free()
	_progress_entry.row.visible = true
	_refresh()
	_set_status("Instalando… no apagues el equipo.", UiStyle.CYAN_SOFT)

# ------------------------------------------------------------------
# Mini-animación de la instalación (por tiempo acumulado: los tests la
# aceleran llamando a tick() con un delta grande).
# ------------------------------------------------------------------
func tick(delta: float) -> void:
	if _installing:
		_tick(delta)
	elif _done() and _success and _success.visible:
		_pulse = fmod(_pulse + delta, 100.0)
		_success.modulate = Color(1, 1, 1, 0.72 + 0.28 * sin(_pulse * 6.0))

func _tick(delta: float) -> void:
	if not _installing:
		return
	var total := float(BOOT_LINES.size()) * LINE_TIME
	SwUI.set_bar(_progress_entry, _line_timer / total, UiStyle.CYAN)
	_line_timer += delta
	var target := clampi(int(_line_timer / LINE_TIME), 0, BOOT_LINES.size())
	while _line_index < target:
		_lines_box.add_child(SwUI.label("  › %s" % BOOT_LINES[_line_index], 14, UiStyle.CYAN_SOFT))
		_line_index += 1
	if _line_timer >= total:
		_finish_install()

func _finish_install() -> void:
	_installing = false
	state.installed = true
	_show_success()
	_schedule_finish()

func _show_success() -> void:
	_installing = false
	if _progress_entry.has("bar"):
		SwUI.set_bar(_progress_entry, 1.0, Color(0.3, 1, 0.5))
		_progress_entry.row.visible = false
	for child in _lines_box.get_children():
		child.queue_free()
	_success.visible = true
	_success.modulate = Color(1, 1, 1, 1.0)
	_refresh()
	_set_status("Instalación terminada. El equipo ya arranca.", Color(0.3, 1, 0.5))

func _schedule_finish() -> void:
	if _emitted or not is_inside_tree():
		return
	get_tree().create_timer(0.7).timeout.connect(_emit)

# _emitted ya está puesto por _schedule_finish(); solo se espera a que
# el nodo siga en el árbol para emitir la instalación terminada.
func _emit() -> void:
	if not is_inside_tree():
		return
	installed.emit()

func _set_status(text: String, color: Color) -> void:
	if _status:
		_status.text = text
		_status.add_theme_color_override("font_color", color)
