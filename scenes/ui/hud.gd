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
# Fila del HUECO USB: botón para meter/sacar el pendrive en ESTA PC.
var software_usb_row: HBoxContainer
var software_usb_label: Label
var software_usb_button: Button
var software_content: VBoxContainer
var software_status: Label
var software_close: Button
# ---- DOS PESTAÑAS: "EL ERROR" (diagnóstico) y "PENDRIVE" ------------
var software_tabs: HBoxContainer
var software_tab_error: Button
var software_tab_usb: Button
var software_page_error: VBoxContainer
var software_page_usb: VBoxContainer
var software_usb_title: Label
var software_usb_items: VBoxContainer
var software_usb_slots: VBoxContainer
var software_usb_head_left: Label
var software_usb_head_right: Label
var software_usb_extra: VBoxContainer
var software_usb_install: Button
var software_usb_status: Label
var _soft_tab := "error"
var _soft_pc: Node = null
# Corta señales duplicadas: si un minijuego emite `finished` dos veces
# (dos relojes), solo se cierra y repara una sola.
var _soft_done := false

# UI propia del modo tutorial (se construye una sola vez en _ready).
var tut_header: Label
var tut_exit_button: Button
var tut_intro: ColorRect
var tut_intro_title: Label
var tut_intro_body: RichTextLabel
var tut_intro_start: Button
var tut_intro_back: Button
var tut_intro_hint: Label
# Cajas que se recolocan al abrir cada pantalla según el tamaño de ventana.
var tut_intro_margin: MarginContainer
var tut_complete_panel: Control
var tut_complete: CenterContainer
var tut_repeat_button: Button
var tut_complete_exit: Button
var tut_complete_text: Label

var _tut_part_shown := ""
var _last_carried_text := ""
var _last_pd_text := ""
var _last_usb_text := ""
var _last_timer_secs := -1
var _last_score := -1
var _last_errors := -1
var _score_tween: Tween
var _last_timer_outline := Color(-1.0, -1.0, -1.0)

func _ready() -> void:
	Game.hud = self
	Game.game_started.connect(_on_game_started)
	Game.game_finished.connect(close_all_menus)
	Game.tutorial_exited.connect(close_all_menus)
	Game.tutorial_finished.connect(close_all_menus)
	Game.tutorial_finished.connect(_on_tutorial_finished)
	Game.tutorial_exited.connect(_on_tutorial_exited)
	# El marcador de PCs se refresca al instante (el último reparo ocurre
	# justo cuando el nivel pasa a terminado y _process ya no pinta nada).
	Game.task_completed.connect(_on_task_progress)
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
		# El enchufe cambia también sin que se mueva el contenido (al
		# meter o sacar el pendrive): se repinta su fila y la pestaña.
		_refresh_software_usb()
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
	# Tiempo y latido cuantizados: el color solo cambia ~10 veces por
	# segundo (o al 1%) y así NO se repinta el rótulo en CADA frame.
	var ratio := clampf(Game.time_left / total, 0.0, 1.0)
	ratio = float(int(ratio * 100.0)) / 100.0
	var urgency := clampf(1.0 - ratio / 0.35, 0.0, 1.0)
	var col := UiStyle.CYAN.lerp(Color(1.0, 0.3, 0.32), urgency)
	if urgency > 0.01:
		var tick := float(int(Time.get_ticks_msec() / 90)) * 0.012
		var pulse := 0.5 + 0.5 * sin(tick * (0.5 + urgency))
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
	# Mundo de software: aquí no hay mochila, así que el rótulo pasa a ser
	# el MARCADOR de la sala (X de 7 PCs listas). En tutorial no se anota
	# nada, así que se avisa de que es práctica libre. De paso no se
	# recalcula inventario en cada frame.
	if Game.uses_software_room():
		var sw_text := "TUTORIAL · sin cronómetro y sin penalizaciones"
		var sw_color := UiStyle.CYAN_SOFT
		if not Game.tutorial_mode:
			sw_text = "PCs reparadas: %d/%d" % [Game.repaired.size(), Game.task_count]
			sw_color = Color(0.3, 1.0, 0.5) if Game.repaired.size() >= Game.task_count else UiStyle.CYAN
		if sw_text != _last_carried_text:
			_last_carried_text = sw_text
			carried_label.text = sw_text
			carried_label.add_theme_color_override("font_color", sw_color)
		return
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

