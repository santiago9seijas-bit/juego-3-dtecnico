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
@onready var tutorial_overlay: Control = %TutorialOverlay
@onready var tutorial_text: RichTextLabel = %TutorialText
@onready var tutorial_page_label: Label = %TutorialPageLabel
@onready var tutorial_prev: Button = %TutorialPrev
@onready var tutorial_next: Button = %TutorialNext
@onready var tutorial_continue: Button = %TutorialContinue
@onready var tutorial_skip: Button = %TutorialSkip

var _msg_until := 0.0
var _removal_cb: Callable = Callable()
var _tut_pages: Array = []
var _tut_page := 0

func _ready() -> void:
	Game.hud = self
	Game.game_started.connect(_on_game_started)
	minigame.repaired.connect(_on_repair)
	message_label.visible = false
	picker.visible = false
	picker_cancel.pressed.connect(close_picker)
	removal_panel.visible = false
	removal_panel.done.connect(_on_removal_done)
	removal_panel.cancel.connect(_on_removal_cancel)
	tutorial_continue.pressed.connect(_end_tutorial)
	tutorial_skip.pressed.connect(_skip_tutorial)
	tutorial_prev.pressed.connect(_prev_tutorial_page)
	tutorial_next.pressed.connect(_next_tutorial_page)

func _process(delta: float) -> void:
	var playing := Game.state == Game.State.PLAYING
	gameplay_root.visible = playing
	if playing:
		timer_label.text = "Tiempo: %02d:%02d" % [int(Game.time_left) / 60, int(Game.time_left) % 60]
		score_label.text = "Puntaje: %d" % Game.score
		errors_label.text = "Errores: %d" % Game.errors
		_show_carried()
		if _msg_until > 0.0:
			_msg_until -= delta
			if _msg_until <= 0.0:
				message_label.visible = false

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

func _show_carried() -> void:
	if Game.carried_parts.is_empty():
		carried_label.text = "Llevas: —"
	else:
		var names: Array = []
		for part in Game.carried_parts:
			names.append(part.name)
		carried_label.text = "Llevas (%d/%d): %s" % [Game.carried_parts.size(), Game.MAX_CARRIED, ", ".join(names)]

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
	picker_title.text = "Estantería de %s — elige el modelo:" % Game.PART_TITLES.get(part_type, part_type)
	for child in picker_list.get_children():
		child.free()
	for variant in Game.PART_VARIANTS[part_type]:
		var button := Button.new()
		button.text = variant.name
		button.pressed.connect(_on_variant_picked.bind(variant))
		picker_list.add_child(button)
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

func open_removal(part_type: String, on_done: Callable, reverse := false) -> void:
	_removal_cb = on_done
	removal_panel.open(part_type, reverse)
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
	_show_carried()
	errors_label.text = "Errores: %d" % Game.errors
	_show_level_tutorial()

func _show_level_tutorial() -> void:
	Game.tutorial_active = true
	_tut_pages = Game.TUTORIAL_PAGES.duplicate()
	_tut_pages.insert(0, "NIVEL %d\n\n%s" % [Game.current_level, Game.tutorial_level_text()])
	_tut_page = 0
	_render_tutorial_page()
	tutorial_overlay.visible = true
	await get_tree().process_frame
	if tutorial_continue:
		tutorial_continue.grab_focus()

func _render_tutorial_page() -> void:
	tutorial_text.text = _tut_pages[_tut_page]
	tutorial_page_label.text = "Página %d/%d" % [_tut_page + 1, _tut_pages.size()]
	tutorial_prev.disabled = _tut_page == 0
	tutorial_next.disabled = _tut_page >= _tut_pages.size() - 1
	tutorial_continue.visible = _tut_page == _tut_pages.size() - 1

func _prev_tutorial_page() -> void:
	_tut_page = maxi(0, _tut_page - 1)
	_render_tutorial_page()

func _next_tutorial_page() -> void:
	_tut_page = mini(_tut_pages.size() - 1, _tut_page + 1)
	_render_tutorial_page()

func _end_tutorial() -> void:
	Game.tutorial_active = false
	tutorial_overlay.visible = false
	Game.set_tutorial_seen(true)

func _skip_tutorial() -> void:
	Game.tutorial_active = false
	tutorial_overlay.visible = false

func _on_repair(_pc_id: int) -> void:
	_show_carried()