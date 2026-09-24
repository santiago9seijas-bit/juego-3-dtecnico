extends CanvasLayer

@onready var gameplay_root: Control = %Gameplay
@onready var prompt_label: Label = %PromptLabel
@onready var timer_label: Label = %TimerLabel
@onready var score_label: Label = %ScoreLabel
@onready var carried_label: Label = %CarriedLabel
@onready var message_label: Label = %MessageLabel
@onready var minigame: PanelContainer = %Minigame
@onready var picker: PanelContainer = %PartPicker
@onready var picker_title: Label = %PickerTitle
@onready var picker_list: VBoxContainer = %PickerList
@onready var picker_cancel: Button = %PickerCancel
@onready var removal_panel: PanelContainer = %RemovalPanel
@onready var sfx: AudioStreamPlayer = %Sfx
@onready var errors_label: Label = %ErrorsLabel

var _msg_until := 0.0
var _removal_cb: Callable = Callable()

# Panel del mundo de software: dentro va el minijuego de la PC (se
# construye una sola vez en _ready). El registro MINIGAMES asigna un
# minijuego a cada tipo de PC de la sala.
var MINIGAMES := {
	"download": BrowserMinigame,
	"drivers": DriversMinigame,
	"os_install": OsInstallMinigame,
	"virus": VirusMinigame,
	"processes": ProcessesMinigame,
	"os_swap": OsSwapMinigame,
	"ads": AdsMinigame,
}
var software_host: Control
var software_panel: PanelContainer
var software_title: Label
var software_symptom: Label
var software_pendrive: Label
var software_content: VBoxContainer
var software_status: Label
var software_close: Button
var _soft_pc: Node = null

# UI propia del modo tutorial (se construye una sola vez en _ready).
var tut_header: Label
var tut_exit_button: Button
var tut_intro: ColorRect
var tut_intro_title: Label
var tut_intro_body: RichTextLabel
var tut_intro_start: Button
var tut_intro_back: Button
var tut_intro_hint: Label
var tut_complete: CenterContainer
var tut_repeat_button: Button
var tut_complete_exit: Button
var tut_complete_text: Label

var _tut_part_shown := ""
var _last_carried_text := ""
var _last_timer_secs := -1
var _last_score := -1
var _last_errors := -1
var _score_tween: Tween
var _last_timer_outline := Color(-1.0, -1.0, -1.0)

func _ready() -> void:
	Game.hud = self
	Game.game_started.connect(_on_game_started)
	Game.tutorial_finished.connect(_on_tutorial_finished)
	Game.tutorial_exited.connect(_on_tutorial_exited)
	minigame.repaired.connect(_on_repair)
	prompt_label.visible = false
	message_label.visible = false
	picker.visible = false
	picker_cancel.pressed.connect(close_picker)
	removal_panel.visible = false
	removal_panel.done.connect(_on_removal_done)
	removal_panel.cancel.connect(_on_removal_cancel)
	_build_tutorial_ui()
	_build_software_ui()
	_style_ui()

# Mismo look del menú principal: paneles oscuros con neón y botones animados.
func _style_ui() -> void:
	UiStyle.apply(gameplay_root)
	UiStyle.apply(tut_header)
	UiStyle.apply(tut_exit_button)
	UiStyle.apply(tut_intro)
	UiStyle.apply(tut_complete)
	_neon_hud()

# Marcador del juego con neón graffiti: tiempo, puntaje, errores, mochila,
# mensajes y la mira central.
func _neon_hud() -> void:
	timer_label.add_theme_font_override("font", UiStyle.neon_font(0.24, 0.26))
	score_label.add_theme_font_override("font", UiStyle.neon_font(0.3, 0.3))
	errors_label.add_theme_font_override("font", UiStyle.neon_font(0.2, 0.18))
	_neon_label(timer_label, 28, Color.WHITE, UiStyle.CYAN, 7, Color(UiStyle.CYAN, 0.55))
	_neon_label(score_label, 30, UiStyle.CYAN_SOFT, UiStyle.MAGENTA, 8, Color(UiStyle.MAGENTA, 0.5))
	_neon_label(errors_label, 17, UiStyle.TEXT, Color(UiStyle.MAGENTA.r, UiStyle.MAGENTA.g, UiStyle.MAGENTA.b, 0.55), 4, Color(UiStyle.MAGENTA, 0.3))
	_neon_label(carried_label, 16, UiStyle.TEXT, Color(UiStyle.CYAN.r, UiStyle.CYAN.g, UiStyle.CYAN.b, 0.5), 4, Color(UiStyle.CYAN, 0.3))
	_neon_label(message_label, 20, Color.WHITE, UiStyle.MAGENTA, 7, Color(UiStyle.CYAN, 0.5))
	_neon_label(prompt_label, 19, UiStyle.CYAN_SOFT, Color(UiStyle.MAGENTA.r, UiStyle.MAGENTA.g, UiStyle.MAGENTA.b, 0.6), 5, Color(UiStyle.CYAN, 0.4))
	var cross: Label = gameplay_root.get_node_or_null("Crosshair")
	if cross:
		_neon_label(cross, 22, Color.WHITE, UiStyle.MAGENTA, 6, Color(UiStyle.MAGENTA, 0.7))

