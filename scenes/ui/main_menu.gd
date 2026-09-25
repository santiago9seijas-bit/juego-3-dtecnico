extends Control

@onready var main_screen: Control = %MainScreen
@onready var level_screen: Control = %LevelScreen
@onready var controls_screen: Control = %ControlsScreen
@onready var tutorial_screen: Control = %TutorialScreen
@onready var pause_screen: Control = %PauseScreen
@onready var finish_screen: Control = %FinishScreen

@onready var title_label: HoloTitle = %TitleLabel
@onready var play_button: Button = %PlayButton
@onready var controls_button: Button = %ControlsButton
@onready var tutorials_button: Button = %TutorialsButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_box: VBoxContainer = %VolumeBox
@onready var exit_button: Button = %ExitButton

@onready var level_buttons: Array[Button] = [%Level1Button, %Level2Button, %Level3Button]
@onready var level_back_button: Button = %LevelBackButton
@onready var controls_back_button: Button = %ControlsBackButton

@onready var tutorial_options_screen: Control = %TutorialOptionsScreen
@onready var tut_ram_button: Button = %TutRamButton
@onready var tut_hdd_button: Button = %TutHddButton
@onready var tut_psu_button: Button = %TutPsuButton
@onready var tut_gpu_button: Button = %TutGpuButton
@onready var tut_mb_button: Button = %TutMbButton
@onready var tut_cpu_button: Button = %TutCpuButton
@onready var tut_fan_button: Button = %TutFanButton
@onready var tut_liquid_button: Button = %TutLiquidButton
@onready var tut_volt_button: Button = %TutVoltButton
@onready var tut_solder_button: Button = %TutSolderButton
@onready var tut_trash_button: Button = %TutTrashButton
@onready var tutorial_options_back_button: Button = %TutorialOptionsBackButton
@onready var section_level_buttons: Array[Button] = [
	%SectionLevel1Button, %SectionLevel2Button, %SectionLevel3Button,
	%SectionLevel4Button, %SectionLevel5Button, %SectionLevel6Button,
]
@onready var section_tutorials_button: Button = %SectionTutorialsButton
@onready var tutorials_pick_screen: Control = %TutorialsPickScreen
@onready var tutorials_pick_back_button: Button = %TutorialsPickBackButton
# Rótulos del menú de la sección y de la lista de tutoriales (cambian
# según el mundo al que se entra: hardware o software).
@onready var section_title: Label = $TutorialOptionsScreen/VBox/SectionTitle
@onready var pick_title: Label = $TutorialsPickScreen/VBox/PickTitle
@onready var pick_hint: Label = $TutorialsPickScreen/VBox/SectionHint
@onready var mechanics_header: Label = $TutorialsPickScreen/VBox/MechanicsHeader

@onready var tutorial_text: RichTextLabel = %TutorialText
@onready var tutorial_title: Label = %TutorialTitle
@onready var tutorial_subtitle: Label = %TutorialSubtitle
@onready var tutorial_progress: ProgressBar = %TutorialProgress
@onready var tutorial_dots: RichTextLabel = %TutorialDots
@onready var tutorial_page_label: Label = %TutorialPageLabel
@onready var tutorial_prev: Button = %TutorialPrev
@onready var tutorial_next: Button = %TutorialNext
@onready var tutorial_back_button: Button = %TutorialBackButton

@onready var pause_info: Label = %PauseInfo
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var pause_menu_button: Button = %PauseMenuButton

@onready var finish_title: Label = %FinishTitle
@onready var finish_stars: Label = %FinishStars
@onready var finish_info: Label = %FinishInfo
@onready var next_level_button: Button = %NextLevelButton
@onready var replay_button: Button = %ReplayButton
@onready var finish_menu_button: Button = %FinishMenuButton

var _screens: Array[Control] = []
var _tut_page := 0
var _tut_part_buttons: Array = []
# Sección abierta en el menú de niveles: 1 = reparación, 2 = software, 3 = servidores.
var _current_section := 1
# Los tutoriales del mundo de software (uno por minijuego, botones
# creados por código para que se monten en el menú orbital).
var _tut_software_buttons := {}
var _tut_browser_button: Button
var _tut_process_button: Button

# Fichas de la columna derecha (aparecen al pasar el mouse sobre un botón).
var _panel_level: PanelContainer
var _panel_section: PanelContainer
var _panel_pick: PanelContainer
var _info_panels: Array[PanelContainer] = []
var _info_titles := {}
var _info_bodies := {}
var _info_scrolls := {}