# Cierra TODO de un golpe. Se usa cuando la partida termina (se acabó el
# tiempo), al salir del tutorial y al arrancar un nivel: si no, la ventana
# de software seguiría montada sobre el resumen o sobre el menú.
func close_all_menus() -> void:
	if removal_panel and removal_panel.visible:
		_on_removal_cancel()
	if picker and picker.visible:
		close_picker()
	if software_panel and software_panel.visible:
		close_software()
	if minigame and minigame.visible:
		close_minigame()
	Game.is_minigame_open = false

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

	# ---------------- DOS PESTAÑAS ------------------------------------
	# Pestaña 1 "EL ERROR": qué le pasa a esta PC, el hueco USB y el
	# diagnóstico. Pestaña 2 "PENDRIVE": el contenido del pendrive y los
	# huecos de esta PC, para arrastrar de un lado a otro y darle a
	# INSTALAR. La 2ª solo existe mientras el pendrive está enchufado aquí.
	software_tabs = HBoxContainer.new()
	software_tabs.name = "SoftwareTabs"
	software_tabs.add_theme_constant_override("separation", 10)
	box.add_child(software_tabs)
	var tab_group := ButtonGroup.new()
	software_tab_error = _software_tab_button(tab_group, "EL ERROR", UiStyle.AMBER)
	software_tabs.add_child(software_tab_error)
	software_tab_usb = _software_tab_button(tab_group, "PENDRIVE", UiStyle.CYAN)
	software_tabs.add_child(software_tab_usb)

	# ---------------- Pestaña 1 · EL ERROR ---------------------------
	software_page_error = VBoxContainer.new()
	software_page_error.name = "PageError"
	software_page_error.size_flags_vertical = Control.SIZE_EXPAND_FILL
	software_page_error.add_theme_constant_override("separation", 12)
	box.add_child(software_page_error)

	software_symptom = Label.new()
	software_symptom.name = "SoftwareSymptom"
	software_symptom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	software_symptom.add_theme_font_size_override("font_size", 15)
	software_symptom.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	software_page_error.add_child(software_symptom)

	# Contenido del pendrive: el jugador siempre ve qué le falta llevar.
	software_pendrive = Label.new()
	software_pendrive.name = "SoftwarePendrive"
	software_pendrive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	software_pendrive.add_theme_font_size_override("font_size", 14)
	software_pendrive.add_theme_color_override("font_color", UiStyle.CYAN_SOFT)
	software_page_error.add_child(software_pendrive)

	# HUECO USB: el pendrive hay que METERLO en la PC para que esta PC
	# pueda bajar o instalar lo que necesita (y sacarlo para llevarlo a otra).
	software_usb_row = HBoxContainer.new()
	software_usb_row.name = "SoftwareUsb"
	software_usb_row.add_theme_constant_override("separation", 12)
	software_page_error.add_child(software_usb_row)

	software_usb_label = Label.new()
	software_usb_label.name = "SoftwareUsbLabel"
	software_usb_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	software_usb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	software_usb_label.add_theme_font_size_override("font_size", 15)
	software_usb_row.add_child(software_usb_label)

	software_usb_button = Button.new()
	software_usb_button.name = "SoftwareUsbButton"
	software_usb_button.custom_minimum_size = Vector2(250, 40)
	software_usb_button.add_theme_font_size_override("font_size", 15)
	software_usb_button.pressed.connect(_on_usb_pressed)
	software_usb_row.add_child(software_usb_button)

	software_content = VBoxContainer.new()
	software_content.name = "SoftwareContent"
	software_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# El minijuego se desliza DENTRO de la ventana: nada se sale de la
	# pantalla ni se queda cortado aunque la ventana sea pequeña.
	var software_scroll := ScrollContainer.new()
	software_scroll.name = "SoftwareScroll"
	software_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	software_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	software_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	software_page_error.add_child(software_scroll)
	software_scroll.add_child(software_content)

	software_status = Label.new()
	software_status.name = "SoftwareStatus"
	software_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	software_status.add_theme_font_size_override("font_size", 15)
	software_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	software_page_error.add_child(software_status)

	# ---------------- Pestaña 2 · PENDRIVE ---------------------------
	_build_software_usb_page(box)
	# Tema ciberpunk + animación del botón (el resto llega por herencia).
	UiStyle.apply(software_panel)

