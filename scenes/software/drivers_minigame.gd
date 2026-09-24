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

# PC en la que está abierto este minijuego (sirve para el hueco USB).
var pc_id := 0
var state: Dictionary = {}
var items: Array = []
var _rows := {}
var _status: Label
# Estado GRANDE: cuántos drivers llevan instalados en esta PC.
var _stage: Label
var _emitted := false

func setup(new_state: Dictionary, task: Dictionary, new_pc_id := 0) -> void:
	pc_id = new_pc_id
	state = new_state if new_state != null else {}
	items = SwUI.str_array(task.get("items", ["driver_nvidia", "driver_amd", "driver_intel"]))
	add_theme_constant_override("separation", 8)

	add_child(SwUI.section_header("Controladores de esta PC", UiStyle.CYAN))
	# Estado grande: cuántos llevan instalados, siempre a la vista.
	_stage = SwUI.label("", 19, UiStyle.MAGENTA)
	add_child(_stage)
	add_child(SwUI.steps([
		{"n": 1, "text": "MIRA LA PASTILLA de cada sección: FALTA significa que ese driver todavía no está en el pendrive."},
		{"n": 2, "text": "SI ALGUNO FALTA: mete el pendrive en la PC de INTERNET, descárgalo ahí y vuelve con él."},
		{"n": 3, "text": "PENDRIVE CONECTADO AQUÍ: pasa a la pestaña PENDRIVE, arrastra cada driver a su hueco y pulsa INSTALAR."},
	]))
	if Game.tutorial_mode:
		add_child(SwUI.rich(
			"[color=#ffb020]En el nivel real[/color] hay tres secciones y los drivers se bajan en la otra PC; " +
			"aquí el pendrive ya viene cargado y todo se hace en la pestaña PENDRIVE."))

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
		progress.custom_minimum_size = Vector2(150, 14)
		row.add_child(progress)

		# El botón de INSTALAR vive en la pestaña PENDRIVE: aquí solo se
		# ve el estado de cada sección (se instala arrastrando allí).
		_rows[id] = {"pill": pill, "bar": progress}
		add_child(row)

	_status = SwUI.label("Empieza por la primera sección del fabricante.", 17, UiStyle.TEXT_DIM)
	add_child(_status)
	_refresh()
	if _all_done():
		_set_status("¡TODOS LOS DRIVERS INSTALADOS! Esta PC ya reconoce su hardware.", PILL_OK)
		_schedule_finish()

func is_installed(id: String) -> bool:
	return bool(state.get("installed", {}).get(id, false))

# ¿Está el pendrive enchufado en esta PC? Sin él no se instala nada.
func _usb_ok() -> bool:
	return Game.pendrive_in(pc_id)

# El jugador acaba de meter o sacar el pendrive: se repintan los botones.
func refresh_usb() -> void:
	_refresh()
	if not _usb_ok() and not _all_done():
		_set_status("✗ El pendrive NO está metido en esta PC: pulsa INSERTAR PENDRIVE (arriba).", Color(1, 0.45, 0.3))

func _install(id: String) -> void:
	if is_installed(id) or _emitted:
		return
	if not _usb_ok():
		_set_status("✗ El pendrive NO está metido en esta PC: pulsa INSERTAR PENDRIVE (arriba).", Color(1, 0.45, 0.3))
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

# ------------------------------------------------------------------
# Pestaña PENDRIVE: un hueco por sección + el botón INSTALAR.
# Los drivers se ARRASTRAN desde el pendrive (izquierda) hasta el hueco
# de su fabricante (derecha) y luego se le da a INSTALAR.
# ------------------------------------------------------------------
func usb_spec() -> Dictionary:
	var slots := []
	var titles := {}
	for id in items:
		var info: Dictionary = Game.SW_ITEMS.get(id, {})
		slots.append({
			"id": "slot_%s" % id,
			"title": "Sección %s" % str(info.get("vendor", "DRIVER")),
			"hint": "%s · %s" % [info.get("name", id), info.get("file", "")],
			"accept": [id],
		})
		titles[id] = str(info.get("name", id))
	return {
		"slots": slots,
		"source": Game.pendrive,
		"source_titles": titles,
		"install_text": "INSTALAR",
		"hint": "Arrastra cada driver al hueco de su sección y pulsa INSTALAR.",
	}

# Huecos rellenos: lo que ya se arrastró + los drivers ya instalados.
func usb_drops() -> Dictionary:
	var out := {}
	var drops: Dictionary = state.get("drops", {})
	for id in items:
		var slot := "slot_%s" % id
		if drops.has(slot):
			out[slot] = str(drops[slot])
		elif is_installed(id):
			out[slot] = id
	return out

func usb_drop(slot_id: String, item_id: String) -> bool:
	if item_id not in items or slot_id != "slot_%s" % item_id:
		return false
	if item_id not in Game.pendrive:
		return false
	var drops: Dictionary = state.get("drops", {})
	drops[slot_id] = item_id
	state.drops = drops
	_refresh()
	return true

func usb_ready() -> bool:
	if not _usb_ok():
		return false
	var drops := usb_drops()
	for id in items:
		if not drops.has("slot_%s" % id):
			return false
	return true

func usb_install() -> Dictionary:
	if not _usb_ok():
		return {"ok": false, "msg": "✗ El pendrive NO está metido en esta PC: pulsa INSERTAR PENDRIVE."}
	var drops := usb_drops()
	var missing := []
	for id in items:
		if not drops.has("slot_%s" % id):
			missing.append(str(Game.SW_ITEMS.get(id, {}).get("short", id)))
	if not missing.is_empty():
		return {"ok": false, "msg": "Arrastra primero: falta %s." % ", ".join(missing)}
	for id in items:
		_install(id)
	state.erase("drops")
	return {"ok": true, "msg": "Controladores instalados. Mira la lista de la pestaña EL ERROR."}

func _refresh() -> void:
	var usb := _usb_ok()
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
	if not usb and not _all_done():
		_set_status("✗ El pendrive NO está metido en esta PC: pulsa INSERTAR PENDRIVE (arriba).", Color(1, 0.45, 0.3))
	_refresh_stage()

func _refresh_stage() -> void:
	if _stage == null:
		return
	var done := 0
	for id in items:
		if is_installed(id):
			done += 1
	if items.is_empty():
		_stage.text = ""
	elif done >= items.size():
		_stage.text = "✔ TODOS LOS DRIVERS INSTALADOS · %d de %d" % [done, items.size()]
		_stage.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
	else:
		_stage.text = "PASO %d DE %d · DRIVERS INSTALADOS: %d  ·  FALTAN %d" % [
			mini(done + 1, items.size()), items.size(), done, items.size() - done]
		_stage.add_theme_color_override("font_color", UiStyle.MAGENTA)

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
