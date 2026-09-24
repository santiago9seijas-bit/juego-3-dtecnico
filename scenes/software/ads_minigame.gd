class_name AdsMinigame
extends VBoxContainer

# MINIJUEGO · VENTANAS EMERGENTES: la PC se llena de pop-ups de
# publicidad que hay que ir cerrando con su botón ✕.
#
# La trampa: en cada tanda hay UNA ✕ FALSA. Pulsarla no cierra nada:
# abre OTRA ventana más. Si en un momento se acumulan MAX_OPEN
# ventanas a la vez, entra malware y se pierde un punto (una sola vez).
#
# El progreso (cuántas van cerradas) vive en `state`, que es UN diccionario
# por PC: cerrar la ventana de la tarea no pierde lo hecho.

signal finished

const MAX_OPEN := 4
const ACCENT := Color(1.0, 0.42, 0.72)

# PC en la que está abierto este minijuego (sirve para el hueco USB).
var pc_id := 0
var state: Dictionary = {}
var count := 3
var items: Array = []

# Nodos abiertos: id -> {"node", "fake", "used"}.
var _open := {}
var _next_id := 0
var _emitted := false

var _box: VBoxContainer
var _status: Label
var _counter: Label
var _success: VBoxContainer

func setup(new_state: Dictionary, task: Dictionary, new_pc_id := 0) -> void:
	pc_id = new_pc_id
	state = new_state if new_state != null else {}
	items = SwUI.str_array(task.get("items", []))
	count = int(task.get("count", 3))
	if count <= 0:
		count = 3
	add_theme_constant_override("separation", 8)

	add_child(SwUI.section_header("Ventanas emergentes de esta PC", ACCENT))
	add_child(SwUI.steps([
		{"n": 1, "text": "Cada ventana tiene su botón [color=#ff2e88]✕ CERRAR[/color] en la esquina."},
		{"n": 2, "text": "CUIDADO: una ✕ es [color=#ff2e88]FALSA[/color]: no cierra nada, abre OTRA ventana más."},
		{"n": 3, "text": "Deja TODAS las ventanas cerradas sin acumular más de %d a la vez." % MAX_OPEN},
	]))

	_counter = SwUI.label("", 18, ACCENT)
	add_child(_counter)

	_box = SwUI.vbox(8)
	add_child(_box)

	_success = SwUI.vbox(4)
	_success.visible = false
	var ok := SwUI.label("✔  PC LIMPIA · TODAS LAS VENTANAS CERRADAS", 24, Color(0.3, 1, 0.5))
	ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success.add_child(ok)
	_success.add_child(SwUI.label("Ya no salen anuncios. Puedes cerrar esta ventana.", 15, UiStyle.TEXT_DIM))
	add_child(_success)

	_status = SwUI.label("Se abren las ventanas: ve cerrándolas con su ✕.", 17, Color(1, 1, 1, 0.85))
	add_child(_status)

	_restore()

func _restore() -> void:
	var spawned := int(state.get("spawned", 0))
	var closed := int(state.get("closed", 0))
	if spawned <= 0:
		# Primera vez: toda la tanda, con la SEGUNDA ventana de la ✕ falsa.
		for i in count:
			_spawn(i == 1 and count > 1)
	else:
		# Reapertura a mitad: se repintan las que faltaban por cerrar.
		var missing := maxi(0, spawned - closed)
		for i in missing:
			_spawn(false)
	_refresh()
	if _done():
		_show_success()
	elif closed > 0:
		_set_status("Ventana cerrada. Sigue con las que quedan.", UiStyle.CYAN_SOFT)

func _done() -> bool:
	return int(state.get("spawned", 0)) > 0 and _open.is_empty() \
		and int(state.get("closed", 0)) >= int(state.get("spawned", 0))