func _ready() -> void:
	# Se crean ANTES de aplicar el estilo para que viajen en el mismo
	# tema y en el mismo menú orbital que el resto de los tutoriales.
	_tut_software_buttons.clear()
	for part: String in Game.SOFTWARE_TUTORIALS:
		_tut_software_buttons[part] = _new_software_tut_button(part)
	# Alias que usan otros puntos del menú (y los tests).
	_tut_browser_button = _tut_software_buttons.get("download")
	_tut_process_button = _tut_software_buttons.get("processes")
	# Tema ciberpunk (neón + retícula) y animaciones para todas las pantallas.
	UiStyle.apply(self)
	# Título del manual con neón (halo cian + contorno magenta).
	UiStyle.neon_title(tutorial_title)
	_style_tutorial_screen()
	# Cada pantalla monta sus botones alrededor del agujero negro.
	_build_orbit_menus()
	_screens = [main_screen, level_screen, controls_screen, tutorial_screen, pause_screen, finish_screen, tutorial_options_screen, tutorials_pick_screen]
	# Menús de selección en dos columnas: botones a la izquierda, ficha a la derecha.
	_build_info_layout()

	Game.game_started.connect(_hide)
	Game.game_finished.connect(_on_finished)
	Game.tutorial_exited.connect(_back_to_section_menu)

	play_button.pressed.connect(_open_levels)
	controls_button.pressed.connect(_open_controls)
	tutorials_button.pressed.connect(_open_tutorials)
	volume_slider.value_changed.connect(_on_volume_changed)
	exit_button.pressed.connect(_quit)
	level_back_button.pressed.connect(_open_main)
	controls_back_button.pressed.connect(_open_main)
	tutorial_back_button.pressed.connect(_open_main)
	tutorial_prev.pressed.connect(_prev_tutorial_page)
	tutorial_next.pressed.connect(_next_tutorial_page)
	tutorial_options_back_button.pressed.connect(_open_levels)
	section_tutorials_button.pressed.connect(_open_tutorials_pick)
	tutorials_pick_back_button.pressed.connect(_open_section_menu)

	_tut_part_buttons = [
		[tut_ram_button, "ram"],
		[tut_hdd_button, "hdd"],
		[tut_psu_button, "psu"],
		[tut_gpu_button, "gpu"],
		[tut_mb_button, "mb"],
		[tut_cpu_button, "cpu"],
		[tut_fan_button, "fan"],
		[tut_liquid_button, "liquid"],
		# Mecánicas del taller (voltímetro, cautín, papelera y tuberías).
		[tut_volt_button, "volt"],
		[tut_solder_button, "solder"],
		[tut_trash_button, "trash"],
	]
	# Mundo de software: un botón por minijuego (descargas, drivers…).
	for part: String in Game.SOFTWARE_TUTORIALS:
		_tut_part_buttons.append([_tut_software_buttons[part], part])
	for entry: Array in _tut_part_buttons:
		var button: Button = entry[0]
		var part: String = entry[1]
		# Las mecánicas van en una fila: etiqueta corta ("VOLTMETRO"…).
		if part in Game.MECHANIC_TUTORIALS:
			button.text = Game.MECHANIC_SHORT.get(part, part.to_upper())
		else:
			button.text = "TUTORIAL: %s" % Game.PART_TITLES[part].to_upper()
		button.pressed.connect(_start_tutorial.bind(part))
		_wire_info(button, _panel_pick, Game.PART_TITLES[part].to_upper(), Game.part_long_text(part))

	for i in level_buttons.size():
		level_buttons[i].pressed.connect(_select_section.bind(i + 1))

	# Los 6 niveles de la sección: cada uno arranca su propia sala.
	for i in section_level_buttons.size():
		section_level_buttons[i].pressed.connect(_play_level.bind(i + 1))

	resume_button.pressed.connect(_resume)
	restart_button.pressed.connect(_restart)
	pause_menu_button.pressed.connect(_to_menu)
	next_level_button.pressed.connect(_next_level)
	replay_button.pressed.connect(_replay)
	finish_menu_button.pressed.connect(_to_menu)

	volume_slider.value = Game.volume * 100.0
	_open_main()

