class_name BrowserMinigame
extends VBoxContainer

# MINIJUEGO · NAVEGADOR DE LA PC DE INTERNET: la página de descargas
# trae dos secciones, DRIVERS (NVIDIA / AMD / Intel) e IMÁGENES DE
# SISTEMA OPERATIVO. Lo que se baja queda guardado en el PENDRIVE, que
# después se lleva a las otras PCs de la sala.
#
# Mecánicas: una descarga a la vez, la primera se traba a mitad y hay
# que pulsar REANUDAR, las ventanas emergentes hay que cerrarlas con su
# botón CERRAR (si se apilan 3 entra malware) y los anuncios falsos
# instalan malware. Todo se construye por código y se mueve con _tick()
# para poder probarlo sin esperar el reloj real.

signal finished

const AD_TEXTS := [
	"¡¡GANA UN PREMIO! CLIC AQUÍ →",
	"TU PC ESTÁ LENTA: LIMPIA YA 💾",
]
const POPUP_TEXTS := [
	"🏆 ¡FELICIDADES! Eres el visitante 1.000.000. Reclama tu premio AHORA.",
	"⚠ Tu reproductor de video está DESACTUALIZADO: instálalo gratis en 1 clic.",
	"💌 3 personas cerca de ti quieren conocerte. Acepta la invitación.",
	"🎰 Gira la ruleta y gana un cupón de $50.000 esta semana.",
]
const STALL_AT := 0.55
const POPUP_LIMIT := 3

var requested: Array = []
var show_ads := true

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
var _ads_box: HBoxContainer
var _popups_box: VBoxContainer
var _status: Label

# ------------------------------------------------------------------
# Construcción
# ------------------------------------------------------------------
func setup(new_state: Dictionary, task: Dictionary) -> void:
	state = new_state if new_state != null else {}
	requested = SwUI.str_array(task.get("items", Game.SW_DOWNLOAD_REQUEST))
	show_ads = bool(task.get("decoy", true))
	if not state.has("files"):
		state.files = {}
	var saved: Dictionary = state.files
	_files.clear()
	for id in Game.SW_ITEM_ORDER:
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
		state.files[id] = _files[id]
	_active = str(state.get("active", ""))
	if _active != "" and bool(_files.get(_active, {}).get("done", false)):
		_active = ""
		state.active = ""
	_build()
	_refresh_ui()
	_running = true
	if _all_requested_done():
		_set_status("¡DESCARGAS COMPLETAS! El pendrive ya lleva todo lo que piden las otras PCs.", Color(0.3, 1, 0.5))
		_schedule_finish()

