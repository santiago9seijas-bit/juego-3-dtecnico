class_name BrowserMinigame
extends VBoxContainer

# MINIJUEGO · NAVEGADOR DE LA PC DE INTERNET.
#
# La página lista SOLO los archivos que piden las otras PCs de la sala y
# cada fila lleva su etiqueta "→ lo pide PC X · TIPO", así que nunca hace
# falta adivinar qué bajar. Lo que se baja queda guardado en el PENDRIVE,
# que además tiene que estar METERIDO en esta PC (botón INSERTAR PENDRIVE)
# para poder descargar.
#
# Mecánicas: una descarga a la vez, la primera se traba a mitad y hay que
# pulsar REANUDAR, y las ventanas emergentes se cierran con su botón
# CERRAR (si se apilan POPUP_LIMIT entra malware). Todo se construye por
# código y se mueve con _tick() para poder probarlo sin esperar el reloj.

signal finished

const POPUP_TEXTS := [
	"🏆 ¡FELICIDADES! Eres el visitante 1.000.000. Reclama tu premio AHORA.",
	"⚠ Tu reproductor de video está DESACTUALIZADO: instálalo gratis en 1 clic.",
	"💌 3 personas cerca de ti quieren conocerte. Acepta la invitación.",
	"🎰 Gira la ruleta y gana un cupón de $50.000 esta semana.",
]
const STALL_AT := 0.55
const POPUP_LIMIT := 3

var requested: Array = []

# PC en la que está abierto este minijuego (sirve para el hueco USB).
var pc_id := 0
var state: Dictionary = {}
# Un diccionario por archivo, GUARDADO en `state` para que cerrar la
# ventana no pierda descargas a medias.
var _files := {}
var _row_ui := {}
# Id del archivo que se está bajando ("" = ninguna).
var _active := ""
var _popup_index := 0
var _popups_open := 0
var _popup_penalty := false
var _emitted := false
var _running := false

var _url_label: Label
var _rows_box: VBoxContainer
var _popups_box: VBoxContainer
var _counter: Label
var _status: Label

# ------------------------------------------------------------------
# Construcción
# ------------------------------------------------------------------
func setup(new_state: Dictionary, task: Dictionary, new_pc_id := 0) -> void:
	pc_id = new_pc_id
	state = new_state if new_state != null else {}
	requested = SwUI.str_array(task.get("items", Game.SW_DOWNLOAD_REQUEST))
	if not state.has("files"):
		state.files = {}
	var saved: Dictionary = state.files
	_files.clear()
	# SOLO se listan los archivos que piden las otras PCs: nada de relleno.
	for id in requested:
		if saved.has(id):
			_files[id] = saved[id]
		else:
			var info: Dictionary = Game.SW_ITEMS.get(id, {})
			_files[id] = {
				"id": id,
				"duration": float(info.get("duration", 2.0)),
				"progress": 0.0,
				"done": false,
				"stalled": false,
			}
		# Lo que ya está en el pendrive cuenta como bajado Y guardado
		# (así el prefill de los tutoriales sale todo hecho).
		if id in Game.pendrive:
			_files[id].done = true
			_files[id].progress = 1.0
			_files[id].stalled = false
		state.files[id] = _files[id]
	_active = str(state.get("active", ""))
	if _active != "" and bool(_files.get(_active, {}).get("done", false)):
		_active = ""
		state.active = ""
	if not state.has("drops"):
		state.drops = {}
	_build()
	_refresh_ui()
	_running = true
	if _all_downloaded() and not _all_requested_done():
		_set_status("TODO BAJADO: ahora pasa a la pestaña PENDRIVE y guarda los archivos.", UiStyle.CYAN_SOFT)
	elif _all_requested_done():
		_set_status("¡DESCARGAS COMPLETAS! El pendrive ya lleva todo lo que piden las otras PCs.", Color(0.3, 1, 0.5))
		_schedule_finish()