# Botón de pestaña (conmutador): el que se pilla se queda resaltado.
func _software_tab_button(group: ButtonGroup, text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(190, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", color)
	b.pressed.connect(func() -> void: _show_software_tab("error" if b == software_tab_error else "usb"))
	return b

# Construye la pestaña 2: pendrive a la IZQUIERDA, huecos de esta PC a la
# DERECHA y el botón INSTALAR debajo. Se repinta entera cuando cambia algo.
func _build_software_usb_page(parent: VBoxContainer) -> void:
	software_page_usb = VBoxContainer.new()
	software_page_usb.name = "PageUsb"
	software_page_usb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	software_page_usb.add_theme_constant_override("separation", 8)
	software_page_usb.visible = false
	parent.add_child(software_page_usb)

	software_usb_title = Label.new()
	software_usb_title.name = "UsbTitle"
	software_usb_title.add_theme_font_size_override("font_size", 17)
	software_usb_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	software_usb_title.add_theme_color_override("font_color", UiStyle.CYAN_SOFT)
	software_page_usb.add_child(software_usb_title)

	# Las dos columnas van dentro de un scroll para que la ventana nunca
	# crezca más de la pantalla aunque el pendrive venga lleno.
	var scroll := ScrollContainer.new()
	scroll.name = "UsbScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	software_page_usb.add_child(scroll)

	var columns := HBoxContainer.new()
	columns.name = "UsbColumns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	scroll.add_child(columns)

	var left := _usb_column(columns, "Pendrive", "EN EL PENDRIVE", UiStyle.CYAN)
	software_usb_head_left = left.get_child(0) as Label
	software_usb_items = VBoxContainer.new()
	software_usb_items.name = "UsbItems"
	software_usb_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	software_usb_items.add_theme_constant_override("separation", 7)
	left.add_child(software_usb_items)

	var right := _usb_column(columns, "Huecos", "LO QUE PIDE ESTA PC", UiStyle.MAGENTA)
	software_usb_head_right = right.get_child(0) as Label
	software_usb_slots = VBoxContainer.new()
	software_usb_slots.name = "UsbSlots"
	software_usb_slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	software_usb_slots.add_theme_constant_override("separation", 7)
	right.add_child(software_usb_slots)

	# Zona extra: aquí el minijuego puede meter sus propios controles
	# (idioma, avisos…). Se vacía con free() porque son suyos.
	software_usb_extra = VBoxContainer.new()
	software_usb_extra.name = "UsbExtra"
	software_usb_extra.add_theme_constant_override("separation", 7)
	software_page_usb.add_child(software_usb_extra)

	software_usb_install = Button.new()
	software_usb_install.name = "UsbInstall"
	software_usb_install.text = "INSTALAR"
	software_usb_install.custom_minimum_size = Vector2(0, 46)
	software_usb_install.add_theme_font_size_override("font_size", 18)
	software_usb_install.disabled = true
	software_usb_install.pressed.connect(_on_usb_install)
	software_page_usb.add_child(software_usb_install)

	software_usb_status = Label.new()
	software_usb_status.name = "UsbStatus"
	software_usb_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	software_usb_status.add_theme_font_size_override("font_size", 14)
	software_usb_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	software_page_usb.add_child(software_usb_status)

# Títulos de las dos columnas: cada minijuego puede renombrarlas desde su
# usb_spec() (por ejemplo el navegador: nada está aún "en el pendrive").
func _set_usb_heads(left_text: String, right_text: String) -> void:
	if software_usb_head_left != null:
		software_usb_head_left.text = left_text
	if software_usb_head_right != null:
		software_usb_head_right.text = right_text

func _usb_column(parent: Container, key: String, title: String, color: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "UsbCol_%s" % key
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.85)
	style.set_border_width_all(1)
	style.border_color = Color(color.r, color.g, color.b, 0.5)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", color)
	box.add_child(head)
	return box

# ------------------------------------------------------------------
# Cambio de pestaña
# ------------------------------------------------------------------
func _usb_tab_available() -> bool:
	if _soft_pc == null or software_page_usb == null:
		return false
	var kind := str(_soft_pc.get("kind"))
	if not Game.usb_needed(kind):
		return false
	var pc_number := 0
	if _soft_pc.get("pc_id") != null:
		pc_number = int(_soft_pc.pc_id)
	return Game.pendrive_in(pc_number)

func _show_software_tab(which: String) -> void:
	if software_page_usb == null:
		return
	if which == "usb" and not _usb_tab_available():
		which = "error"
	_soft_tab = which
	software_tab_usb.visible = _usb_tab_available()
	software_page_error.visible = which != "usb"
	software_page_usb.visible = which == "usb"
	software_tab_error.button_pressed = which != "usb"
	software_tab_usb.button_pressed = which == "usb"
	if which == "usb":
		_rebuild_usb_page()

func _clear_usb_page() -> void:
	if software_usb_items == null:
		return
	_free_children(software_usb_items)
	_free_children(software_usb_slots)
	_free_children(software_usb_extra)

# Se SACAN del árbol y se destruyen al terminar el frame: no se puede
# free() una ficha mientras ella misma está emitiendo `dropped`.
func _free_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _software_minigame() -> Node:
	if software_content == null or software_content.get_child_count() == 0:
		return null
	return software_content.get_child(0)

# Pinta la pestaña PENDRIVE: contenido a la izquierda, huecos a la derecha.
func _rebuild_usb_page() -> void:
	if software_usb_items == null or _soft_pc == null:
		return
	_clear_usb_page()
	software_usb_status.text = ""
	software_usb_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)

	var mg := _software_minigame()
	if mg == null or not mg.has_method("usb_spec"):
		software_usb_title.text = "PENDRIVE · %s" % Game.pendrive_names()
		_set_usb_heads("EN EL PENDRIVE", "LO QUE PIDE ESTA PC")
		software_usb_install.disabled = true
		software_usb_status.text = "Esta PC trabaja con lo que ya llevas en el pendrive."
		return

	var spec: Dictionary = mg.usb_spec()
	_set_usb_heads(
		str(spec.get("source_title", "EN EL PENDRIVE")),
		str(spec.get("slots_title", "LO QUE PIDE ESTA PC")))
	var accent: Color = SoftwarePC.KIND_COLORS.get(str(_soft_pc.get("kind")), UiStyle.CYAN)
	software_usb_title.text = "PENDRIVE · %s" % Game.pendrive_names()
	software_usb_title.add_theme_color_override("font_color", accent)
	var drops: Dictionary = mg.usb_drops() if mg.has_method("usb_drops") else {}

	# Izquierda: lo que se puede arrastrar.
	var source: Array = spec.get("source", Game.pendrive)
	var source_titles: Dictionary = spec.get("source_titles", {})
	var placed := {}
	for key in drops:
		placed[str(drops[key])] = true
	for raw_id in source:
		var id := str(raw_id)
		var info: Dictionary = Game.SW_ITEMS.get(id, {})
		var title := str(source_titles.get(id, info.get("name", id)))
		var sub := "%s · %s" % [info.get("file", ""), info.get("size", "")]
		if placed.has(id):
			sub = "ya colocado en un hueco"
		software_usb_items.add_child(UsbPiece.make(
			"item", id, title, sub, accent, [], id if placed.has(id) else ""))

	# Derecha: los huecos que pide esta PC.
	var slots: Array = spec.get("slots", [])
	for raw_slot in slots:
		var slot: Dictionary = raw_slot
		var slot_id := str(slot.get("id", ""))
		var filled := str(drops.get(slot_id, ""))
		var accept_ids: Array = slot.get("accept", [])
		var piece := UsbPiece.make(
			"slot", slot_id, str(slot.get("title", "Hueco")),
			str(slot.get("hint", "arrastra aquí el archivo")), accent, accept_ids, filled)
		piece.dropped.connect(_on_usb_drop)
		software_usb_slots.add_child(piece)

	if mg.has_method("usb_build_extra"):
		mg.usb_build_extra(software_usb_extra)

	software_usb_install.text = str(spec.get("install_text", "INSTALAR"))
	software_usb_install.disabled = not bool(mg.usb_ready()) if mg.has_method("usb_ready") else true
	var hint := str(spec.get("hint", ""))
	if hint != "":
		software_usb_status.text = hint
		software_usb_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)

