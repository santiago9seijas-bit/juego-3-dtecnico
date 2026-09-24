class_name VirusMinigame
extends VBoxContainer

# MINIJUEGO · LIMPIEZA DE VIRUS: primero se ANALIZA el disco (barra de
# progreso) y los archivos infectados quedan marcados en MAGENTA. After
# eso hay que ARRASTRAR cada infectado hasta la zona de CUARENTENA; si
# arrastras un archivo bueno, se pierden datos y resta puntos.
#
# El progreso vive en `state` (una por PC) y el análisis se mueve por
# tiempo acumulado, así que los tests lo aceleran con _tick(delta).

signal finished

const CLEAN_FILES := [
	{"name": "trabajo_final.docx", "size": "2 MB"},
	{"name": "fotos_familia.jpg", "size": "4 MB"},
	{"name": "presupuesto.xlsx", "size": "1 MB"},
	{"name": "instalador_juego.zip", "size": "900 MB"},
	{"name": "curriculum.pdf", "size": "310 KB"},
	{"name": "canciones_fav.mp3", "size": "12 MB"},
]
const VIRUS_FILES := [
	{"name": "troyano_banco.exe", "size": "12 MB"},
	{"name": "ransom_cifrado.sys", "size": "8 MB"},
	{"name": "keylogger_oculto.dll", "size": "1 MB"},
	{"name": "minero_secreto.exe", "size": "6 MB"},
	{"name": "spyware_webcam.ocx", "size": "2 MB"},
	{"name": "adware_escondido.exe", "size": "3 MB"},
	{"name": "gusano_red.exe", "size": "5 MB"},
	{"name": "backdoor_abierto.exe", "size": "7 MB"},
]
# Orden en que se reparten las tarjetas (los infectados van primero).
const SCAN_TIME := 0.9

# Tarjeta arrastrable: revela su contenido tras el análisis y se puede
# arrastrar hasta la cuarentena.
class VirusCard extends PanelContainer:
	var index := 0
	var is_virus := false
	var revealed := false
	var title: Label

	func _init(idx: int, virus: bool, text: String, revealed_now: bool) -> void:
		index = idx
		is_virus = virus
		revealed = revealed_now
		custom_minimum_size = Vector2(205, 62)
		title = SwUI.label(text, 15, UiStyle.TEXT_DIM)
		add_child(title)
		_style()
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _style() -> void:
		var style := StyleBoxFlat.new()
		if not revealed:
			style.bg_color = Color("0a1018")
			style.border_color = Color(UiStyle.TEXT_DIM, 0.5)
		elif is_virus:
			style.bg_color = Color("2a0a1c")
			style.border_color = UiStyle.MAGENTA
		else:
			style.bg_color = Color("0a1a14")
			style.border_color = Color(0.3, 1, 0.5)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
		add_theme_stylebox_override("panel", style)

	func set_revealed(on: bool) -> void:
		revealed = on
		title.add_theme_color_override(
			"font_color",
			(Color(1, 0.4, 0.7) if is_virus else Color(0.3, 1, 0.5)) if on else UiStyle.TEXT_DIM)
		_style()

	func mark_clean() -> void:
		title.text = "✔ %s" % title.text.get_slice("  ", -1)
		title.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		modulate.a = 0.45
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Arrastrar la tarjeta: solo tiene sentido con el análisis hecho y
	# si todavía no está en cuarentena.
	func _get_drag_data(_at: Vector2) -> Variant:
		if not revealed or not mouse_filter == Control.MOUSE_FILTER_STOP:
			return null
		var preview := PanelContainer.new()
		var box := SwUI.vbox(0)
		preview.add_child(box)
		box.add_child(SwUI.label(title.text, 15, UiStyle.CYAN_SOFT))
		set_drag_preview(preview)
		return {"sw_virus": index}

# Zona de destino: aquí caen los archivos infectados.
class QuarantineZone extends PanelContainer:
	var target: Node = null

	func _init() -> void:
		custom_minimum_size = Vector2(0, 96)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("0a0f16")
		style.set_border_width_all(3)
		style.border_color = Color(0.3, 1, 0.5)
		style.set_corner_radius_all(8)
		style.content_margin_left = 16.0
		style.content_margin_right = 16.0
		style.content_margin_top = 10.0
		style.content_margin_bottom = 10.0
		add_theme_stylebox_override("panel", style)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).has("sw_virus")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		if target:
			target.quarantine(int((data as Dictionary).sw_virus))

