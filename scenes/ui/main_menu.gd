extends Control

@onready var main_screen: Control = %MainScreen
@onready var level_screen: Control = %LevelScreen
@onready var controls_screen: Control = %ControlsScreen
@onready var tutorial_screen: Control = %TutorialScreen
@onready var pause_screen: Control = %PauseScreen
@onready var finish_screen: Control = %FinishScreen

@onready var play_button: Button = %PlayButton
@onready var controls_button: Button = %ControlsButton
@onready var tutorials_button: Button = %TutorialsButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_box: VBoxContainer = %VolumeBox
@onready var exit_button: Button = %ExitButton

@onready var level_buttons: Array[Button] = [%Level1Button, %Level2Button, %Level3Button]
@onready var level_back_button: Button = %LevelBackButton
@onready var controls_back_button: Button = %ControlsBackButton

@onready var tutorial_text: RichTextLabel = %TutorialText
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

func _ready() -> void:
	_screens = [main_screen, level_screen, controls_screen, tutorial_screen, pause_screen, finish_screen]

	Game.game_started.connect(_hide)
	Game.game_finished.connect(_on_finished)

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

	for i in level_buttons.size():
		level_buttons[i].pressed.connect(_start_level.bind(i + 1))

	resume_button.pressed.connect(_resume)
	restart_button.pressed.connect(_restart)
	pause_menu_button.pressed.connect(_to_menu)
	next_level_button.pressed.connect(_next_level)
	replay_button.pressed.connect(_replay)
	finish_menu_button.pressed.connect(_to_menu)

	volume_slider.value = Game.volume * 100.0
	_open_main()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Game.is_minigame_open:
			Game.hud.close_minigame()
		elif Game.state == Game.State.PLAYING:
			_show_pause()
		elif Game.state == Game.State.PAUSED:
			_resume()

func _show_screen(screen: Control) -> void:
	for s in _screens:
		s.visible = s == screen
	volume_box.visible = _screens[0] == screen
	visible = true

func _hide() -> void:
	visible = false

func _open_main() -> void:
	_show_screen(main_screen)

func _open_levels() -> void:
	for i in level_buttons.size():
		var unlocked := i < Game.unlocked_levels
		level_buttons[i].disabled = not unlocked
		level_buttons[i].text = "NIVEL %d" % (i + 1) if unlocked else "NIVEL %d - BLOQUEADO" % (i + 1)
	_show_screen(level_screen)

func _open_controls() -> void:
	_show_screen(controls_screen)

func _open_tutorials() -> void:
	_tut_page = 0
	_show_screen(tutorial_screen)
	_render_tutorial_page()

func _render_tutorial_page() -> void:
	var total := Game.TUTORIAL_PAGES.size()
	tutorial_page_label.text = "Página %d/%d" % [_tut_page + 1, total]
	tutorial_text.text = Game.TUTORIAL_PAGES[_tut_page]
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

func _start_level(idx: int) -> void:
	Game.start_level(idx)
	visible = false

func _show_pause() -> void:
	pause_info.text = "Tiempo restante: %02d:%02d" % [int(Game.time_left) / 60, int(Game.time_left) % 60]
	_show_screen(pause_screen)
	Game.pause_game()

func _resume() -> void:
	visible = false
	Game.resume_game()

func _restart() -> void:
	Game.start_level(Game.current_level)
	visible = false

func _replay() -> void:
	Game.start_level(Game.current_level)
	visible = false

func _next_level() -> void:
	if Game.current_level < Game.LEVELS.size():
		Game.start_level(Game.current_level + 1)
	visible = false

func _to_menu() -> void:
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
	next_level_button.visible = completed and Game.current_level < Game.LEVELS.size()
	_show_screen(finish_screen)

func _quit() -> void:
	get_tree().quit()