# Arrastrar una ficha del pendrive a un hueco de esta PC.
func _on_usb_drop(slot_id: String, item_id: String) -> void:
	usb_drop(slot_id, item_id)

# API pública (también la usan las pruebas): ¿acepta el minijuego esa
# ficha en ese hueco? Si la acepta, la página se repinta para que se vea
# el hueco relleno y se active su botón.
func usb_drop(slot_id: String, item_id: String) -> bool:
	var mg := _software_minigame()
	if mg == null or not mg.has_method("usb_drop"):
		return false
	var ok: bool = mg.usb_drop(slot_id, item_id)
	if not ok:
		software_usb_status.text = "✗ Ese archivo no va en ese hueco."
		software_usb_status.add_theme_color_override("font_color", UiStyle.RED)
		return false
	software_usb_status.text = ""
	_rebuild_usb_page()
	return true

# Botón INSTALAR de la pestaña PENDRIVE.
func _on_usb_install() -> void:
	var mg := _software_minigame()
	if mg == null or not mg.has_method("usb_install"):
		return
	var res: Variant = mg.usb_install()
	if res is Dictionary and not bool(res.get("ok", false)):
		software_usb_status.text = str(res.get("msg", "No se puede instalar todavía."))
		software_usb_status.add_theme_color_override("font_color", UiStyle.RED)
		return
	# Al instalar, el resultado (barra de progreso, cartel verde…) sale en
	# la pestaña EL ERROR: la pasamos sola para que el jugador lo vea.
	_rebuild_usb_page()
	_show_software_tab("error")
	software_status.text = str(res.get("msg", "Instalando…")) if res is Dictionary else "Instalando…"
	software_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)


