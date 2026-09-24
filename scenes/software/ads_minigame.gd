class_name AdsMinigame
extends VBoxContainer

# MINIJUEGO · DESINSTALADOR DE ANUNCIOS (bloatware): la PC está llena
# de programas que solo estorban. Hay que quitarlos y dejar los útiles.
# La trampa creativa: cuando pides desinstalar, el programa muestra un
# aviso de despedida con un botón GRANDE y verde que dice "NO, me
# quedo"; el que desinstala de verdad es el pequeño de al lado.

signal finished

const PROGRAMS := [
	{"id": "turbo", "name": "Navegador Turbo Max 12", "size": "240 MB", "bloat": true,
		"why": "Abre 5 pestañas de anuncios al arrancar y cambia tu buscador."},
	{"id": "quickdeal", "name": "Barra de ofertas QuickDeal", "size": "18 MB", "bloat": true,
		"why": "Pinta cupones encima de las páginas que visitas."},
	{"id": "videoplus", "name": "Reproductor VideoPlus Pro", "size": "96 MB", "bloat": true,
		"why": "Instala otro programa cada vez que lo actualizas."},
	{"id": "searchmar", "name": "BuscaRápido Toolbar", "size": "34 MB", "bloat": true,
		"why": "Se coloca en el navegador y ralentiza cada página."},
	{"id": "winrar", "name": "WinRAR (compresor de archivos)", "size": "5 MB", "bloat": false,
		"why": "Útil: sirve para abrir y crear archivos ZIP y RAR."},
	{"id": "printer", "name": "Controlador de impresora HP", "size": "40 MB", "bloat": false,
		"why": "Útil: sin él no puedes imprimir."},
	{"id": "team", "name": "TeamViewer (acceso remoto)", "size": "70 MB", "bloat": false,
		"why": "Útil: lo usa el técnico para ayudarte a distancia."},
	{"id": "zip", "name": "Lector de PDF Acrobat", "size": "120 MB", "bloat": false,
		"why": "Útil: abre los documentos PDF."},
]
const REMOVE_TIME := 0.8

var state: Dictionary = {}
var count := 3
var items: Array = []

var _view := "list"
var _pending := ""
var _removing := false
var _remove_timer := 0.0
var _emitted := false

var _list_box: VBoxContainer
var _confirm_box: VBoxContainer
var _remove_entry: Dictionary = {}
var _status: Label

# ------------------------------------------------------------------
# Construcción
# ------------------------------------------------------------------
func setup(new_state: Dictionary, task: Dictionary) -> void:
	state = new_state if new_state != null else {}
	count = maxi(1, int(task.get("count", 3)))
	if not state.has("removed"):
		state.removed = {}
	items = bloat_ids().slice(0, count)
	add_theme_constant_override("separation", 8)

	add_child(SwUI.section_header("Programas instalados en esta PC", UiStyle.CYAN))
	add_child(SwUI.steps([
		{"n": 1, "text": "Busca los programas que solo estorban: barras, ofertas, buscadores y reproductores de más."},
		{"n": 2, "text": "Pulsa DESINSTALAR en cada uno de ellos y espera a que termine."},
		{"n": 3, "text": "Deja los programas útiles (compresor, impresora, PDF): quitarlos estorba más."},
	]))
	add_child(SwUI.rich(
		"[color=#ff2e88]Cuidado[/color]: el aviso de despedida tiene un botón grande y verde que NO desinstala. " +
		"El que de verdad desinstala es el pequeño de al lado."))

	_list_box = SwUI.vbox(6)
	add_child(_list_box)

	_remove_entry = SwUI.bar_row("Desinstalando", UiStyle.MAGENTA)
	_remove_entry.row.visible = false
	add_child(_remove_entry.row)

	_confirm_box = SwUI.vbox(8)
	_confirm_box.visible = false
	add_child(_confirm_box)

	_status = SwUI.label("Empieza por el primer programa de la lista.", 16, UiStyle.TEXT_DIM)
	add_child(_status)

	_build_list()
	if _all_done():
		_set_status("¡PC LIMPIA! Solo quedan los programas útiles.", Color(0.3, 1, 0.5))
		_schedule_finish()

static func bloat_ids() -> Array:
	var out: Array = []
	for p in PROGRAMS:
		if bool(p.bloat):
			out.append(str(p.id))
	return out

static func program(id: String) -> Dictionary:
	for p in PROGRAMS:
		if str(p.id) == id:
			return p
	return {}

func is_removed(id: String) -> bool:
	return bool(state.removed.get(id, false))

func removed_count() -> int:
	return state.removed.size()

func _all_done() -> bool:
	return removed_count() >= items.size()

func _build_list() -> void:
	_view = "list"
	_list_box.visible = true
	_confirm_box.visible = false
	for child in _list_box.get_children():
		child.queue_free()
	for p in PROGRAMS:
		var id := str(p.id)
		var removed := is_removed(id)
		var row := SwUI.hbox(12)

		var info := SwUI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name := SwUI.label("%s  ·  %s" % [str(p.name), str(p.size)], 16,
			UiStyle.TEXT_DIM if (removed or not bool(p.bloat)) else UiStyle.TEXT)
		info.add_child(name)

		var why := SwUI.label(str(p.why), 13, UiStyle.TEXT_DIM)
		info.add_child(why)

		var button := SwUI.button(
			"DESINSTALADO ✓" if removed else "DESINSTALAR",
			Vector2(200, 40), 15)
		button.disabled = removed or bool(state.get("protected", {}).get(id, false))
		if bool(state.get("protected", {}).get(id, false)) and not removed:
			button.text = "ÚTIL · NO QUITAR"
		button.pressed.connect(_on_remove_pressed.bind(id))
		row.add_child(button)

		_list_box.add_child(row)

