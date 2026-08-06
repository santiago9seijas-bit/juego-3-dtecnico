extends PanelContainer

signal done
signal cancel

const SCREW_COLORS := [
	Color(0.9, 0.3, 0.3),
	Color(0.3, 0.65, 0.95),
	Color(0.35, 0.85, 0.5),
	Color(0.95, 0.75, 0.25),
	Color(0.75, 0.45, 0.95),
	Color(0.3, 0.9, 0.9),
]
const DRIVER_NAMES := {"flat": "LLANA", "phillips": "CRUZ"}
const DRIVER_KEYS := {"flat": "1", "phillips": "2"}

class SlideComponent:
	extends Control

	signal completed

	const WIDTH := 400.0
	const HANDLE_W := 120.0
	const TRACK_H := 64.0

	var reverse := false
	var label := ""
	var _delta_x := 0.0
	var _dragging := false
	var _drag_origin := Vector2.ZERO
	var _drag_start_x := 0.0

	func _max_x() -> float:
		return WIDTH - HANDLE_W

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(WIDTH, 90)

	func _ready() -> void:
		_delta_x = _max_x() if reverse else 0.0

	func _draw() -> void:
		var ty := (size.y - TRACK_H) / 2.0
		draw_rect(Rect2(0, ty, size.x, TRACK_H), Color(0.14, 0.14, 0.17))
		draw_rect(Rect2(_max_x(), ty, HANDLE_W, TRACK_H), Color(0.2, 0.45, 0.28))
		var hx := clampf(_delta_x, 0.0, _max_x())
		draw_rect(Rect2(hx, ty, HANDLE_W, TRACK_H), Color(0.85, 0.62, 0.2))
		draw_rect(Rect2(hx, ty, HANDLE_W, TRACK_H), Color(0, 0, 0, 0.2), false, 2.0)
		if label != "":
			draw_string(get_theme_default_font(), Vector2(hx + 6, ty + TRACK_H / 2 + 6), label, HORIZONTAL_ALIGNMENT_CENTER, HANDLE_W - 12, 16, Color.WHITE)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local: Vector2 = event.position
				var ty := (size.y - TRACK_H) / 2.0
				var hx := clampf(_delta_x, 0.0, _max_x())
				if Rect2(hx, ty, HANDLE_W, TRACK_H).has_point(local):
					_dragging = true
					_drag_origin = local
					_drag_start_x = _delta_x
			elif _dragging:
				_dragging = false
				_on_release()
		elif event is InputEventMouseMotion and _dragging:
			var local: Vector2 = event.position
			_delta_x = clampf(_drag_start_x + (local.x - _drag_origin.x), 0.0, _max_x())
			queue_redraw()

	func _on_drag(rel: Vector2) -> void:
		if is_queued_for_deletion():
			return
		_delta_x = clampf(_delta_x + rel.x, 0.0, _max_x())
		queue_redraw()

	func _on_release() -> void:
		if is_queued_for_deletion():
			return
		queue_redraw()
		if _delta_x >= _max_x() - 2.0 and not reverse:
			completed.emit()
		elif _delta_x <= 2.0 and reverse:
			completed.emit()

class ScrewButton:
	extends Button

	var head_type := "flat"

	func _draw() -> void:
		var cx := size.x / 2.0
		var cy := size.y / 2.0
		var glyph := 13.0
		var lw := 4.5
		var gc := Color(0.1, 0.1, 0.13, 0.95) if not button_pressed else Color(0.55, 0.55, 0.6, 0.9)
		if head_type == "phillips":
			draw_rect(Rect2(cx - glyph / 2.0, cy - lw / 2.0, glyph, lw), gc)
			draw_rect(Rect2(cx - lw / 2.0, cy - glyph / 2.0, lw, glyph), gc)
		else:
			draw_rect(Rect2(cx - glyph / 2.0, cy - lw / 2.0, glyph, lw), gc)

@onready var title_label: Label = %RemovalTitle
@onready var content: VBoxContainer = %RemovalContent
@onready var cancel_button: Button = %RemovalCancel

var _reverse := false
var _mode := ""
var _screwdriver := "flat"
var _screw_total := 0
var _screws_removed := 0
var _screw_buttons: Array = []
var _driver_buttons: Dictionary = {}
var _hint_label: Label
var _slider_h: Slider
var _slider_v: Slider
var _slide_component: SlideComponent
var _stage_done: Callable = Callable()
var _combo := 0
var _multiplier := 1
var last_multiplier := 1
var _multiplier_label: Label
var _particles: CPUParticles2D