func _neon_label(label: Label, font_size: int, color: Color, outline: Color, outline_size: int, glow: Color) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("font_outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", glow)
	label.add_theme_constant_override("shadow_outline_size", 8)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)

func _process(delta: float) -> void:
	var playing := Game.state == Game.State.PLAYING
	gameplay_root.visible = playing
	_update_tutorial_ui()
	# Mientras la ventana está abierta el pendrive se mueve solo: cada
	# descarga lo carga y cada instalador lo consulta, así que el cartel
	# tiene que decir SIEMPRE qué lleva y qué le falta a esa PC.
	if software_panel and software_panel.visible:
		_refresh_software_pendrive()
	if not playing:
		return
	if not Game.tutorial_mode:
		var secs := int(Game.time_left)
		if secs != _last_timer_secs:
			_last_timer_secs = secs
			timer_label.text = "Tiempo: %02d:%02d" % [secs / 60, secs % 60]
		# Los bordes del reloj se ponen rojizos cuando se acaba el tiempo.
		_update_timer_urgency()
		if Game.score != _last_score:
			if _last_score >= 0:
				_flash_score(Game.score > _last_score)
			_last_score = Game.score
			score_label.text = "Puntaje: %d" % Game.score
		if Game.errors != _last_errors:
			_last_errors = Game.errors
			errors_label.text = "Errores: %d" % Game.errors
	_show_carried()
	if _msg_until > 0.0:
		_msg_until -= delta
		if _msg_until <= 0.0:
			message_label.visible = false