func _build() -> void:
	_row_ui.clear()
	add_theme_constant_override("separation", 8)

	# Barra del navegador: pestaña + dirección.
	var chrome := SwUI.hbox(10)
	add_child(chrome)

	var tab := SwUI.label("▰ NAVEGADOR DEL TALLER", 16, UiStyle.CYAN)
	# El título va SIN autowrap: si no su mínimo es de 1px y el HBox se lo
	# come entero (saldría letra debajo de letra y la fila mediría 500px).
	tab.autowrap_mode = TextServer.AUTOWRAP_OFF
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chrome.add_child(tab)

	var url_box := PanelContainer.new()
	var url_style := StyleBoxFlat.new()
	url_style.bg_color = Color("070c13")
	url_style.set_border_width_all(1)
	url_style.border_color = Color(UiStyle.CYAN, 0.4)
	url_style.set_corner_radius_all(4)
	url_style.content_margin_left = 12.0
	url_style.content_margin_right = 12.0
	url_style.content_margin_top = 4.0
	url_style.content_margin_bottom = 4.0
	url_box.add_theme_stylebox_override("panel", url_style)
	url_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chrome.add_child(url_box)

	_url_label = SwUI.label("https://www.descargas-del-taller.net/centro-de-descargas", 15, UiStyle.CYAN_SOFT)
	url_box.add_child(_url_label)

	var page := SwUI.label("CENTRO DE DESCARGAS · baja lo pedido y llévalo al PENDRIVE", 20, UiStyle.CYAN)
	page.add_theme_color_override("font_outline_color", Color(UiStyle.CYAN.r, UiStyle.CYAN.g, UiStyle.CYAN.b, 0.35))
	page.add_theme_constant_override("font_outline_size", 6)
	add_child(page)

	# Contador grande: qué falta todavía, de un vistazo.
	_counter = SwUI.label("", 18, Color(1, 0.69, 0.13))
	add_child(_counter)

	add_child(SwUI.steps([
		{"n": 1, "text": "Cada fila tiene una etiqueta [color=#ff2e88]→ lo pide PC X · TIPO[/color]: son los ÚNICOS archivos que necesitas."},
		{"n": 2, "text": "Pulsa [color=#19e6ff]DESCARGAR[/color]. Si se corta a mitad, pulsa [color=#ff2e88]REANUDAR[/color]."},
		{"n": 3, "text": "Cierra las ventanas emergentes con su botón [color=#ff2e88]CERRAR[/color]: si se apilan %d, entra malware." % POPUP_LIMIT},
	]))
	add_child(SwUI.rich("[color=#ffb020]El PENDRIVE tiene que estar METERIDO en esta PC[/color]: si no, el botón DESCARGAR no funciona."))
	add_child(SwUI.rich(
		"Cuando bajes todo, abre la pestaña [color=#19e6ff][b]PENDRIVE[/b][/color], arrastra cada archivo a su hueco " +
		"y pulsa [color=#ff2e88]GUARDAR EN EL PENDRIVE[/color]."))

	# Lista de descargas: SOLO lo que piden las otras PCs, por sección.
	_rows_box = SwUI.vbox(10)
	add_child(_rows_box)
	for section in Game.SW_SECTIONS:
		var ids: Array = []
		for id in requested:
			if str(Game.SW_ITEMS.get(id, {}).get("section", "")) == str(section.id):
				ids.append(id)
		if ids.is_empty():
			continue
		_rows_box.add_child(SwUI.section_header(str(section.title), Color(str(section.color))))
		for id in ids:
			_rows_box.add_child(_build_row(id))

	# Ventanas emergentes.
	_popups_box = SwUI.vbox(8)
	add_child(_popups_box)

	_status = SwUI.label("Todo listo: empieza por la primera descarga.", 16, Color(1, 1, 1, 0.8))
	add_child(_status)

func _build_row(id: String) -> Control:
	var info: Dictionary = Game.SW_ITEMS.get(id, {})
	var row := SwUI.hbox(12)

	var info_box := SwUI.vbox(3)
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_box)

	# LA ETIQUETA: qué PC pide este archivo y para qué (su tipo).
	var who := SwUI.label(_requester_label(id), 15, UiStyle.MAGENTA)
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(who)

	var head := SwUI.hbox(10)
	info_box.add_child(head)

	var name_label := SwUI.label("📥  %s" % str(info.get("file", id)), 17, UiStyle.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)

	var pill := SwUI.pill(_pill_text(id), _pill_color(id))
	head.add_child(pill)

	var size_label := SwUI.label(str(info.get("size", "")), 15, UiStyle.TEXT_DIM)
	size_label.custom_minimum_size = Vector2(80, 0)
	head.add_child(size_label)

	var bar := SwUI.bar(UiStyle.CYAN, 16.0)
	info_box.add_child(bar)

	var percent := SwUI.label("0%", 15, UiStyle.TEXT_DIM)
	percent.custom_minimum_size = Vector2(64, 0)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent)

	var button := SwUI.button("DESCARGAR", Vector2(170, 44), 16)
	button.pressed.connect(_on_row_pressed.bind(id))
	row.add_child(button)

	_row_ui[id] = {"bar": bar, "percent": percent, "button": button, "pill": pill}
	return row