func _ready() -> void:
	cancel_button.pressed.connect(func() -> void:
		_reset_cursor()
		cancel.emit())
	_particles = CPUParticles2D.new()
	_particles.name = "ScrewParticles"
	_particles.one_shot = true
	_particles.emitting = false
	_particles.amount = 14
	_particles.lifetime = 0.45
	_particles.direction = Vector2(0, -1)
	_particles.spread = 180.0
	_particles.gravity = Vector2(0, 400)
	_particles.scale_amount_min = 2
	_particles.scale_amount_max = 4
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 4.0
	add_child(_particles)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _mode != "screws":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_screwdriver("flat")
				get_viewport().set_input_as_handled()
			KEY_2:
				_set_screwdriver("phillips")
				get_viewport().set_input_as_handled()

func open(part_type: String, reverse := false) -> void:
	_reverse = reverse
	last_multiplier = 1
	_clear_content()
	var accion := "Instalar" if reverse else "Desarmar"
	title_label.text = "%s - %s" % [accion, Game.PART_TITLES.get(part_type, part_type)]
	match part_type:
		"ram":
			_build_ram()
		"cpu":
			_build_cpu()
		"hdd":
			_build_slide_right("hdd")
		"psu":
			_build_psu()
		_:
			_build_screws()

func _clear_content() -> void:
	for child in content.get_children():
		child.queue_free()
	_reset_cursor()
	_mode = ""
	_screwdriver = "flat"
	_screw_total = 0
	_screws_removed = 0
	_screw_buttons.clear()
	_driver_buttons.clear()
	_hint_label = null
	_multiplier_label = null
	_slider_h = null
	_slider_v = null
	_slide_component = null
	_stage_done = Callable()

func _fire_stage() -> void:
	if _stage_done.is_valid():
		_stage_done.call()
	else:
		done.emit()

func _make_hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	content.add_child(l)
	_hint_label = l
	return l

func _build_ram() -> void:
	if _reverse:
		_make_hint("Arrastra el soporte hacia la IZQUIERDA para insertar la RAM")
	else:
		_make_hint("Arrastra el soporte hacia la DERECHA para extraer la RAM")
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.value = 100.0 if _reverse else 0.0
	s.step = 1.0
	s.custom_minimum_size = Vector2(300, 26)
	content.add_child(s)
	s.value_changed.connect(func(_v: float) -> void:
		if (_reverse and s.value <= 0.0) or (not _reverse and s.value >= 100.0):
			done.emit())

func _build_slide_right(part_type: String, on_done: Callable = Callable(), step_text := "") -> void:
	_clear_content()
	_stage_done = on_done
	var nombre: String = Game.PART_TITLES.get(part_type, part_type)
	var prefix := (step_text + " — ") if step_text != "" else ""
	if _reverse:
		_make_hint("%sDesliza %s hacia la IZQUIERDA para instalarlo" % [prefix, nombre])
	else:
		_make_hint("%sDesliza %s hacia la DERECHA y suéltalo cuando encaje" % [prefix, nombre])
	var center := CenterContainer.new()
	content.add_child(center)
	var sc := SlideComponent.new()
	sc.reverse = _reverse
	sc.label = nombre
	center.add_child(sc)
	sc.completed.connect(func() -> void: _fire_stage())
	_slide_component = sc

func _build_psu() -> void:
	_clear_content()
	if _reverse:
		_build_slide_right("psu", func() -> void: _build_screws(func() -> void: done.emit(), "Paso 2 de 2"), "Paso 1 de 2")
	else:
		_build_screws(func() -> void: _build_slide_right("psu", func() -> void: done.emit(), "Paso 2 de 2"), "Paso 1 de 2")