# ------------------------------------------------------------------
# AGUJERO NEGRO: los botones de cada pantalla dejan su columna recta
# y se curvan sobre un arco alrededor de una esfera (OrbitMenu).
# ------------------------------------------------------------------
func _build_orbit_menus() -> void:
	_orbit(main_screen, [play_button, controls_button, tutorials_button, exit_button])
	_orbit(level_screen, [level_buttons[0], level_buttons[1], level_buttons[2], level_back_button])
	var section: Array = [section_tutorials_button]
	for b in section_level_buttons:
		section.append(b)
	section.append(tutorial_options_back_button)
	_orbit(tutorial_options_screen, section)
	# Los tutoriales usan una rejilla: muchos botones en un solo arco se
	# amontonaban, sobre todo en el taller.
	_style_tutorial_grid()
	_orbit(controls_screen, [controls_back_button])
	_orbit(pause_screen, [resume_button, restart_button, pause_menu_button])
	_orbit(finish_screen, [next_level_button, replay_button, finish_menu_button])
	_orbit(tutorial_screen, [tutorial_prev, tutorial_next, tutorial_back_button])

# Mueve los botones a un OrbitMenu dentro de la caja de la pantalla
# y borra los contenedores que quedaron vacíos (fila, navegación…).
func _orbit(screen: Control, buttons: Array) -> void:
	var box := _find_box(screen)
	if box == null:
		return
	var orbit := OrbitMenu.new()
	orbit.name = "Orbit"
	if screen == tutorials_pick_screen:
		# La pantalla de tutoriales es la más cargada (las 17 prácticas
		# del juego): su arco se encoge para que ENTRE COMPLETA en la
		# ventana de 1152x648 sin recortar ningún botón.
		orbit.sphere_radius = 50.0
		orbit.side_margin = 12.0
		# Más aire entre las selecciones: en hardware se ven 10 botones y antes
		# quedaban demasiado pegados al arquearse alrededor del agujero negro.
		orbit.gap = 18.0
		orbit.max_button_width = 320.0
		orbit.max_span_deg = 175.0
	for raw in buttons:
		var button := raw as Button
		if button == null:
			continue
		var parent := button.get_parent()
		if parent:
			parent.remove_child(button)
		orbit.add_child(button)
	box.add_child(orbit)
	for i in range(box.get_child_count() - 1, -1, -1):
		var child := box.get_child(i)
		if child is Container and not (child is OrbitMenu) and child.get_child_count() == 0:
			box.remove_child(child)
			child.queue_free()

# Rejilla de tutoriales: dos columnas para que los botones del taller no
# se amontonen. Las mecánicas y VOLVER conservan su fila inferior.
func _style_tutorial_grid() -> void:
	var grid := tutorials_pick_screen.get_node_or_null("VBox/TutorialsList") as GridContainer
	if grid:
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		grid.alignment = BoxContainer.ALIGNMENT_CENTER
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.custom_minimum_size = Vector2(520, 0)
		for child in grid.get_children():
			if child is Button:
				var button := child as Button
				button.custom_minimum_size = Vector2(250, 40)
				button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				_style_tutorial_pill(button)
	for button in [tut_volt_button, tut_solder_button, tut_trash_button, tut_liquid_button, tutorials_pick_back_button]:
		if button != tutorials_pick_back_button:
			(button as Button).custom_minimum_size = Vector2(120, 40)
		_style_tutorial_pill(button as Button)

func _style_tutorial_pill(button: Button) -> void:
	if button == null or button.has_meta("tutorial_pill"):
		return
	button.set_meta("tutorial_pill", true)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var base := button.get_theme_stylebox(state, "Button") as StyleBoxFlat
		if base == null:
			continue
		var pill := base.duplicate() as StyleBoxFlat
		pill.set_corner_radius_all(20)
		button.add_theme_stylebox_override(state, pill)

# La caja de botones de la pantalla (puede estar dentro de la tarjeta).
func _find_box(screen: Control) -> VBoxContainer:
	var direct: Node = screen.get_node_or_null("VBox")
	if direct is VBoxContainer:
		return direct
	return _find_vbox_recursive(screen) as VBoxContainer

func _find_vbox_recursive(node: Node) -> Node:
	for child in node.get_children():
		if child is VBoxContainer:
			return child
		var deep: Node = _find_vbox_recursive(child)
		if deep:
			return deep
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Game.is_minigame_open and Game.hud:
			Game.hud.close_top_menu()
		elif Game.state == Game.State.PLAYING:
			_show_pause()
		elif Game.state == Game.State.PAUSED:
			_resume()
		elif tutorials_pick_screen.visible:
			_open_section_menu()
		elif tutorial_options_screen.visible:
			_open_levels()
		elif level_screen.visible:
			_open_main()
		elif tutorial_screen.visible:
			_open_main()