# "→ lo pide PC 3 · CONTROLADORES" (o "...PC 3, PC 6 · SISTEMA...").
func _requester_label(id: String) -> String:
	var pcs: Array = []
	var kinds: Array = []
	for t in Game.current_tasks:
		if str(t.get("kind", "")) == "download":
			continue
		if id not in SwUI.str_array(t.get("items", [])):
			continue
		pcs.append("PC %d" % int(t.get("id", 0)))
		var k := str(Game.PART_TITLES.get(str(t.get("kind", "")), str(t.get("kind", ""))))
		if k not in kinds:
			kinds.append(k)
	if pcs.is_empty():
		return "→ LO PIDEN OTRAS PCS"
	var tipo: String = " / ".join(kinds)
	if pcs.size() == 1:
		return "→ lo pide %s · %s" % [pcs[0], tipo]
	return "→ lo piden %s · %s" % [", ".join(pcs), tipo]

# Contador vivo: cuántos archivos siguen sin bajar.
func _refresh_counter() -> void:
	if _counter == null:
		return
	var missing := _missing_count()
	if missing > 0:
		_counter.text = "✗ FALTAN %d DE %d ARCHIVOS PARA LAS OTRAS PCS" % [missing, requested.size()]
		_counter.add_theme_color_override("font_color", Color(1, 0.69, 0.13))
	elif not _all_requested_done():
		_counter.text = "✓ TODO BAJADO · ahora guárdalos en el PENDRIVE (pestaña PENDRIVE)"
		_counter.add_theme_color_override("font_color", UiStyle.CYAN_SOFT)
	else:
		_counter.text = "✓ PENDRIVE CARGADO · %d de %d archivos" % [requested.size(), requested.size()]
		_counter.add_theme_color_override("font_color", Color(0.3, 1, 0.5))

func _pill_text(id: String) -> String:
	if id in Game.pendrive:
		return "EN PENDRIVE ✓"
	if _is_downloaded(id):
		return "DESCARGADO ✓ · GUÁRDALO"
	return "FALTA · DESCÁRGALO"

func _pill_color(id: String) -> Color:
	if id in Game.pendrive:
		return Color(0.3, 1, 0.5)
	if _is_downloaded(id):
		return UiStyle.CYAN_SOFT
	return Color(1, 0.69, 0.13)

func _is_downloaded(id: String) -> bool:
	return bool(_files.get(id, {}).get("done", false))

# ------------------------------------------------------------------
# Descargas
# ------------------------------------------------------------------
func _process(delta: float) -> void:
	if not _running or not visible:
		return
	_tick(delta)

# Avance de la descarga en curso. Los tests lo llaman directamente para
# no tener que esperar el reloj real.
func _tick(delta: float) -> void:
	if _active == "":
		return
	var f: Dictionary = _files.get(_active, {})
	if f.is_empty() or bool(f.done) or bool(f.stalled):
		return
	f.progress = minf(1.0, f.progress + delta / float(f.duration))
	_refresh_row(_active)
	# La primera descarga de la sesión se traba una vez a mitad de camino.
	if not bool(state.get("stalled_any", false)) and f.progress >= STALL_AT:
		state.stalled_any = true
		f.stalled = true
		_set_status("La conexión se cortó con %s. Pulsa REANUDAR para seguir." % str(Game.SW_ITEMS.get(_active, {}).get("file", _active)), Color(1, 0.4, 0.4))
		_refresh_ui()
		return
	if f.progress >= 1.0:
		_complete(_active)

# ¿Está el pendrive enchufado en esta PC? Sin él no baja nada.
func _usb_ok() -> bool:
	return Game.pendrive_in(pc_id)

# El jugador acaba de meter o sacar el pendrive.
func refresh_usb() -> void:
	if not _usb_ok() and _running:
		_set_status("✗ El pendrive NO está metido en esta PC: pulsa INSERTAR PENDRIVE (arriba).", Color(1, 0.45, 0.3))
	_refresh_ui()