# El puntaje "pita" visualmente: borde VERDE al sumar y ROJO al restar
# (un destello corto y sobrio), con un pequeño salto de tamaño.
func _flash_score(gain: bool) -> void:
	var col := Color(0.3, 1.0, 0.5) if gain else Color(1.0, 0.26, 0.32)
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_outline_color", col)
	score_label.add_theme_color_override("font_shadow_color", Color(col.r, col.g, col.b, 0.85))
	if score_label.size.x <= 0.0:
		_reset_score_style()
		return
	score_label.pivot_offset = score_label.size * 0.5
	var pop := Vector2(1.14, 1.14) if gain else Vector2(1.08, 1.08)
	_score_tween = score_label.create_tween()
	_score_tween.tween_property(score_label, "scale", pop, 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_score_tween.tween_interval(0.3)
	_score_tween.tween_property(score_label, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_score_tween.tween_callback(_reset_score_style)

func _reset_score_style() -> void:
	if not is_instance_valid(score_label):
		return
	score_label.add_theme_color_override("font_color", UiStyle.CYAN_SOFT)
	score_label.add_theme_color_override("font_outline_color", UiStyle.MAGENTA)
	score_label.add_theme_color_override("font_shadow_color", Color(UiStyle.MAGENTA, 0.5))

# Los bordes del cronómetro pasan de cian a ROJIZOS (y laten) según se
# acaba el tiempo del nivel.
func _update_timer_urgency() -> void:
	var total := Game.level_time_total()
	if total <= 0.0:
		return
	var ratio := clampf(Game.time_left / total, 0.0, 1.0)
	var urgency := clampf(1.0 - ratio / 0.35, 0.0, 1.0)
	var col := UiStyle.CYAN.lerp(Color(1.0, 0.3, 0.32), urgency)
	if urgency > 0.01:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012 * (0.5 + urgency))
		col = col.lerp(Color(1.0, 0.12, 0.18), 0.4 * urgency * pulse)
	if col.is_equal_approx(_last_timer_outline):
		return
	_last_timer_outline = col
	timer_label.add_theme_color_override("font_outline_color", col)
	timer_label.add_theme_color_override("font_shadow_color", Color(col.r, col.g, col.b, 0.5 + 0.35 * urgency))
	timer_label.add_theme_color_override("font_color", Color.WHITE.lerp(Color(1.0, 0.82, 0.82), urgency))

func play_sfx(name: String) -> void:
	var stream := _sfx_stream(name)
	if stream and sfx:
		sfx.stream = stream
		sfx.play()

func _sfx_stream(_name: String) -> AudioStream:
	return null

func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	_msg_until = 2.0

# Inventario: avisa claramente cuándo llevas una pieza dañada (rojo
# neón + ⚠) para que la vayas a botar a la papelera.
func _show_carried() -> void:
	var text := "Llevas: —"
	var damaged := Game.damaged_count()
	if not Game.carried_parts.is_empty():
		var names: Array = []
		for part in Game.carried_parts:
			if part.get("good", true):
				names.append(part.name)
			else:
				names.append("⚠ %s [DAÑADA]" % part.name)
		text = "Llevas (%d/%d): %s" % [Game.carried_parts.size(), Game.MAX_CARRIED, ", ".join(names)]
	if text == _last_carried_text:
		return
	_last_carried_text = text
	carried_label.text = text
	carried_label.add_theme_color_override(
		"font_color",
		UiStyle.MAGENTA if damaged > 0 else UiStyle.TEXT
	)

# Papelera: se tiran todas las piezas dañadas que cargues.
func throw_damaged() -> void:
	var n := Game.trash_damaged()
	_last_carried_text = ""
	_show_carried()
	if n == 0:
		show_message("No llevas ninguna pieza dañada.")
	elif n == 1:
		show_message("Bottaste la pieza dañada. Mochila liberada.")
	else:
		show_message("Bottaste %d piezas dañadas. Mochila liberada." % n)

func set_prompt(interactable: Node3D) -> void:
	if interactable and interactable is Interactable:
		prompt_label.text = "E - %s" % interactable.prompt_text
		prompt_label.visible = true
	else:
		prompt_label.visible = false

func open_minigame(pc: Node) -> void:
	minigame.setup(pc)
	Game.is_minigame_open = true
	_fix_minigame_layout()

func _fix_minigame_layout() -> void:
	await get_tree().process_frame
	minigame.custom_minimum_size = Vector2(860, 520)
	minigame.size = Vector2(860, 520)
	minigame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func close_minigame() -> void:
	minigame.visible = false
	Game.is_minigame_open = false

func open_picker(part_type: String) -> void:
	var part_title: String = Game.PART_TITLES.get(part_type, part_type)
	var variants: Array = Game.PART_VARIANTS[part_type]
	var box_title := "Estantería de %s — elige el modelo:" % part_title
	# En el tutorial la caja trae SOLO el repuesto exacto que pide esa PC.
	if Game.tutorial_mode and Game.current_tasks.size() == 1:
		var want: String = Game.current_tasks[0].get("variant", "")
		var exact: Array = []
		for v in variants:
			if String(v.name) == want:
				exact.append(v)
		if not exact.is_empty():
			variants = exact
			box_title = "Caja de %s — repuesto exacto:" % part_title
	picker_title.text = box_title
	for child in picker_list.get_children():
		child.free()
	for variant in variants:
		var button := Button.new()
		button.text = variant.name
		button.pressed.connect(_on_variant_picked.bind(variant))
		picker_list.add_child(button)
		UiStyle.animate(button)
	picker.visible = true
	Game.is_minigame_open = true
	_fix_picker_layout()

func _on_variant_picked(variant: Dictionary) -> void:
	if not Game.pick_part_variant(variant):
		show_message("Mochila llena (max %d)." % Game.MAX_CARRIED)
	close_picker()

func close_picker() -> void:
	picker.visible = false
	Game.is_minigame_open = false

# ESC cierra el menú que esté encima: primero los paneles pequeños y la PC al final.
func close_top_menu() -> void:
	if removal_panel.visible:
		_on_removal_cancel()
	elif picker.visible:
		close_picker()
	elif software_panel and software_panel.visible:
		close_software()
	elif minigame.visible:
		close_minigame()

# ------------------------------------------------------------------
# MUNDO DE SOFTWARE: ventana con el navegador o el administrador de
# tareas. Se construye una sola vez y recibe un minijuego por tarea.
# ------------------------------------------------------------------
func _build_software_ui() -> void:
	software_host = Control.new()
	software_host.name = "SoftwareHost"
	add_child(software_host)
	software_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# IMPORTANTE: al ser un Control a pantalla completa dentro del HUD,
	# tiene que dejar pasar el ratón (como hace "Gameplay") o tapa los
	# botones del menú principal que quedan debajo.
	software_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	software_host.visible = false

	# Centrado garantizado. Igual que el host, no puede comerse los clics:
	# el que los recoge es el panel (STOP por defecto) mientras está abierto.
	var center := CenterContainer.new()
	center.name = "SoftwareCenter"
	software_host.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	software_panel = PanelContainer.new()
	software_panel.name = "SoftwarePanel"
	software_panel.visible = false
	software_panel.custom_minimum_size = Vector2(940, 580)
	center.add_child(software_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	software_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "VBox"
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)

	software_title = Label.new()
	software_title.name = "SoftwareTitle"
	software_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	software_title.add_theme_font_size_override("font_size", 22)
	UiStyle.accent(software_title)
	head.add_child(software_title)

	software_close = Button.new()
	software_close.name = "SoftwareClose"
	software_close.text = "CERRAR (ESC)"
	software_close.custom_minimum_size = Vector2(170, 42)
	software_close.add_theme_font_size_override("font_size", 16)
	software_close.pressed.connect(close_software)
	head.add_child(software_close)

	software_symptom = Label.new()
	software_symptom.name = "SoftwareSymptom"
	software_symptom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	software_symptom.add_theme_font_size_override("font_size", 15)
	software_symptom.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	box.add_child(software_symptom)

	# Contenido del pendrive: el jugador siempre ve qué le falta llevar.
	software_pendrive = Label.new()
	software_pendrive.name = "SoftwarePendrive"
	software_pendrive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	software_pendrive.add_theme_font_size_override("font_size", 14)
	software_pendrive.add_theme_color_override("font_color", UiStyle.CYAN_SOFT)
	box.add_child(software_pendrive)

	software_content = VBoxContainer.new()
	software_content.name = "SoftwareContent"
	software_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(software_content)

	software_status = Label.new()
	software_status.name = "SoftwareStatus"
	software_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	software_status.add_theme_font_size_override("font_size", 15)
	software_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	box.add_child(software_status)

	# Tema ciberpunk + animación del botón (el resto llega por herencia).
	UiStyle.apply(software_panel)

func open_software(pc: Node) -> void:
	if pc == null or software_panel == null:
		return
	if pc.get("pc_id") != null and int(pc.pc_id) in Game.repaired:
		return
	_soft_pc = pc
	var kind := str(pc.get("kind"))
	software_title.text = "PC %d · %s" % [int(pc.pc_id), Game.PART_TITLES.get(kind, "PC")]
	software_symptom.text = "SÍNTOMA: %s" % str(pc.get("symptom"))
	_refresh_software_pendrive()
	_clear_software_content()
	var cls: GDScript = MINIGAMES.get(kind, BrowserMinigame)
	var node := cls.new() as Control
	software_content.add_child(node)
	# Estado por PC: cerrar la ventana no pierde descargas ni instalaciones.
	var soft_state: Dictionary = pc.get("state") if pc.get("state") != null else {}
	node.setup(soft_state, pc.get("task") if "task" in pc else {})
	node.finished.connect(_on_software_done)
	software_status.text = "Resuelve la tarea para reparar esta PC. ESC la cierra sin perder el avance."
	software_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	software_panel.visible = true
	software_host.visible = true
	Game.is_minigame_open = true

# Rótulo vivo del pendrive (se repinta en cada frame mientras hay ventana).
func _refresh_software_pendrive() -> void:
	if software_pendrive:
		software_pendrive.text = "PENDRIVE · contiene: %s" % Game.pendrive_names()

func close_software() -> void:
	if software_panel:
		software_panel.visible = false
	if software_host:
		software_host.visible = false
	_clear_software_content()
	_soft_pc = null
	Game.is_minigame_open = false

func _clear_software_content() -> void:
	if software_content == null:
		return
	# Nunca free() aquí: el minijuego puede estar emitiendo su señal
	# (finished) cuando se cierra la ventana. Se saca del árbol ya y se
	# destruye al terminar el frame.
	for child in software_content.get_children():
		software_content.remove_child(child)
		child.call_deferred("free")

# La tarea terminada: se cierra la ventana y se anota la reparación.
# Se aplaza un frame para que el minijuego termine de emitir su señal
# sin que su propio nodo quede bloqueado al liberarse.
func _on_software_done() -> void:
	if _soft_pc == null:
		return
	call_deferred("_close_and_repair", _soft_pc)

func _close_and_repair(pc: Node) -> void:
	if not is_instance_valid(pc):
		return
	_soft_pc = null
	close_software()
	var id := int(pc.pc_id)
	Game.mark_repaired(id)
	if not Game.tutorial_mode:
		show_message("¡PC %d reparada! +%d puntos" % [id, Game.POINTS_PER_TASK])

func open_removal(part_type: String, on_done: Callable, reverse := false, mode := "") -> void:
	_removal_cb = on_done
	removal_panel.open(part_type, reverse, mode)
	removal_panel.visible = true
	_fix_removal_layout()

func _on_removal_done() -> void:
	removal_panel.visible = false
	Game.add_multiplier_bonus(removal_panel.last_multiplier)
	if _removal_cb.is_valid():
		_removal_cb.call()
	_removal_cb = Callable()

func _on_removal_cancel() -> void:
	removal_panel.visible = false
	_removal_cb = Callable()

func _fix_removal_layout() -> void:
	await get_tree().process_frame
	removal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func _fix_picker_layout() -> void:
	await get_tree().process_frame
	picker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

func _on_game_started() -> void:
	_last_carried_text = ""
	_last_timer_secs = -1
	_last_score = -1
	_last_errors = -1
	_show_carried()
	errors_label.text = "Errores: %d" % Game.errors
	if Game.tutorial_mode:
		_show_tutorial_intro()
	# El nivel con cronómetro ya no arranca con explicación: esa información
	# vive ahora en el menú de la sección (ficha de la derecha).

func _on_repair(_pc_id: int) -> void:
	_show_carried()

# ------------------------------------------------------------------
# Modo tutorial: habitación pequeña, sin cronómetro.
# ------------------------------------------------------------------
func _build_tutorial_ui() -> void:
	tut_header = Label.new()
	tut_header.name = "TutorialHeader"
	add_child(tut_header)
	tut_header.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tut_header.offset_left = -320.0
	tut_header.offset_right = 320.0
	tut_header.offset_top = 10.0
	tut_header.offset_bottom = 46.0
	tut_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_header.add_theme_font_size_override("font_size", 24)
	tut_header.add_theme_color_override("font_color", UiStyle.CYAN)
	tut_header.visible = false

	# Abajo a la izquierda: arriba estorba.
	tut_exit_button = Button.new()
	tut_exit_button.name = "TutorialExit"
	add_child(tut_exit_button)
	tut_exit_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tut_exit_button.offset_left = 16.0
	tut_exit_button.offset_right = 236.0
	tut_exit_button.offset_top = -58.0
	tut_exit_button.offset_bottom = -16.0
	tut_exit_button.text = "VOLVER AL MENÚ"
	tut_exit_button.add_theme_font_size_override("font_size", 16)
	tut_exit_button.visible = false
	tut_exit_button.pressed.connect(_exit_tutorial)

	tut_intro = ColorRect.new()
	tut_intro.name = "TutorialIntro"
	add_child(tut_intro)
	tut_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tut_intro.color = Color(0, 0, 0, 0.88)
	tut_intro.visible = false
	_build_tutorial_intro()
	_build_tutorial_complete()

func _build_tutorial_intro() -> void:
	var center := CenterContainer.new()
	tut_intro.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)

	tut_intro_title = Label.new()
	tut_intro_title.name = "IntroTitle"
	tut_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_intro_title.add_theme_font_size_override("font_size", 44)
	box.add_child(tut_intro_title)

	tut_intro_body = RichTextLabel.new()
	tut_intro_body.bbcode_enabled = true
	tut_intro_body.custom_minimum_size = Vector2(640, 280)
	tut_intro_body.add_theme_font_size_override("font_size", 17)
	box.add_child(tut_intro_body)

	var hint := Label.new()
	tut_intro_hint = hint
	hint.text = "Recorre la habitación, examina la PC y lleva el repuesto al slot dañado.\nSin cronómetro: puedes practicar las veces que quieras."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15)
	box.add_child(hint)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 24)
	box.add_child(nav)

	tut_intro_start = Button.new()
	tut_intro_start.text = "EMPEZAR"
	tut_intro_start.custom_minimum_size = Vector2(220, 54)
	tut_intro_start.add_theme_font_size_override("font_size", 22)
	tut_intro_start.pressed.connect(_start_practice)
	nav.add_child(tut_intro_start)

	tut_intro_back = Button.new()
	tut_intro_back.text = "VOLVER"
	tut_intro_back.custom_minimum_size = Vector2(180, 54)
	tut_intro_back.add_theme_font_size_override("font_size", 22)
	tut_intro_back.pressed.connect(_exit_tutorial)
	nav.add_child(tut_intro_back)