# ------------------------------------------------------------------
# Dos columnas en los menús de selección: los botones quedan a la
# IZQUIERDA y, a la DERECHA, aparece la ficha (imagen + párrafos)
# cuando el mouse se coloca sobre una opción.
# ------------------------------------------------------------------
func _build_info_layout() -> void:
	_panel_level = _split_columns(level_screen)
	_panel_section = _split_columns(tutorial_options_screen)
	_panel_pick = _split_columns(tutorials_pick_screen)
	# La ficha de tutoriales es más estrecha: así el conjunto (botones +
	# ficha) siempre cabe entero en la ventana.
	_panel_pick.custom_minimum_size = Vector2(430, 400)

	_wire_info(level_buttons[0], _panel_level, Game.SECTION_NAMES[0], Game.SECTION_INFO[0])
	_wire_info(level_buttons[1], _panel_level, Game.SECTION_NAMES[1], Game.SECTION_INFO[1])
	_wire_info(level_buttons[2], _panel_level, Game.SECTION_NAMES[2], Game.SECTION_INFO[2])

	# La ficha de TUTORIALES y la de cada nivel dependen del mundo abierto.
	# Las dos secciones muestran seis niveles con su etapa de dificultad.
	section_tutorials_button.mouse_entered.connect(_show_tutorials_info)
	for i in section_level_buttons.size():
		section_level_buttons[i].mouse_entered.connect(_show_section_level_info.bind(i + 1))

func _split_columns(screen: Control) -> PanelContainer:
	var card: Control = screen.get_child(0)
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 32)
	screen.add_child(columns)
	UiStyle.reparent(card, columns)
	return _build_info_panel(columns)

func _build_info_panel(columns: Control) -> PanelContainer:
	var panel: PanelContainer = HoloCard.new()
	panel.name = "InfoPanel"
	panel.custom_minimum_size = Vector2(520, 430)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Ocupa su sitio desde el inicio (sin saltos de layout) pero invisible
	# hasta que el mouse se coloca sobre un botón.
	panel.modulate.a = 0.0
	columns.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.name = "InfoScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var box := VBoxContainer.new()
	box.name = "InfoBox"
	box.add_theme_constant_override("separation", 18)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(box)

	# Espacio reservado para la imagen que se colocará después.
	var frame := PanelContainer.new()
	frame.name = "ImageFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	var stack := Control.new()
	stack.name = "ImageStack"
	stack.custom_minimum_size = Vector2(0, 180)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stack)
	var space := TextureRect.new()
	space.name = "ImageSpace"
	space.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	space.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(space)
	space.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hint := Label.new()
	hint.name = "ImageHint"
	hint.text = "[ ESPACIO PARA IMAGEN ]"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	stack.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title := Label.new()
	title.name = "InfoTitle"
	title.add_theme_font_size_override("font_size", 26)
	UiStyle.accent(title)
	box.add_child(title)

	var body := RichTextLabel.new()
	body.name = "InfoBody"
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("font_size", 17)
	box.add_child(body)

	_info_panels.append(panel)
	_info_titles[panel] = title
	_info_bodies[panel] = body
	_info_scrolls[panel] = scroll
	return panel

func _wire_info(button: Button, panel: PanelContainer, title: String, body: String) -> void:
	button.mouse_entered.connect(_show_info.bind(panel, title, body))

# La ficha se queda visible aunque el mouse salga del botón, para poder
# leerla (y bajar con la rueda) moviéndose hacia la derecha.
func _show_info(panel: PanelContainer, title: String, body: String) -> void:
	(_info_titles[panel] as Label).text = title
	(_info_bodies[panel] as RichTextLabel).text = body
	(_info_scrolls[panel] as ScrollContainer).scroll_vertical = 0
	if panel.modulate.a < 0.05:
		UiStyle.fade_in(panel)

func _show_screen(screen: Control) -> void:
	for s in _screens:
		s.visible = s == screen
	volume_box.visible = _screens[0] == screen
	# Las fichas se ocultan al cambiar de pantalla: reaparecen al pasar el mouse.
	for panel in _info_panels:
		panel.modulate.a = 0.0
	visible = true
	UiStyle.fade_in(self)
	UiStyle.enter_screen(screen)

