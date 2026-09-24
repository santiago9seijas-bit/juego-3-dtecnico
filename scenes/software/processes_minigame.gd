class_name ProcessesMinigame
extends VBoxContainer

# MINIJUEGO 2 · ADMINISTRADOR DE TAREAS: la PC está infestada de
# procesos que se comen la CPU. La regla es una sola y se lee en la
# columna de CPU: termina SOLO los que pasan del 50%. Los del sistema
# (aunque su nombre dé desconfianza) se quedan corriendo.
# El estado se guarda en diccionarios así que un test puede recorrerlo
# entero sin esperar frames.

signal finished

const CPU_LIMIT := 50

const LEGIT := [
	{"name": "sistema_operativo.exe", "cpu": 3, "decoy": false},
	{"name": "explorador_de_archivos.exe", "cpu": 6, "decoy": false},
	{"name": "svch0st_act.exe", "cpu": 4, "decoy": true},
	{"name": "servicio_de_audio.exe", "cpu": 2, "decoy": false},
]
const MALWARE := [
	{"name": "kryptominer_x64.exe", "cpu": 99},
	{"name": "asistente_descargas.exe", "cpu": 64},
	{"name": "adware_popups.exe", "cpu": 77},
]
# Orden fijo de las filas: malo, bueno, bueno, malo, bueno, malo, bueno.
const PATTERN := [true, false, false, true, false, true, false]

# Progreso de esta PC (ya terminados, estabilidad): se guarda en `state`
# para que cerrar la ventana no pierda lo hecho.
var state: Dictionary = {}
var required := 3
var show_decoy := true

var _rows: Array = []
var _killed := 0
var _stability := 100
var _emitted := false
var _running := false
var _total_cpu := 0

var _cpu_bar: ProgressBar
var _cpu_text: Label
var _stab_bar: ProgressBar
var _stab_text: Label
var _rows_box: VBoxContainer
var _status: Label

# ------------------------------------------------------------------
# Construcción
# ------------------------------------------------------------------
func setup(new_state: Dictionary, task: Dictionary) -> void:
	state = new_state if new_state != null else {}
	required = maxi(1, int(task.get("count", task.get("required", 3))))
	show_decoy = bool(task.get("decoy", true))
	if not state.has("done"):
		state.done = {}
	_rows = _rows_data()
	_total_cpu = 0
	for r in _rows:
		_total_cpu += int(r.cpu)
	_stability = int(state.get("stability", 100))
	_killed = 0
	_build()
	_restore()
	_running = true

# Reaplica lo que ya se había hecho en visitas anteriores a esta PC.
func _restore() -> void:
	var done: Dictionary = state.get("done", {})
	for key in done:
		var index := int(key)
		if index < 0 or index >= _rows.size():
			continue
		var r: Dictionary = _rows[index]
		var how := str(done[key])
		r.done = true
		r["killed"] = how == "killed"
		r["protected"] = how == "protected"
		var button: Button = r.button
		button.disabled = true
		if how == "killed":
			_killed += 1
			button.text = "TERMINADO ✓"
			button.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
			(r.name_label as Label).add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		else:
			button.text = "PROTEGIDO ✓"
			button.add_theme_color_override("font_color", Color(0.4, 1, 0.6))
	_refresh_bars()
	if _killed >= required:
		_set_status("¡SISTEMA LIMPIO! Se terminaron los %d procesos maliciosos." % required, Color(0.3, 1, 0.5))
		_running = false
		_schedule_finish()

func _rows_data() -> Array:
	var bad: Array = []
	for i in mini(required, MALWARE.size()):
		var m: Dictionary = MALWARE[i]
		bad.append({"name": m.name, "cpu": int(m.cpu), "bad": true})
	var good: Array = []
	for p in LEGIT:
		if bool(p.get("decoy", false)) and not show_decoy:
			continue
		good.append({"name": p.name, "cpu": int(p.cpu), "bad": false})
	var out: Array = []
	var bi := 0
	var gi := 0
	for want_bad: bool in PATTERN:
		if want_bad:
			if bi < bad.size():
				out.append(bad[bi])
				bi += 1
		elif gi < good.size():
			out.append(good[gi])
			gi += 1
	while bi < bad.size():
		out.append(bad[bi])
		bi += 1
	while gi < good.size():
		out.append(good[gi])
		gi += 1
	return out