func open_software(pc: Node) -> void:
	if pc == null or software_panel == null:
		return
	# La ventana se ajusta al tamaño real de la pantalla: nunca más
	# ancha ni más alta que la ventana que la contiene.
	var vp: Vector2 = get_viewport().get_visible_rect().size
	software_panel.custom_minimum_size = Vector2(minf(940.0, vp.x - 40.0), minf(580.0, vp.y - 40.0))
	if pc.get("pc_id") != null and int(pc.pc_id) in Game.repaired:
		return
	_soft_pc = pc
	_soft_done = false
	_soft_tab = "error"
	if software_page_usb:
		software_page_usb.visible = false
		software_page_error.visible = true
	var kind := str(pc.get("kind"))
	software_title.text = "PC %d · %s" % [int(pc.pc_id), Game.PART_TITLES.get(kind, "PC")]
	# El título toma el color propio de la estación (mismo color que su
	# rótulo 3D y su pantalla) para distinguir de un vistazo de qué PC es.
	var accent: Color = SoftwarePC.KIND_COLORS.get(kind, UiStyle.CYAN)
	software_title.add_theme_color_override("font_color", accent)
	software_title.add_theme_color_override("font_outline_color", Color(accent.r, accent.g, accent.b, 0.45))
	software_symptom.text = "SÍNTOMA: %s" % str(pc.get("symptom"))
	_last_pd_text = ""
	_last_usb_text = ""
	_refresh_software_pendrive()
	_clear_software_content()
	var cls: GDScript = MINIGAMES.get(kind, BrowserMinigame)
	var node := cls.new() as Control
	software_content.add_child(node)
	# Estado por PC: cerrar la ventana no pierde descargas ni instalaciones.
	var soft_state: Dictionary = pc.get("state") if pc.get("state") != null else {}
	# El minijuego recibe además EN QUÉ PC está abierto: así el hueco USB
	# solo deja bajar o instalar cuando el pendrive está metido allí.
	var pc_number := 0
	if pc.get("pc_id") != null:
		pc_number = int(pc.pc_id)
	node.setup(soft_state, pc.get("task") if "task" in pc else {}, pc_number)
	node.finished.connect(_on_software_done)
	software_status.text = "Resuelve la tarea para reparar esta PC. ESC la cierra sin perder el avance."
	software_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	software_panel.visible = true
	software_host.visible = true
	Game.is_minigame_open = true
	# Pestaña PENDRIVE: se prepara al abrir (oculta) para que, en cuanto
	# metas el pendrive, aparezca sola con su contenido y sus huecos.
	_clear_usb_page()
	if _usb_tab_available():
		_rebuild_usb_page()
	_show_software_tab("error")