func _hide() -> void:
	visible = false

func _open_main() -> void:
	_show_screen(main_screen)

func _open_levels() -> void:
	for i in level_buttons.size():
		var unlocked := i < Game.unlocked_levels
		level_buttons[i].disabled = not unlocked
		var section_name: String = Game.SECTION_NAMES[i]
		level_buttons[i].text = section_name if unlocked else "%s — BLOQUEADO" % section_name
	_show_screen(level_screen)

# Las secciones 1 (reparación), 2 (software) y 3 (servidores) están habilitadas.
func _select_section(idx: int) -> void:
	if idx > Game.unlocked_levels:
		return
	_current_section = idx
	_refresh_section_menu()
	_show_screen(tutorial_options_screen)

# El menú de la sección se arma según el mundo: su título y los seis
# niveles de progresión (básicos, avanzados y todo junto).
func _refresh_section_menu() -> void:
	if section_title:
		section_title.text = Game.SECTION_NAMES[_current_section - 1]
	section_tutorials_button.visible = _current_section != Game.SECTION_SERVER
	var total := Game.levels_for(_current_section).size()
	for i in section_level_buttons.size():
		section_level_buttons[i].visible = i < total
		if section_level_buttons[i].visible:
			section_level_buttons[i].text = "NIVEL %d · %s" % [i + 1, Game.level_title(i + 1, _current_section)]

# La ficha de TUTORIALES cambia según el mundo al que se entró.
func _show_tutorials_info() -> void:
	if _current_section == Game.SECTION_SOFTWARE:
		_show_info(_panel_section, "TUTORIALES", Game.SOFTWARE_TUTORIALS_MENU_TEXT)
	else:
		_show_info(_panel_section, "TUTORIALES", Game.TUTORIALS_MENU_TEXT)

# La ficha de cada nivel se arma con la sección seleccionada.
func _show_section_level_info(level_idx: int) -> void:
	_show_info(_panel_section, "NIVEL %d" % level_idx, Game.level_info_text(level_idx, _current_section))

# Botón nuevo de tutorial del mundo de software (se crea por código).
func _new_software_tut_button(part: String) -> Button:
	var button := Button.new()
	button.name = "TutSoftware%sButton" % part.capitalize()
	button.text = "TUTORIAL: %s" % Game.PART_TITLES.get(part, part).to_upper()
	button.custom_minimum_size = Vector2(250, 40)
	button.add_theme_font_size_override("font_size", 17)
	button.visible = false
	tut_ram_button.get_parent().add_child(button)
	return button

func _play_level(idx: int) -> void:
	Game.start_level(idx, _current_section)
	visible = false

# TUTORIALES (arriba de JUGAR) abre la lista de piezas, una debajo de otra.
# Cada mundo enseña lo suyo: el taller sus piezas, software sus minijuegos.
func _open_tutorials_pick() -> void:
	var software := _current_section == Game.SECTION_SOFTWARE
	for entry: Array in _tut_part_buttons:
		var part: String = entry[1]
		(entry[0] as Button).visible = (part in Game.SOFTWARE_TUTORIALS) == software
	if pick_title:
		pick_title.text = "TUTORIALES · %s" % Game.SECTION_NAMES[_current_section - 1]
	if pick_hint:
		pick_hint.text = (
			"Siete minijuegos · niveles 1-2 básicos, 3-4 avanzados y 5-6 todo junto. ESC vuelve."
			if software else
			"Piezas y mecánicas del taller, sin cronómetro. ESC vuelve."
		)
	if mechanics_header:
		mechanics_header.visible = not software
	_show_screen(tutorials_pick_screen)

func _open_section_menu() -> void:
	_show_screen(tutorial_options_screen)

# "VOLVER AL MENÚ DE NIVEL": vuelve a donde se elige tutorial o el nivel.
func _back_to_section_menu() -> void:
	_open_section_menu()

func _start_tutorial(part: String) -> void:
	Game.start_tutorial(part)
	visible = false

func _open_controls() -> void:
	_show_screen(controls_screen)

func _open_tutorials() -> void:
	_tut_page = 0
	var total := Game.TUTORIAL_PAGES.size()
	tutorial_subtitle.text = "GUIA RAPIDA · %d LECCIONES CORTAS · SIN CRONOMETRO" % total
	_show_screen(tutorial_screen)
	_render_tutorial_page()