func _build_tutorial_complete() -> void:
	tut_complete = CenterContainer.new()
	tut_complete.name = "TutorialComplete"
	add_child(tut_complete)
	tut_complete.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tut_complete.visible = false

	var panel := HoloCard.new()
	panel.custom_minimum_size = Vector2(520, 0)
	tut_complete.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	panel.add_child(box)

	var title := Label.new()
	title.name = "CompleteTitle"
	title.text = "TUTORIAL TERMINADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	tut_complete_text = Label.new()
	tut_complete_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_complete_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_complete_text.custom_minimum_size = Vector2(460, 0)
	box.add_child(tut_complete_text)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 24)
	box.add_child(nav)

	tut_repeat_button = Button.new()
	tut_repeat_button.text = "VOLVER A JUGAR"
	tut_repeat_button.custom_minimum_size = Vector2(300, 52)
	tut_repeat_button.add_theme_font_size_override("font_size", 20)
	tut_repeat_button.pressed.connect(_repeat_tutorial)
	nav.add_child(tut_repeat_button)

	tut_complete_exit = Button.new()
	tut_complete_exit.text = "REGRESAR AL MENÚ DE SELECCIÓN DE NIVEL"
	tut_complete_exit.custom_minimum_size = Vector2(500, 52)
	tut_complete_exit.add_theme_font_size_override("font_size", 18)
	tut_complete_exit.pressed.connect(_exit_tutorial)
	nav.add_child(tut_complete_exit)