func _build() -> void:
	add_theme_constant_override("separation", 10)

	var head := Label.new()
	head.text = "⚡  ADMINISTRADOR DE TAREAS · procesos en ejecución"
	head.add_theme_font_size_override("font_size", 17)
	UiStyle.accent(head)
	add_child(head)

	var rule := RichTextLabel.new()
	rule.bbcode_enabled = true
	rule.fit_content = true
	rule.scroll_active = false
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.add_theme_font_size_override("font_size", 15)
	rule.text = "Regla del técnico: termina SOLO los procesos con más del [color=#ff2e88][b]%d%% de CPU[/b][/color]. " % CPU_LIMIT + \
		"Los de CPU baja son del sistema, aunque su nombre parezca de virus: matarlos resta puntos y baja la estabilidad."
	add_child(rule)

	# Barras de CPU y de estabilidad.
	_cpu_bar = _make_bar(UiStyle.MAGENTA)
	_cpu_text = _make_bar_text()
	add_child(_make_bar_row("CPU total", _cpu_bar, _cpu_text))
	_stab_bar = _make_bar(Color(0.3, 1, 0.5))
	_stab_text = _make_bar_text()
	add_child(_make_bar_row("Estabilidad", _stab_bar, _stab_text))

	# Cabecera de columnas.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	add_child(columns)
	var col_name := Label.new()
	col_name.text = "PROCESO"
	col_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_name.add_theme_font_size_override("font_size", 13)
	col_name.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	columns.add_child(col_name)
	var col_cpu := Label.new()
	col_cpu.text = "CPU"
	col_cpu.custom_minimum_size = Vector2(80, 0)
	col_cpu.add_theme_font_size_override("font_size", 13)
	col_cpu.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	columns.add_child(col_cpu)
	var col_action := Label.new()
	col_action.text = "ACCIÓN"
	col_action.custom_minimum_size = Vector2(170, 0)
	col_action.add_theme_font_size_override("font_size", 13)
	col_action.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	columns.add_child(col_action)

	# Filas de procesos.
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	add_child(_rows_box)
	for i in _rows.size():
		_rows_box.add_child(_build_row(i))

	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 16)
	_status.text = "Mira la columna CPU antes de terminar cualquier proceso."
	_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	add_child(_status)
	_refresh_bars()

func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.max_value = 100.0
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0a1018")
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	fill.shadow_size = 6
	fill.shadow_color = Color(color, 0.55)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _make_bar_text() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(96, 0)
	label.add_theme_font_size_override("font_size", 15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label

func _make_bar_row(title: String, bar: ProgressBar, text: Label) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(120, 0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	row.add_child(label)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	row.add_child(text)
	return row

func _build_row(index: int) -> Control:
	var r: Dictionary = _rows[index]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = "▪ %s" % r.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	row.add_child(name_label)

	var cpu := Label.new()
	cpu.text = "%d%%" % int(r.cpu)
	cpu.custom_minimum_size = Vector2(80, 0)
	cpu.add_theme_font_size_override("font_size", 16)
	if int(r.cpu) > CPU_LIMIT:
		cpu.add_theme_color_override("font_color", Color(1, 0.35, 0.4))
		cpu.add_theme_color_override("font_outline_color", Color(UiStyle.MAGENTA, 0.6))
		cpu.add_theme_constant_override("font_outline_size", 4)
	else:
		cpu.add_theme_color_override("font_color", Color(0.4, 1, 0.6))
	row.add_child(cpu)

	var button := Button.new()
	button.text = "TERMINAR"
	button.custom_minimum_size = Vector2(170, 40)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_on_kill.bind(index))
	row.add_child(button)
	UiStyle.animate(button)

	r["button"] = button
	r["name_label"] = name_label
	return row

# ------------------------------------------------------------------
# Juego
# ------------------------------------------------------------------
func _on_kill(index: int) -> void:
	if not _running:
		return
	var r: Dictionary = _rows[index]
	if bool(r.get("done", false)):
		return
	var button: Button = r.button
	if int(r.cpu) <= CPU_LIMIT:
		# Un proceso del sistema: se protege y no vuelve a poder matarse.
		r.done = true
		r.protected = true
		state.done[str(index)] = "protected"
		button.disabled = true
		button.text = "PROTEGIDO ✓"
		button.add_theme_color_override("font_color", Color(0.4, 1, 0.6))
		_stability = maxi(0, _stability - 25)
		state.stability = _stability
		_refresh_bars()
		_mistake("¡%s solo usa %d%% de CPU: es del sistema! Estabilidad -25." % [r.name, int(r.cpu)])
		return
	r.done = true
	r.killed = true
	state.done[str(index)] = "killed"
	button.disabled = true
	button.text = "TERMINADO ✓"
	button.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
	(r.name_label as Label).add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_killed += 1
	_refresh_bars()
	if _killed >= required:
		_set_status("¡SISTEMA LIMPIO! Se terminaron los %d procesos maliciosos." % required, Color(0.3, 1, 0.5))
		_running = false
		_schedule_finish()
	else:
		_set_status("Proceso terminado. Quedan %d maliciosos por fuera." % (required - _killed), Color(0.3, 1, 0.5))

func _refresh_bars() -> void:
	var remaining := 0
	for r in _rows:
		if not bool(r.get("killed", false)):
			remaining += int(r.cpu)
	if _cpu_bar:
		_cpu_bar.value = 100.0 * float(remaining) / float(maxi(_total_cpu, 1))
		_cpu_text.text = "%d%%" % int(100.0 * float(remaining) / float(maxi(_total_cpu, 1)))
		_cpu_text.add_theme_color_override("font_color", Color(1, 0.35, 0.4) if remaining > CPU_LIMIT else Color(0.3, 1, 0.5))
	if _stab_bar:
		_stab_bar.value = float(_stability)
		_stab_text.text = "%d%%" % _stability
		_stab_text.add_theme_color_override("font_color", Color(1, 0.35, 0.4) if _stability < 60 else Color(0.3, 1, 0.5))

func _schedule_finish() -> void:
	if _emitted or not is_inside_tree():
		return
	get_tree().create_timer(0.7).timeout.connect(_emit_finished)

# OJO: _emitted ya está puesto por _schedule_finish(); aquí SOLO se
# comprueba que el nodo siga vivo, o la señal nunca llegaría.
func _emit_finished() -> void:
	if not is_inside_tree():
		return
	finished.emit()

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