# Marco del texto del manual y estilo de la barra de progreso.
func _style_tutorial_screen() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("070b12")
	box.border_color = Color(UiStyle.CYAN, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.shadow_size = 6
	box.shadow_color = Color(UiStyle.CYAN, 0.12)
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 16.0
	tutorial_text.add_theme_stylebox_override("normal", box)
	tutorial_text.add_theme_color_override("default_color", UiStyle.TEXT)

	var bg := StyleBoxFlat.new()
	bg.bg_color = UiStyle.BTN
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiStyle.CYAN
	fill.set_corner_radius_all(4)
	fill.shadow_size = 8
	fill.shadow_color = Color(UiStyle.CYAN, 0.6)
	tutorial_progress.add_theme_stylebox_override("background", bg)
	tutorial_progress.add_theme_stylebox_override("fill", fill)
	tutorial_subtitle.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	tutorial_subtitle.add_theme_color_override("font_outline_color", Color(UiStyle.CYAN, 0.35))
	tutorial_subtitle.add_theme_constant_override("font_outline_size", 4)
	tutorial_page_label.add_theme_color_override("font_color", UiStyle.CYAN_SOFT)

func _render_tutorial_page() -> void:
	var total := Game.TUTORIAL_PAGES.size()
	tutorial_page_label.text = "PÁGINA %d/%d" % [_tut_page + 1, total]
	tutorial_text.text = Game.TUTORIAL_PAGES[_tut_page]
	tutorial_progress.max_value = total
	tutorial_progress.value = _tut_page + 1
	# Puntitos: el de la página actual brilla en cian.
	var dots := ""
	for i in total:
		dots += "[color=#19e6ff][b]●[/b][/color]  " if i == _tut_page else "[color=#243446]●[/color]  "
	tutorial_dots.text = dots
	tutorial_prev.disabled = _tut_page == 0
	tutorial_next.disabled = _tut_page >= total - 1

func _prev_tutorial_page() -> void:
	_tut_page = maxi(0, _tut_page - 1)
	_render_tutorial_page()

func _next_tutorial_page() -> void:
	_tut_page = mini(Game.TUTORIAL_PAGES.size() - 1, _tut_page + 1)
	_render_tutorial_page()

func _on_volume_changed(value: float) -> void:
	Game.set_volume(value / 100.0)

func _show_pause() -> void:
	if Game.tutorial_mode:
		pause_info.text = "TUTORIAL: %s (sin cronómetro)" % Game.PART_TITLES.get(Game.tutorial_part, "")
	else:
		pause_info.text = "Tiempo restante: %02d:%02d" % [int(Game.time_left) / 60, int(Game.time_left) % 60]
	_show_screen(pause_screen)
	Game.pause_game()

func _resume() -> void:
	visible = false
	Game.resume_game()

func _restart() -> void:
	if Game.tutorial_mode:
		Game.start_tutorial(Game.tutorial_part)
	else:
		Game.start_level(Game.current_level, Game.current_section)
	visible = false

func _replay() -> void:
	if Game.tutorial_mode:
		Game.start_tutorial(Game.tutorial_part)
	else:
		Game.start_level(Game.current_level, Game.current_section)
	visible = false

func _next_level() -> void:
	if Game.tutorial_mode:
		return
	if Game.current_level < Game.levels_for(Game.current_section).size():
		Game.start_level(Game.current_level + 1, Game.current_section)
	visible = false

func _to_menu() -> void:
	if Game.tutorial_mode:
		# El tutorial también se abandona desde ESC → pausa.
		Game.finish_tutorial()
	else:
		Game.quit_to_menu()
	_open_main()

func _on_finished() -> void:
	var completed := Game.all_done()
	finish_title.text = "¡NIVEL COMPLETADO!" if completed else "SE ACABO EL TIEMPO"
	var stars := Game.stars_for_score()
	var star_map := {0: "☆☆☆", 1: "★☆☆", 2: "★★☆", 3: "★★★"}
	finish_stars.text = star_map.get(stars, "☆☆☆")
	finish_stars.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if stars > 0 else Color(0.55, 0.55, 0.55))
	finish_info.text = "Puntaje: %d\nErrores: %d\nTiempo restante: %02d:%02d" % [
		Game.score,
		Game.errors,
		int(Game.time_left) / 60,
		int(Game.time_left) % 60,
	]
	next_level_button.visible = completed and Game.current_level < Game.levels_for(Game.current_section).size()
	_show_screen(finish_screen)

func _quit() -> void:
	get_tree().quit()