func _build_screws(on_done: Callable = Callable(), step_text := "") -> void:
	_clear_content()
	_mode = "screws"
	_stage_done = on_done
	_combo = 0
	_multiplier = 1
	var count_range: Vector2i = Game.screw_count_range()
	_screw_total = randi_range(count_range.x, count_range.y)
	var accion := "ATORNILLAR" if _reverse else "desatornillar"
	var prefix := (step_text + " — ") if step_text != "" else ""
	_make_hint("%sToca los %d tornillos para %s. Usa las teclas 1 y 2 para elegir destornillador." % [prefix, _screw_total, accion])
	_make_multiplier_label()
	_build_screwdriver_selector()
	var area := Control.new()
	area.custom_minimum_size = Vector2(300, 160)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(area)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var palette: Array = SCREW_COLORS.duplicate()
	palette.shuffle()
	var cols := ceili(sqrt(float(_screw_total)))
	var rows := ceili(float(_screw_total) / float(cols))
	var cell_w := area.custom_minimum_size.x / float(cols)
	var cell_h := area.custom_minimum_size.y / float(rows)
	var cells: Array = []
	for r in rows:
		for c in cols:
			cells.append(Vector2(c, r))
	cells.shuffle()

	var phi_prob: float = Game.phillips_probability()
	var types: Array = []
	var has_flat := false
	for i in _screw_total:
		var t := "phillips" if rng.randf() < phi_prob else "flat"
		if t == "flat":
			has_flat = true
		types.append(t)
	if not has_flat:
		types[randi() % _screw_total] = "flat"
	types.shuffle()

	for i in _screw_total:
		var color: Color = palette[i % palette.size()]
		var b := _make_screw_button(color)
		b.head_type = types[i]
		if _reverse:
			b.button_pressed = true
		_screw_buttons.append(b)
		var cell: Vector2 = cells[i]
		var pos := Vector2(
			cell.x * cell_w + rng.randf_range(-10, 10),
			cell.y * cell_h + rng.randf_range(-10, 10)
		)
		b.position = pos
		area.add_child(b)
	_update_cursor()
	_update_multiplier_label()

func _build_screwdriver_selector() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	var flat_btn := _make_driver_button("1  LLANA  —", Color(0.95, 0.85, 0.4))
	var phi_btn := _make_driver_button("2  CRUZ  +", Color(0.5, 0.75, 0.98))
	flat_btn.button_group = group
	phi_btn.button_group = group
	flat_btn.pressed.connect(_set_screwdriver.bind("flat"))
	phi_btn.pressed.connect(_set_screwdriver.bind("phillips"))
	row.add_child(flat_btn)
	row.add_child(phi_btn)
	_driver_buttons["flat"] = flat_btn
	_driver_buttons["phillips"] = phi_btn
	flat_btn.button_pressed = true

func _make_driver_button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(130, 34)
	b.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.16, 0.19)
	normal.set_corner_radius_all(6)
	normal.border_color = Color(0.4, 0.4, 0.45)
	normal.set_border_width_all(2)
	var active := StyleBoxFlat.new()
	active.bg_color = Color(0.22, 0.22, 0.26)
	active.set_corner_radius_all(6)
	active.border_color = accent
	active.border_width_bottom = 4
	active.border_width_top = 4
	active.border_width_left = 4
	active.border_width_right = 4
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", active)
	b.add_theme_color_override("font_pressed_color", accent)
	return b

func _set_screwdriver(head_type: String) -> void:
	_screwdriver = head_type
	if _driver_buttons.has(head_type):
		_driver_buttons[head_type].button_pressed = true
	if _mode == "screws":
		_update_cursor()

func _make_screw_button(color: Color) -> ScrewButton:
	var b := ScrewButton.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(42, 42)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(21)
	normal.border_color = color.lightened(0.35)
	normal.set_border_width_all(2)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.15)
	hover.set_corner_radius_all(21)
	hover.border_color = color.lightened(0.45)
	hover.set_border_width_all(2)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.25, 0.25, 0.28)
	pressed.set_corner_radius_all(21)
	pressed.border_color = Color(0.45, 0.45, 0.5)
	pressed.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.toggled.connect(_on_screw.bind(b))
	b.toggled.connect(func(_p: bool) -> void: b.queue_redraw())
	return b

func _on_screw(pressed: bool, button: ScrewButton) -> void:
	if _reverse:
		if pressed:
			return
		if button.head_type != _screwdriver:
			button.set_pressed_no_signal(true)
			_wrong_driver_hint(button.head_type)
			return
		_combo += 1
		_multiplier = clampi(_combo, 1, Game.MAX_MULTIPLIER)
		_update_multiplier_label()
		_spawn_screw_fx(button)
		var colored := 0
		for b in _screw_buttons:
			if not b.button_pressed:
				colored += 1
		if _hint_label:
			_hint_label.text = "Tornillos atornillados: %d / %d" % [colored, _screw_total]
		last_multiplier = _multiplier
		if colored >= _screw_total:
			_fire_stage()
	else:
		if not pressed:
			return
		if button.head_type != _screwdriver:
			button.set_pressed_no_signal(false)
			_wrong_driver_hint(button.head_type)
			return
		_combo += 1
		_multiplier = clampi(_combo, 1, Game.MAX_MULTIPLIER)
		_update_multiplier_label()
		_spawn_screw_fx(button)
		_screws_removed += 1
		if _hint_label:
			_hint_label.text = "Tornillos desatornillados: %d / %d" % [_screws_removed, _screw_total]
		last_multiplier = _multiplier
		if _screws_removed >= _screw_total:
			_fire_stage()