# ------------------------------------------------------------------
# Ventanas
# ------------------------------------------------------------------
func _spawn(fake: bool) -> void:
	state.spawned = int(state.get("spawned", 0)) + 1
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("180a12")
	style.set_border_width_all(2)
	style.border_color = ACCENT if fake else UiStyle.MAGENTA
	style.set_corner_radius_all(6)
	style.shadow_size = 10
	style.shadow_color = Color(UiStyle.MAGENTA, 0.45)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	popup.add_theme_stylebox_override("panel", style)
	_box.add_child(popup)

	var row := SwUI.hbox(12)
	popup.add_child(row)

	var text := SwUI.label(_popup_text(), 15, UiStyle.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var close := SwUI.button("✕ CERRAR", Vector2(150, 40), 15)
	close.pressed.connect(_on_close.bind(_next_id))
	row.add_child(close)

	_open[_next_id] = {"node": popup, "fake": fake, "used": false}
	_next_id += 1

func _popup_text() -> String:
	var texts := [
		"¡¡GANA UN PREMIO! Pulsa AQUÍ ahora o te lo pierdes.",
		"Tu PC está LENTA: limpia la memoria GRATIS en 1 clic.",
		"🎰 Gira la ruleta y gana un cupón de $50.000 esta semana.",
		"🔔 Activar notificaciones para no perderte ninguna oferta.",
		"Tu reproductor de video está DESACTUALIZADO: actualízalo gratis.",
		"🏆 Eres el visitante 1.000.000 de esta web. Reclama tu premio.",
	]
	return str(texts[(int(state.get("spawned", 0)) - 1) % texts.size()])

func _on_close(id: int) -> void:
	var w: Dictionary = _open.get(id, {})
	if w.is_empty():
		return
	if bool(w.get("fake", false)) and not bool(w.get("used", false)):
		# La ✕ era FALSA: no cierra nada, abre una ventana más.
		w.used = true
		_open[id] = w
		state.fake_used = true
		_spawn(false)
		_set_status("¡Esa ✕ era FALSA! En vez de cerrar ha abierto OTRA ventana.", Color(1, 0.4, 0.4))
		_refresh()
		_check_overflow()
		return
	var node: Node = w.node
	if is_instance_valid(node):
		node.queue_free()
	_open.erase(id)
	state.closed = int(state.get("closed", 0)) + 1
	_refresh()
	if _done():
		_show_success()
	else:
		_set_status("Ventana cerrada. Quedan %d." % _open.size(), Color(0.3, 1, 0.5))
	_check_overflow()

func _check_overflow() -> void:
	if _open.size() < MAX_OPEN or bool(state.get("penalty", false)):
		return
	state.penalty = true
	_mistake("%d ventanas abiertas a la vez: mientras tanto entró malware en la PC." % _open.size())

func _refresh() -> void:
	if _counter == null:
		return
	var closed := int(state.get("closed", 0))
	var total := int(state.get("spawned", 0))
	_counter.text = "VENTANAS CERRADAS: %d / %d   ·   ABIERTAS AHORA: %d" % [closed, total, _open.size()]
	if _open.size() >= MAX_OPEN - 1 and not _done():
		_counter.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	else:
		_counter.add_theme_color_override("font_color", ACCENT)

func _show_success() -> void:
	_success.visible = true
	_success.modulate = Color(1, 1, 1, 1.0)
	_set_status("PC limpia: no queda ninguna ventana emergente.", Color(0.3, 1, 0.5))
	_schedule_finish()

func _schedule_finish() -> void:
	if _emitted or not is_inside_tree():
		return
	# Guard: sin él, setup() y el cierre programan DOS relojes y la
	# reparación se anunciaría dos veces.
	_emitted = true
	get_tree().create_timer(0.7).timeout.connect(_emit)

func _emit() -> void:
	if not is_inside_tree():
		_emitted = false
		return
	finished.emit()

func _set_status(text: String, color: Color) -> void:
	if _status:
		_status.text = text
		_status.add_theme_color_override("font_color", color)

# Un error penaliza fuera del tutorial (allí solo avisa en rojo).
func _mistake(text: String) -> void:
	if not Game.tutorial_mode:
		Game.penalize()
	_set_status(text, Color(1, 0.4, 0.4))