var state: Dictionary = {}
var cards: Array = []
var count := 4
var show_decoy := true

var _scanned := false
var _scanning := false
var _scan_timer := 0.0
var _quarantined_count := 0
var _emitted := false

var _scan_button: Button
var _scan_entry: Dictionary = {}
var _grid: GridContainer
var _status: Label

# ------------------------------------------------------------------
# Construcción
# ------------------------------------------------------------------
func setup(new_state: Dictionary, task: Dictionary) -> void:
	state = new_state if new_state != null else {}
	count = maxi(1, int(task.get("count", 4)))
	show_decoy = bool(task.get("decoy", true))
	if not state.has("cleaned"):
		state.cleaned = {}
	cards = _cards_data(count, show_decoy)
	add_theme_constant_override("separation", 8)

	add_child(SwUI.section_header("Analizador de amenazas", UiStyle.MAGENTA))
	add_child(SwUI.rich(
		"[color=#ff2e88][b]Hay archivos infectados[/b][/color] por el disco. " +
		"Primero hay que analizarlos y después mandarlos a la cuarentena."))
	add_child(SwUI.steps([
		{"n": 1, "text": "Pulsa [color=#ffb020]ANALIZAR[/color] para que el antivirus revise todos los archivos."},
		{"n": 2, "text": "Arrastra cada archivo [color=#ff2e88]INFECTADO[/color] hasta la CUARENTENA de abajo."},
		{"n": 3, "text": "NO arrastres los archivos buenos: se borran datos y restan puntos."},
	]))

	_scan_entry = SwUI.bar_row("Analizando", UiStyle.MAGENTA)
	_scan_entry.row.visible = false
	add_child(_scan_entry.row)

	_scan_button = SwUI.button("ANALIZAR DISCO", Vector2(240, 44), 17)
	_scan_button.pressed.connect(start_scan)
	add_child(_scan_button)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	add_child(_grid)
	for i in cards.size():
		var c: Dictionary = cards[i]
		var card := VirusCard.new(
			i, bool(c.virus), str(c.name),
			bool(state.get("scanned", false)) and (not bool(state.cleaned.get(str(i), false)))
		)
		if bool(state.cleaned.get(str(i), false)):
			card.mark_clean()
		_grid.add_child(card)
		c["card"] = card

	var zone := QuarantineZone.new()
	zone.target = self
	zone.name = "Quarantine"
	add_child(zone)
	var zone_title := SwUI.label("▢ ARRASTRA AQUÍ LOS ARCHIVOS INFECTADOS — CUARENTENA", 16, Color(0.3, 1, 0.5))
	zone_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone.add_child(zone_title)

	_status = SwUI.label("Pulsa ANALIZAR para empezar: todavía no sabes qué está infectado.", 16, UiStyle.TEXT_DIM)
	add_child(_status)

	_scanned = bool(state.get("scanned", false))
	_quarantined_count = state.cleaned.size()
	if _scanned:
		_scan_button.disabled = true
		_scan_button.text = "ANALIZADO ✓"
		_set_status(_remaining_text(), UiStyle.CYAN_SOFT)
	if _all_done():
		_set_status("¡DISCO LIMPIO! Todos los virus están en cuarentena.", Color(0.3, 1, 0.5))
		_schedule_finish()

# Reparte las tarjetas: `count` infectados y, si hay trampas, también
# `count` archivos buenos en medio. Siempre empieza un infectado.
static func _cards_data(count: int, with_clean: bool) -> Array:
	var out: Array = []
	var vi := 0
	var ci := 0
	var clean_total := count if with_clean else 0
	var want_virus := true
	while vi < count or ci < clean_total:
		if want_virus and vi < count:
			out.append(_card_data(true, vi))
			vi += 1
		elif ci < clean_total:
			out.append(_card_data(false, ci))
			ci += 1
		elif vi < count:
			out.append(_card_data(true, vi))
			vi += 1
		want_virus = not want_virus
	return out