func _wrong_driver_hint(head_type: String) -> void:
	_combo = 0
	_multiplier = 1
	_update_multiplier_label()
	_break_driver_hint()
	if _hint_label:
		_hint_label.text = "¡Destornillador equivocado! Usa %s (tecla %s) para este tornillo." % [
			DRIVER_NAMES.get(head_type, head_type),
			DRIVER_KEYS.get(head_type, "?"),
		]

func _build_cpu() -> void:
	if _reverse:
		_make_hint("Paso 1: desliza el procesador hacia la IZQUIERDA para colocarlo")
		_slider_h = _make_hslider(100.0)
		_slider_h.value_changed.connect(_on_cpu_h_reverse)
	else:
		_make_hint("Paso 1: desliza el procesador hacia la DERECHA")
		_slider_h = _make_hslider(0.0)
		_slider_h.value_changed.connect(_on_cpu_h)

func _make_hslider(initial: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.value = initial
	s.step = 1.0
	s.custom_minimum_size = Vector2(300, 26)
	content.add_child(s)
	return s

func _make_vslider(initial: float) -> VSlider:
	var s := VSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.value = initial
	s.step = 1.0
	s.custom_minimum_size = Vector2(26, 150)
	var center := CenterContainer.new()
	center.add_child(s)
	content.add_child(center)
	return s

func _unlock_cpu_vertical(initial: float) -> void:
	_slider_h.editable = false
	_make_hint("Paso 2: ahora desliza el procesador hacia ABAJO" if _reverse else "Paso 2: ahora desliza el procesador hacia ARRIBA")
	_slider_v = _make_vslider(initial)
	_slider_v.value_changed.connect(_on_cpu_v)

func _on_cpu_h(v: float) -> void:
	if v >= 100.0:
		_unlock_cpu_vertical(0.0)

func _on_cpu_h_reverse(v: float) -> void:
	if v <= 0.0:
		_unlock_cpu_vertical(100.0)

func _on_cpu_v(v: float) -> void:
	if (_reverse and v <= 0.0) or (not _reverse and v >= 100.0):
		done.emit()

func _make_multiplier_label() -> void:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.text = "Multiplicador: x%d" % _multiplier
	content.add_child(l)
	_multiplier_label = l

func _update_multiplier_label() -> void:
	if not _multiplier_label:
		return
	_multiplier_label.text = "Multiplicador: x%d%s" % [_multiplier, "  (racha perfecta!)" if _multiplier >= Game.MAX_MULTIPLIER else ""]
	if _multiplier >= Game.MAX_MULTIPLIER:
		_multiplier_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	elif _multiplier > 1:
		_multiplier_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
	else:
		_multiplier_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

func _spawn_screw_fx(button: ScrewButton) -> void:
	if _particles:
		_particles.global_position = button.global_position
		_particles.restart()
	if Game.hud:
		Game.hud.play_sfx("screw")

func _break_driver_hint() -> void:
	if _hint_label and _hint_label.has_method("_shake"):
		_hint_label.call("_shake")

func _make_cursor_texture(flat: bool) -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(16, 16)
	for y in size:
		for x in size:
			var d: float = Vector2(x, y).distance_to(c)
			if d <= 13.0 and d >= 9.0:
				img.set_pixel(x, y, Color(0.92, 0.92, 0.96))
	var glyph := Color(0.05, 0.05, 0.08)
	if flat:
		for x in range(6, 27):
			for y in range(14, 18):
				img.set_pixel(x, y, glyph)
	else:
		for x in range(14, 18):
			for y in range(5, 27):
				img.set_pixel(x, y, glyph)
		for x in range(5, 27):
			for y in range(14, 18):
				img.set_pixel(x, y, glyph)
	return ImageTexture.create_from_image(img)

func _update_cursor() -> void:
	Input.set_custom_mouse_cursor(_make_cursor_texture(_screwdriver == "flat"), Input.CURSOR_ARROW, Vector2(16, 16))

func _reset_cursor() -> void:
	Input.set_custom_mouse_cursor(null)