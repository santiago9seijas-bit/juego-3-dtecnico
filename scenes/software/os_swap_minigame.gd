class_name OsSwapMinigame
extends VBoxContainer

# PC CON UN SISTEMA VIEJO: primero se desinstala (con confirmación de
# "borrar todo") y luego se instala otro desde el pendrive con el mismo
# flujo de idioma y animación final.

signal finished

const OLD_OS := "Windows 10 (versión 1809)"

var state: Dictionary = {}
var flow: OsFlow
var items: Array = []

var _erase_check: CheckBox
var _remove_button: Button
var _remove_entry: Dictionary = {}
var _status: Label

func setup(new_state: Dictionary, task: Dictionary) -> void:
	state = new_state if new_state != null else {}
	items = SwUI.str_array(task.get("items", []))
	if items.is_empty():
		items = ["so_windows", "so_mac", "so_linux"]
	add_theme_constant_override("separation", 8)

	add_child(SwUI.section_header("Sistema actual", UiStyle.MAGENTA))
	var current := SwUI.label("Este equipo trae: %s" % OLD_OS, 17, UiStyle.TEXT)
	add_child(current)

	add_child(SwUI.steps([
		{"n": 1, "text": "Marca la casilla para confirmar que se borra TODO el sistema actual."},
		{"n": 2, "text": "Pulsa DESINSTALAR y espera a que se vacíe la partición."},
		{"n": 3, "text": "Elige el sistema nuevo y el idioma, y pulsa INSTALAR."},
	]))

	_erase_check = CheckBox.new()
	_erase_check.text = "Entiendo que se borrará todo el sistema actual y sus archivos."
	_erase_check.toggled.connect(func(_on: bool) -> void: _refresh())
	add_child(_erase_check)

	_remove_button = SwUI.button("DESINSTALAR SISTEMA ACTUAL", Vector2(360, 44), 16)
	_remove_button.pressed.connect(_start_remove)
	add_child(_remove_button)

	_remove_entry = SwUI.bar_row("Vaciando", UiStyle.MAGENTA)
	add_child(_remove_entry.row)
	_remove_entry.row.visible = false

	add_child(SwUI.gap(6))
	add_child(SwUI.section_header("Paso 2 · Instalar el sistema nuevo", UiStyle.CYAN))
	flow = OsFlow.new()
	add_child(flow)
	flow.setup(state, items)
	flow.installed.connect(func() -> void: finished.emit())

	_status = SwUI.label("Antes de instalar hay que quitar el sistema viejo.", 15, UiStyle.TEXT_DIM)
	add_child(_status)

	if bool(state.get("removed", false)):
		_show_flow()
	else:
		flow.visible = false
	_refresh()
	# NOTA: no hace falta programar aquí el aviso de reparación: cuando el
	# sistema ya está instalado, flow.setup() lo hace él solo (y con un único
	# reloj). Programarlo aquí duplicaba la señal `finished` de esta PC.
	# (El guard de os_flow se libera solo si cierras la ventana antes de tiempo.)

func _refresh() -> void:
	if _erase_check == null:
		return
	var removed: bool = bool(state.get("removed", false))
	_erase_check.disabled = removed
	_erase_check.button_pressed = removed or _erase_check.button_pressed
	_remove_button.disabled = removed or not _erase_check.button_pressed or bool(state.get("removing", false))
	_remove_button.text = "SISTEMA ELIMINADO ✓" if removed else "DESINSTALAR SISTEMA ACTUAL"

func _start_remove() -> void:
	if bool(state.get("removed", false)) or bool(state.get("removing", false)):
		return
	if not _erase_check.button_pressed:
		_set_status("Marca la casilla de confirmación: no se borra nada sin tu visto bueno.", Color(1, 0.4, 0.4))
		return
	state.removing = true
	_remove_entry.row.visible = true
	_remove_button.disabled = true
	_set_status("Borrando el sistema…", UiStyle.CYAN_SOFT)
	_refresh()

func _process(delta: float) -> void:
	if bool(state.get("removing", false)):
		var timer: float = float(state.get("remove_timer", 0.0)) + delta
		state.remove_timer = timer
		SwUI.set_bar(_remove_entry, timer / 1.5, UiStyle.MAGENTA)
		if timer >= 1.5:
			state.erase("removing")
			state.removed = true
			state.erase("remove_timer")
			_remove_entry.row.visible = false
			_show_flow()
			_set_status("Disco vacío. Ahora instala el sistema nuevo.", Color(0.3, 1, 0.5))
			_refresh()
	if flow:
		flow.tick(delta)

func _show_flow() -> void:
	flow.visible = true

func _set_status(text: String, color: Color) -> void:
	if _status:
		_status.text = text
		_status.add_theme_color_override("font_color", color)