# Rótulo vivo del pendrive (se repinta en cada frame mientras hay ventana).
# Además de lo que lleva, dice QUÉ LE FALTA a la PC que está abierta: así
# el jugador ve de un vistazo si tiene que volver a la PC de INTERNET.
func _refresh_software_pendrive() -> void:
	if software_pendrive == null:
		return
	var text := "PENDRIVE · contiene: %s" % Game.pendrive_names()
	var color := UiStyle.CYAN_SOFT
	var kind := ""
	var items: Array = []
	if _soft_pc != null:
		kind = str(_soft_pc.get("kind"))
		var task: Variant = _soft_pc.get("task")
		if task is Dictionary:
			items = task.get("items", [])
	if not items.is_empty():
		var pending: Array = []
		for id: Variant in items:
			if not Game.pendrive_has(str(id)):
				pending.append(str(Game.SW_ITEMS.get(str(id), {}).get("short", id)))
		if kind == "download":
			# La PC de INTERNET es la fuente: muestra lo que aún no baja.
			if pending.is_empty():
				text += "\n✓ Ya bajaste todo lo que piden las otras PCs."
				color = Color(0.3, 1.0, 0.5)
			else:
				text += "\nPOR BAJAR: %s · lo piden las otras PCs." % ", ".join(pending)
				color = Color(1.0, 0.69, 0.13)
		elif kind == "os_install" or kind == "os_swap":
			# Cualquier imagen sirve: basta con que haya UNA en el pendrive.
			if pending.size() >= items.size():
				text += "\nFALTA: una imagen de sistema (Windows, macOS o Linux) · ve a la PC de INTERNET."
				color = Color(1.0, 0.45, 0.4)
			else:
				text += "\n✓ Ya tienes una imagen de sistema en el pendrive."
				color = Color(0.3, 1.0, 0.5)
		elif pending.is_empty():
			text += "\n✓ listo para esta PC."
			color = Color(0.3, 1.0, 0.5)
		else:
			text += "\nFALTA PARA ESTA PC: %s · ve a la PC de INTERNET." % ", ".join(pending)
			color = Color(1.0, 0.45, 0.4)
	# Cache: solo se repinta cuando el contenido cambia de verdad.
	if text == _last_pd_text:
		return
	_last_pd_text = text
	software_pendrive.text = text
	software_pendrive.add_theme_color_override("font_color", color)
	_refresh_software_usb()
	# Si el jugador está mirando el pendrive, su contenido cambió: se repinta.
	if _soft_tab == "usb" and software_page_usb != null and software_page_usb.visible:
		_rebuild_usb_page()