func _update_tutorial_ui() -> void:
	var on := Game.tutorial_mode
	timer_label.visible = not on
	score_label.visible = not on
	errors_label.visible = not on
	tut_header.visible = on
	tut_exit_button.visible = on
	if not on:
		if _tut_part_shown != "":
			_tut_part_shown = ""
		return
	if _tut_part_shown == Game.tutorial_part:
		return
	_tut_part_shown = Game.tutorial_part
	tut_header.text = "TUTORIAL: %s" % Game.PART_TITLES.get(Game.tutorial_part, "").to_upper()

# Al entrar al tutorial se muestra el contexto: para qué sirve la pieza y qué falla.
func _show_tutorial_intro() -> void:
	Game.tutorial_active = true
	tut_complete.visible = false
	tut_intro_title.text = "TUTORIAL: %s" % Game.PART_TITLES.get(Game.tutorial_part, "").to_upper()
	tut_intro_body.text = Game.part_info_text(Game.tutorial_part)
	if Game.tutorial_part in Game.SOFTWARE_TUTORIALS:
		tut_intro_hint.text = "Recorre la habitación, pulsa E sobre la PC y resuelve el minijuego con el ratón.\nSin cronómetro y sin penalizaciones: repítelo las veces que quieras."
	else:
		tut_intro_hint.text = "Recorre la habitación, examina la PC y lleva el repuesto al slot dañado.\nSin cronómetro: puedes practicar las veces que quieras."
	tut_intro.visible = true
	UiStyle.fade_in(tut_intro)
	tut_intro_start.grab_focus.call_deferred()

func _start_practice() -> void:
	Game.tutorial_active = false
	tut_intro.visible = false

func _exit_tutorial() -> void:
	Game.tutorial_active = false
	tut_intro.visible = false
	tut_complete.visible = false
	Game.finish_tutorial()

func _repeat_tutorial() -> void:
	Game.tutorial_active = false
	tut_complete.visible = false
	Game.start_tutorial(Game.tutorial_part)

func _on_tutorial_finished() -> void:
	var title: String = Game.PART_TITLES.get(Game.tutorial_part, "la pieza")
	Game.tutorial_active = true
	# La pantalla de "tutorial terminado" queda sola, sin la PC encima.
	close_minigame()
	close_software()
	tut_complete_text.text = "Completaste el tutorial de %s. Practica de nuevo o vuelve al menú." % title
	tut_complete.visible = true
	UiStyle.fade_in(tut_complete)
	tut_repeat_button.grab_focus.call_deferred()

func _on_tutorial_exited() -> void:
	Game.tutorial_active = false
	tut_intro.visible = false
	tut_complete.visible = false
	_tut_part_shown = ""