func _on_row_pressed(id: String) -> void:
	if not _running:
		return
	var f: Dictionary = _files.get(id, {})
	if f.is_empty() or bool(f.done):
		return
	if bool(f.stalled):
		f.stalled = false
		_set_status("Reanudando la descarga…", UiStyle.CYAN_SOFT)
		_refresh_ui()
		return
	if not _usb_ok():
		_set_status("✗ El pendrive NO está metido en esta PC: pulsa INSERTAR PENDRIVE (arriba).", Color(1, 0.45, 0.3))
		return
	if _active != "":
		_set_status("Hay una descarga en curso: espera o pulsa REANUDAR.", Color(1, 0.85, 0.4))
		return
	_active = id
	state.active = id
	f.progress = 0.001
	_set_status("Descargando %s… cierra las ventanas emergentes." % str(Game.SW_ITEMS.get(id, {}).get("file", id)), UiStyle.CYAN_SOFT)
	_refresh_ui()
	_spawn_popup()

func _complete(id: String) -> void:
	var f: Dictionary = _files.get(id, {})
	f.done = true
	f.stalled = false
	f.progress = 1.0
	# La descarga queda AQUÍ, todavía sin tocar el pendrive: hay que
	# arrastrarla a su hueco en la pestaña PENDRIVE y guardarla.
	_active = ""
	state.active = ""
	_refresh_ui()
	if not _all_downloaded():
		_set_status("¡%s descargado! Faltan %d archivos por bajar." % [
			str(Game.SW_ITEMS.get(id, {}).get("short", id)), _missing_count()], Color(0.3, 1, 0.5))
		return
	_running = false
	if _all_requested_done():
		_set_status("¡DESCARGAS COMPLETAS! El pendrive ya lleva todo lo que piden las otras PCs.", Color(0.3, 1, 0.5))
		_schedule_finish()
	else:
		_set_status("¡TODO BAJADO! Abre la pestaña PENDRIVE, arrastra cada archivo a su hueco y pulsa GUARDAR.", UiStyle.CYAN_SOFT)

func _missing_count() -> int:
	var n := 0
	for id in requested:
		if not _is_downloaded(id):
			n += 1
	return n

# ¿Están todos los archivos ya bajados (aunque todavía no se hayan
# guardado en el pendrive)?
func _all_downloaded() -> bool:
	if requested.is_empty():
		return false
	for id in requested:
		if not _is_downloaded(id):
			return false
	return true

# La tarea se da por buena cuando el pendrive lleva TODO lo pedido.
func _all_requested_done() -> bool:
	if requested.is_empty():
		return false
	for id in requested:
		if id not in Game.pendrive:
			return false
	return true

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

# ------------------------------------------------------------------
# Pestaña PENDRIVE: lo descargado (izquierda) → los huecos de esta PC
# (derecha) → GUARDAR EN EL PENDRIVE.
# ------------------------------------------------------------------
func usb_spec() -> Dictionary:
	var source := []
	var titles := {}
	for id in requested:
		titles[id] = str(Game.SW_ITEMS.get(id, {}).get("name", id))
		if _is_downloaded(id) and id not in Game.pendrive:
			source.append(id)
	var slots := []
	for id in requested:
		var info: Dictionary = Game.SW_ITEMS.get(id, {})
		slots.append({
			"id": "slot_%s" % id,
			"title": _requester_label(id).trim_prefix("→ ").to_upper(),
			"hint": "%s · %s" % [info.get("file", id), info.get("size", "")],
			"accept": [id],
		})
	var hint := "Arrastra cada descarga a su hueco y pulsa GUARDAR EN EL PENDRIVE."
	if _all_requested_done():
		hint = "✓ Todo guardado en el pendrive: ya puedes llevárselo a las otras PCs."
	elif not _all_downloaded():
		hint = "Primero baja TODO lo pedido en la pestaña EL ERROR; después arrastra aquí y guarda."
	return {
		"slots": slots,
		"source": source,
		"source_titles": titles,
		"source_title": "DESCARGADOS SIN GUARDAR",
		"slots_title": "HUECOS DEL PENDRIVE",
		"install_text": "GUARDAR EN EL PENDRIVE",
		"hint": hint,
	}

# Huecos rellenos: lo que ya se arrastró + lo que ya está en el pendrive.
func usb_drops() -> Dictionary:
	var out := {}
	var drops: Dictionary = state.get("drops", {})
	for id in requested:
		var slot := "slot_%s" % id
		if drops.has(slot):
			out[slot] = str(drops[slot])
		elif id in Game.pendrive:
			out[slot] = id
	return out

func usb_drop(slot_id: String, item_id: String) -> bool:
	if item_id not in requested or slot_id != "slot_%s" % item_id:
		return false
	if item_id in Game.pendrive or not _is_downloaded(item_id):
		return false
	var drops: Dictionary = state.get("drops", {})
	drops[slot_id] = item_id
	state.drops = drops
	_refresh_ui()
	return true