# Botón del HUECO USB: meter el pendrive en esta PC (si estaba en otra
# sale solo de ahí) o sacarlo para llevárselo a otra PC.
func _on_usb_pressed() -> void:
	if _soft_pc == null:
		return
	var pc_id := int(_soft_pc.get("pc_id"))
	if Game.pendrive_in(pc_id):
		Game.pendrive_unplug()
		show_message("Pendrive sacado de la PC %d" % pc_id)
	else:
		Game.pendrive_plug(pc_id)
		show_message("¡Pendrive metido en la PC %d!" % pc_id)
	_last_pd_text = ""
	_last_usb_text = ""
	_refresh_software_pendrive()
	# El minijuego repinta lo que depende del pendrive (pastillas,
	# listas de sistemas…): aquí solo cambia el enchufe, no su contenido.
	var kids: Array = software_content.get_children()
	if not kids.is_empty() and kids[0].has_method("refresh_usb"):
		kids[0].call("refresh_usb")
	# Al meter el pendrive APARECE sola la pestaña PENDRIVE con su
	# contenido; al sacarlo se vuelve al diagnóstico.
	_show_software_tab("usb" if Game.pendrive_in(int(_soft_pc.get("pc_id"))) else "error")

# Estado del hueco USB: siempre visible en las PCs que exigen pendrive,
# con el botón grande de INSERTAR cuando falta (nadie puede perderse eso).
func _refresh_software_usb() -> void:
	if software_usb_row == null or software_usb_label == null or _soft_pc == null:
		return
	var kind := str(_soft_pc.get("kind"))
	software_usb_row.visible = Game.usb_needed(kind)
	# La pestaña PENDRIVE solo existe mientras el pendrive está metido aquí:
	# si se saca, la ventana vuelve sola al diagnóstico.
	if software_tab_usb:
		software_tab_usb.visible = _usb_tab_available()
		if _soft_tab == "usb" and not software_tab_usb.visible:
			_show_software_tab("error")
	if not software_usb_row.visible:
		return
	var pc_id := int(_soft_pc.get("pc_id"))
	var plugged := Game.pendrive_in(pc_id)
	var text: String
	var color: Color
	var button_text: String
	var button_color: Color
	if plugged:
		text = "HUECO USB · ✓ PENDRIVE METIDO EN ESTA PC — ya puedes descargar e instalar."
		color = Color(0.3, 1.0, 0.5)
		button_text = "SACAR PENDRIVE"
		button_color = Color(0.55, 0.62, 0.7)
	else:
		var where := ""
		if Game.pendrive_pc > 0:
			where = " (está en la PC %d: sácalo de ahí)" % Game.pendrive_pc
		text = "HUECO USB · ✗ EL PENDRIVE NO ESTÁ METIDO EN ESTA PC%s. Sin él no se baja ni se instala nada." % where
		color = Color(1.0, 0.55, 0.2)
		button_text = "INSERTAR PENDRIVE"
		button_color = Color(1.0, 0.69, 0.13)
	if text + str(button_text) != _last_usb_text:
		_last_usb_text = text + str(button_text)
		software_usb_label.text = text
		software_usb_label.add_theme_color_override("font_color", color)
		software_usb_button.text = button_text
		software_usb_button.add_theme_color_override("font_color", button_color)
		software_usb_button.add_theme_color_override("font_hover_color", button_color.lightened(0.3))

func close_software() -> void:
	if software_panel:
		software_panel.visible = false
	if software_host:
		software_host.visible = false
	_clear_software_content()
	_soft_pc = null
	_soft_tab = "error"
	_clear_usb_page()
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
	if _soft_pc == null or _soft_done:
		return
	_soft_done = true
	call_deferred("_close_and_repair", _soft_pc)

func _close_and_repair(pc: Node) -> void:
	if not is_instance_valid(pc):
		return
	_soft_pc = null
	close_software()
	# Si la partida ya terminó (se acabó el tiempo con la ventana abierta),
	# la ventana se cierra pero NO se anota nada nuevo: el resumen ya está
	# pintado en pantalla.
	if Game.state != Game.State.PLAYING:
		return
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
	# Arranca un nivel nuevo: no puede heredar ninguna ventana abierta.
	close_all_menus()
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