static func _card_data(virus: bool, index: int) -> Dictionary:
	var pool: Array = VIRUS_FILES if virus else CLEAN_FILES
	var entry: Dictionary = pool[index % pool.size()]
	return {"virus": virus, "name": str(entry.name), "size": str(entry.size)}

func virus_count() -> int:
	var n := 0
	for c in cards:
		if bool(c.virus):
			n += 1
	return n

func cleaned_count() -> int:
	return state.cleaned.size()

func _needed() -> int:
	return mini(count, virus_count())

func _all_done() -> bool:
	return cleaned_count() >= _needed()

func _remaining_text() -> String:
	return "Quedan %d archivos infectados por poner en cuarentena." % maxi(0, _needed() - cleaned_count())

# ------------------------------------------------------------------
# Análisis (por tiempo acumulado: los tests lo aceleran con tick)
# ------------------------------------------------------------------
func start_scan() -> void:
	if _scanned or _scanning:
		return
	_scanning = true
	_scan_timer = 0.0
	_scan_entry.row.visible = true
	_scan_button.disabled = true
	_set_status("Analizando el disco…", UiStyle.CYAN_SOFT)

func _process(delta: float) -> void:
	if _scanning:
		_tick(delta)

func tick(delta: float) -> void:
	_tick(delta)

func _tick(delta: float) -> void:
	if not _scanning:
		return
	_scan_timer += delta
	SwUI.set_bar(_scan_entry, _scan_timer / SCAN_TIME, UiStyle.MAGENTA)
	if _scan_timer < SCAN_TIME:
		return
	_scanning = false
	_scanned = true
	state.scanned = true
	_scan_entry.row.visible = false
	_scan_button.disabled = true
	_scan_button.text = "ANALIZADO ✓"
	for i in cards.size():
		var card: VirusCard = cards[i].card
		if is_instance_valid(card) and not bool(state.cleaned.get(str(i), false)):
			card.set_revealed(true)
	_set_status("Análisis terminado. " + _remaining_text(), UiStyle.CYAN_SOFT)

# ------------------------------------------------------------------
# Cuarentena
# ------------------------------------------------------------------
# También se puede llamar desde el teclado/tests (además de arrastrando).
func quarantine(index: int) -> void:
	if not _scanned:
		_set_status("Todavía no has analizado el disco: pulsa ANALIZAR primero.", Color(1, 0.4, 0.4))
		return
	if index < 0 or index >= cards.size():
		return
	if bool(state.cleaned.get(str(index), false)):
		return
	var c: Dictionary = cards[index]
	var card: VirusCard = c.card
	if not bool(c.virus):
		# Un archivo bueno: se pierden datos. SOLO se penaliza la primera
		# vez (si no, arrastrándolo una y otra vez se farmearía el castigo);
		# a partir de ahí la tarjeta queda inmóvil y en rojo.
		var bad: Dictionary = state.get("bad", {})
		if bool(bad.get(str(index), false)):
			return
		bad[str(index)] = true
		state.bad = bad
		if not Game.tutorial_mode:
			Game.penalize()
		card.modulate = Color(1, 0.6, 0.6, 1.0)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_status("¡«%s» era un archivo BUENO! Se han perdido datos. -penalización." % str(c.name), Color(1, 0.4, 0.4))
		return
	state.cleaned[str(index)] = true
	card.mark_clean()
	_quarantined_count = state.cleaned.size()
	if _all_done():
		_set_status("¡DISCO LIMPIO! Todos los virus están en cuarentena.", Color(0.3, 1, 0.5))
		_schedule_finish()
	else:
		_set_status("«%s» en cuarentena. " % str(c.name) + _remaining_text(), Color(0.3, 1, 0.5))

# Se usa un método (y no una lambda) para que la conexión muera con
# este nodo: si el jugador cierra la ventana antes de tiempo, el reloj
# no intenta emitir sobre una instancia ya liberada.
func _schedule_finish() -> void:
	if _emitted or not is_inside_tree():
		return
	_emitted = true
	get_tree().create_timer(0.7).timeout.connect(_emit_finished)

func _emit_finished() -> void:
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