func usb_ready() -> bool:
	if _all_requested_done():
		return false
	var drops := usb_drops()
	for id in requested:
		if not drops.has("slot_%s" % id):
			return false
	return true

func usb_install() -> Dictionary:
	if not _usb_ok():
		return {"ok": false, "msg": "✗ El pendrive NO está metido en esta PC: pulsa INSERTAR PENDRIVE."}
	var drops := usb_drops()
	var missing := []
	for id in requested:
		if not drops.has("slot_%s" % id):
			missing.append(str(Game.SW_ITEMS.get(id, {}).get("short", id)))
	if not missing.is_empty():
		return {"ok": false, "msg": "Arrastra primero: falta %s." % ", ".join(missing)}
	var saved := 0
	for slot in drops:
		var id := str(drops[slot])
		if id not in Game.pendrive:
			Game.pendrive_add(id)
			saved += 1
	state.erase("drops")
	_refresh_ui()
	if _all_requested_done():
		_running = false
		_set_status("¡PENDRIVE CARGADO! Ya lleva todo lo que piden las otras PCs.", Color(0.3, 1, 0.5))
		_schedule_finish()
		return {"ok": true, "msg": "¡%d archivos guardados en el pendrive!" % saved}
	return {"ok": true, "msg": "%d archivos guardados en el pendrive." % saved}

func _refresh_ui() -> void:
	_refresh_counter()
	for id in _row_ui:
		_refresh_row(id)

func _refresh_row(id: String) -> void:
	var f: Dictionary = _files.get(id, {})
	var ui: Dictionary = _row_ui.get(id, {})
	if ui.is_empty() or f.is_empty():
		return
	var ratio: float = float(f.get("progress", 0.0))
	(ui.bar as ProgressBar).value = ratio * 100.0
	(ui.percent as Label).text = "%d%%" % int(ratio * 100.0)
	var pill: PanelContainer = ui.pill
	var pill_text: Label = pill.get_child(0) as Label
	pill_text.text = _pill_text(id)
	pill_text.add_theme_color_override("font_color", _pill_color(id))
	var button: Button = ui.button
	if bool(f.get("done", false)):
		button.text = "LISTO ✓"
		button.disabled = true
		button.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
	elif bool(f.get("stalled", false)):
		button.text = "REANUDAR ⚠"
		button.disabled = false
		button.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	elif _active == id:
		button.text = "DESCARGANDO…"
		button.disabled = true
		button.add_theme_color_override("font_color", UiStyle.TEXT)
	else:
		button.text = "DESCARGAR"
		button.disabled = false
		button.add_theme_color_override("font_color", UiStyle.TEXT)

# ------------------------------------------------------------------
# Ventanas emergentes
# ------------------------------------------------------------------
func _spawn_popup() -> void:
	if _popup_index >= POPUP_TEXTS.size():
		return
	var popup := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("180a12")
	style.set_border_width_all(2)
	style.border_color = UiStyle.MAGENTA
	style.set_corner_radius_all(4)
	style.shadow_size = 10
	style.shadow_color = Color(UiStyle.MAGENTA, 0.45)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	popup.add_theme_stylebox_override("panel", style)
	_popups_box.add_child(popup)

	var row := SwUI.hbox(12)
	popup.add_child(row)

	var text := SwUI.label(POPUP_TEXTS[_popup_index], 15, UiStyle.TEXT)
	_popup_index += 1
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var close := SwUI.button("CERRAR ✕", Vector2(140, 40), 15)
	close.pressed.connect(_close_popup.bind(popup))
	row.add_child(close)

	_popups_open += 1
	if _popups_open >= POPUP_LIMIT and not _popup_penalty:
		_popup_penalty = true
		_mistake("%d ventanas emergentes abiertas: mientras tanto entró malware." % _popups_open)

func _close_popup(popup: Control) -> void:
	if not is_instance_valid(popup):
		return
	_popups_open = maxi(0, _popups_open - 1)
	popup.queue_free()
	_set_status("Ventana cerrada. Sigue con las descargas.", Color(1, 1, 1, 0.8))

func _set_status(text: String, color: Color) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", color)

# Un error penaliza fuera del tutorial (allí solo avisa en rojo).
func _mistake(text: String) -> void:
	if not Game.tutorial_mode:
		Game.penalize()
	_set_status(text, Color(1, 0.4, 0.4))