# Cada PC reparada refresca el marcador de la sala (se llama también con
# la última, justo antes de que el nivel pase a terminado).
func _on_task_progress(_pc_id: int) -> void:
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
	# El panel ocupa la ventana con margen y NUNCA la desborda: el cuerpo
	# se desliza dentro de un scroll y los botones quedan siempre a la vista.
	var margin := MarginContainer.new()
	margin.name = "IntroMargin"
	tut_intro.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	tut_intro_margin = margin

	var box := VBoxContainer.new()
	box.name = "IntroBox"
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	tut_intro_title = Label.new()
	tut_intro_title.name = "IntroTitle"
	tut_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_intro_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_intro_title.add_theme_font_size_override("font_size", 34)
	box.add_child(tut_intro_title)

	# El cuerpo (QUE ES LO MÁS LARGO) vive dentro de un scroll: si no cabe,
	# se desliza en vez de cortarse o de echar los botones de la ventana.
	var scroll := ScrollContainer.new()
	scroll.name = "IntroScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	tut_intro_body = RichTextLabel.new()
	tut_intro_body.bbcode_enabled = true
	tut_intro_body.fit_content = true
	tut_intro_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tut_intro_body.add_theme_font_size_override("font_size", 17)
	scroll.add_child(tut_intro_body)

	var hint := Label.new()
	tut_intro_hint = hint
	hint.text = "Recorre la habitación, examina la PC y lleva el repuesto al slot dañado.\nSin cronómetro: puedes practicar las veces que quieras."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15)
	box.add_child(hint)

	# LA NAVEGACIÓN FUERA DEL SCROLL: EMPEZAR y VOLVER se ven siempre.
	var nav := HBoxContainer.new()
	nav.name = "IntroNav"
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
	tut_complete_panel = panel

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)

	var title := Label.new()
	title.name = "CompleteTitle"
	title.text = "TUTORIAL TERMINADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	tut_complete_text = Label.new()
	tut_complete_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_complete_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_complete_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(tut_complete_text)

	# Los botones van APILADOS (uno debajo del otro): así nunca se pasan
	# del ancho de la ventana y siguen estando siempre completos a la vista.
	var nav := VBoxContainer.new()
	nav.name = "CompleteNav"
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 14)
	box.add_child(nav)

	tut_repeat_button = Button.new()
	tut_repeat_button.text = "VOLVER A JUGAR"
	tut_repeat_button.custom_minimum_size = Vector2(420, 52)
	tut_repeat_button.add_theme_font_size_override("font_size", 20)
	tut_repeat_button.pressed.connect(_repeat_tutorial)
	nav.add_child(tut_repeat_button)

	tut_complete_exit = Button.new()
	tut_complete_exit.text = "VOLVER AL MENÚ DE NIVELES"
	tut_complete_exit.custom_minimum_size = Vector2(420, 52)
	tut_complete_exit.add_theme_font_size_override("font_size", 18)
	tut_complete_exit.pressed.connect(_exit_tutorial)
	nav.add_child(tut_complete_exit)

# Ajusta las dos pantallas de tutorial al tamaño REAL de la ventana: el
# ancho del texto se adapta y, si la ventana es estrecha, los botones se
# encogen con ella. Se recalcula cada vez que una pantalla se enseña.
func _fit_tutorial_screens() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if tut_intro_margin:
		var intro_w := minf(780.0, vp.x - 48.0)
		var side := maxi(16, int((vp.x - intro_w) * 0.5))
		tut_intro_margin.add_theme_constant_override("margin_left", side)
		tut_intro_margin.add_theme_constant_override("margin_right", side)
	if tut_complete_panel:
		var card_w := minf(560.0, vp.x - 40.0)
		tut_complete_panel.custom_minimum_size = Vector2(card_w, 0)
		var btn_w := maxf(220.0, minf(440.0, vp.x - 96.0))
		tut_repeat_button.custom_minimum_size = Vector2(btn_w, 52)
		tut_complete_exit.custom_minimum_size = Vector2(btn_w, 52)

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
	_fit_tutorial_screens()
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
	_fit_tutorial_screens()
	tut_complete_text.text = "Completaste el tutorial de %s. Practica de nuevo o vuelve al menú." % title
	tut_complete.visible = true
	UiStyle.fade_in(tut_complete)
	tut_repeat_button.grab_focus.call_deferred()

func _on_tutorial_exited() -> void:
	Game.tutorial_active = false
	tut_intro.visible = false
	tut_complete.visible = false
	_tut_part_shown = ""