# ------------------------------------------------------------------
# Desinstalación (con el aviso tramposo)
# ------------------------------------------------------------------
func _on_remove_pressed(id: String) -> void:
	if is_removed(id) or _emitted:
		return
	var p := program(id)
	if not bool(p.bloat):
		var protected: Dictionary = state.get("protected", {})
		protected[id] = true
		state.protected = protected
		if not Game.tutorial_mode:
			Game.penalize()
		_set_status("«%s» es un programa ÚTIL: %s" % [str(p.name), str(p.why)], Color(1, 0.4, 0.4))
		_build_list()
		return
	_pending = id
	_show_confirm(id)

func _show_confirm(id: String) -> void:
	_view = "confirm"
	_list_box.visible = false
	for child in _confirm_box.get_children():
		child.queue_free()
	_confirm_box.visible = true

	var card := SwUI.card(UiStyle.MAGENTA, Color("140a12"))
	_confirm_box.add_child(card)
	var box := SwUI.vbox(14)
	card.add_child(box)

	var title := SwUI.label("¿Seguro que quieres desinstalar «%s»?" % str(program(id).name), 19, UiStyle.TEXT)
	box.add_child(title)
	box.add_child(SwUI.rich("[color=#ffb020]«%s»[/color] — %s" % [str(program(id).name), str(program(id).why)]))
	box.add_child(SwUI.label("Nosotros te echaremos mucho de menos…", 15, UiStyle.TEXT_DIM))

	# LA TRAMPA: primero el botón grande y amable que NO desinstala.
	var no_button := SwUI.button("😢  NO, me quedo con el programa", Vector2(560, 66), 22)
	no_button.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
	var no_style := StyleBoxFlat.new()
	no_style.bg_color = Color("0a1a14")
	no_style.set_border_width_all(3)
	no_style.border_color = Color(0.3, 1, 0.5)
	no_style.set_corner_radius_all(8)
	no_style.shadow_size = 12
	no_style.shadow_color = Color(0.3, 1, 0.5, 0.55)
	no_button.add_theme_stylebox_override("normal", no_style)
	no_button.add_theme_stylebox_override("hover", no_style)
	no_button.pressed.connect(_on_trick_no)
	box.add_child(no_button)

	var yes_button := SwUI.button("Sí, desinstalar", Vector2(170, 34), 14)
	yes_button.add_theme_color_override("font_color", Color(1, 0.4, 0.5))
	yes_button.pressed.connect(_on_confirm_yes)
	var yes_row := SwUI.hbox(8)
	yes_row.alignment = BoxContainer.ALIGNMENT_END
	yes_row.add_child(yes_button)
	box.add_child(yes_row)

	_set_status("El aviso de despedida intenta convencerte: fíjate bien antes de pulsar.", Color(1, 0.85, 0.4))

func _on_trick_no() -> void:
	var tricks: Dictionary = state.get("tricks", {})
	tricks[_pending] = true
	state.tricks = tricks
	_set_status("Te intentaron convencer. Vuelve a pulsar DESINSTALAR y elige «Sí, desinstalar».", Color(1, 0.4, 0.4))
	_pending = ""
	_build_list()

func _on_confirm_yes() -> void:
	if _pending == "":
		return
	_removing = true
	_remove_timer = 0.0
	_confirm_box.visible = false
	_remove_entry.row.visible = true
	_set_status("Desinstalando…", UiStyle.CYAN_SOFT)

func trick_count() -> int:
	return state.get("tricks", {}).size()

# ------------------------------------------------------------------
# Avance (por tiempo acumulado: los tests lo aceleran con tick)
# ------------------------------------------------------------------
func _process(delta: float) -> void:
	if _removing:
		_tick(delta)

func tick(delta: float) -> void:
	_tick(delta)

func _tick(delta: float) -> void:
	if not _removing:
		return
	_remove_timer += delta
	SwUI.set_bar(_remove_entry, _remove_timer / REMOVE_TIME, UiStyle.MAGENTA)
	if _remove_timer < REMOVE_TIME:
		return
	_removing = false
	_remove_entry.row.visible = false
	state.removed[_pending] = true
	var name := str(program(_pending).name)
	_pending = ""
	_build_list()
	if _all_done():
		_set_status("¡PC LIMPIA! Solo quedan los programas útiles.", Color(0.3, 1, 0.5))
		_schedule_finish()
	else:
		_set_status("«%s» desinstalado. Quedan %d programas de más." % [name, maxi(0, items.size() - removed_count())], Color(0.3, 1, 0.5))

# Método y no lambda: la conexión se descarta sola si este nodo muere
# antes de que corra el reloj (ventana cerrada a contrarreloj).
func _schedule_finish() -> void:
	if _emitted or not is_inside_tree():
		return
	_emitted = true
	get_tree().create_timer(0.7).timeout.connect(_emit_finished)

func _emit_finished() -> void:
	if not is_inside_tree():
		return
	finished.emit()

func _set_status(text: String, color: Color) -> void:
	if _status:
		_status.text = text
		_status.add_theme_color_override("font_color", color)