func _build() -> void:
	_row_ui.clear()
	add_theme_constant_override("separation", 8)

	# Barra del navegador: pestaña + dirección.
	var chrome := SwUI.hbox(10)
	add_child(chrome)

	var tab := SwUI.label("▰ NAVEGADOR DEL TALLER", 16, UiStyle.CYAN)
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

	var page := SwUI.label("CENTRO DE DESCARGAS · lo que bajes queda en el PENDRIVE", 20, UiStyle.CYAN)
	page.add_theme_color_override("font_outline_color", Color(UiStyle.CYAN.r, UiStyle.CYAN.g, UiStyle.CYAN.b, 0.35))
	page.add_theme_constant_override("font_outline_size", 6)
	add_child(page)

	# Instrucciones: el número SOLO en su línea y la explicación debajo.
	add_child(SwUI.steps([
		{"n": 1, "text": "Pulsa DESCARGAR en los archivos que marcan [color=#ffb020]LO PIDEN OTRAS PCS[/color]."},
		{"n": 2, "text": "Si la descarga se corta a mitad, pulsa [color=#ff2e88]REANUDAR[/color]."},
		{"n": 3, "text": "Cierra las ventanas emergentes con su botón [color=#ff2e88]CERRAR[/color]: si se apilan %d, entra malware." % POPUP_LIMIT},
	]))
	add_child(SwUI.rich("[color=#ff2e88][b]NO[/b][/color] pulses los anuncios de abajo: son trampas que instalan malware."))

	# Lista de descargas agrupada por sección.
	_rows_box = SwUI.vbox(8)
	add_child(_rows_box)
	for section in Game.SW_SECTIONS:
		var ids: Array = []
		for id in Game.SW_ITEM_ORDER:
			if str(Game.SW_ITEMS.get(id, {}).get("section", "")) == str(section.id):
				ids.append(id)
		if ids.is_empty():
			continue
		_rows_box.add_child(SwUI.section_header(str(section.title), Color(str(section.color))))
		for id in ids:
			_rows_box.add_child(_build_row(id))

	# Anuncios falsos (solo en el nivel; el tutorial los oculta).
	_ads_box = SwUI.hbox(14)
	_ads_box.visible = show_ads
	add_child(_ads_box)
	for i in AD_TEXTS.size():
		var ad := Button.new()
		ad.text = AD_TEXTS[i]
		ad.custom_minimum_size = Vector2(410, 44)
		ad.add_theme_font_size_override("font_size", 16)
		var ad_style := StyleBoxFlat.new()
		ad_style.bg_color = Color("2a0a1c")
		ad_style.set_border_width_all(2)
		ad_style.border_color = UiStyle.MAGENTA
		ad_style.set_corner_radius_all(4)
		ad_style.shadow_size = 8
		ad_style.shadow_color = Color(UiStyle.MAGENTA, 0.5)
		ad.add_theme_stylebox_override("normal", ad_style)
		var ad_hover := ad_style.duplicate() as StyleBoxFlat
		ad_hover.bg_color = Color("4a1030")
		ad.add_theme_stylebox_override("hover", ad_hover)
		ad.pressed.connect(_on_ad_pressed.bind(i, ad))
		UiStyle.animate(ad)
		_ads_box.add_child(ad)

	# Ventanas emergentes.
	_popups_box = SwUI.vbox(8)
	add_child(_popups_box)

	_status = SwUI.label("Todo listo: empieza por la primera descarga.", 16, Color(1, 1, 1, 0.8))
	add_child(_status)

func _build_row(id: String) -> Control:
	var info: Dictionary = Game.SW_ITEMS.get(id, {})
	var row := SwUI.hbox(12)

	var info_box := SwUI.vbox(4)
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_box)

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

func _pill_text(id: String) -> String:
	if id in Game.pendrive:
		return "EN PENDRIVE ✓"
	if id in requested:
		return "LO PIDEN OTRAS PCS"
	return "EXTRA"

func _pill_color(id: String) -> Color:
	if id in Game.pendrive:
		return Color(0.3, 1, 0.5)
	if id in requested:
		return Color(1, 0.69, 0.13)
	return UiStyle.TEXT_DIM

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
	# Lo recién bajado se guarda SOLO en el pendrive.
	Game.pendrive_add(id)
	_active = ""
	state.active = ""
	_refresh_ui()
	if _all_requested_done():
		_set_status("¡DESCARGAS COMPLETAS! El pendrive ya lleva todo lo que piden las otras PCs.", Color(0.3, 1, 0.5))
		_running = false
		_schedule_finish()
	else:
		_set_status("¡%s en el pendrive! Faltan %d archivos." % [
			str(Game.SW_ITEMS.get(id, {}).get("short", id)), _missing_count()], Color(0.3, 1, 0.5))

func _missing_count() -> int:
	var n := 0
	for id in requested:
		if id not in Game.pendrive:
			n += 1
	return n

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
		return
	finished.emit()

func _refresh_ui() -> void:
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
# Anuncios y ventanas emergentes
# ------------------------------------------------------------------
func _on_ad_pressed(index: int, button: Button) -> void:
	if not _running:
		return
	button.disabled = true
	button.text = "%s  ✗ MALWARE" % AD_TEXTS[index]
	_mistake("¡Ese botón era un ANUNCIO! Se instaló malware en la PC.")
	_spawn_popup()

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
