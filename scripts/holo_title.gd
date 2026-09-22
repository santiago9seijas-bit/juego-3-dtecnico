class_name HoloTitle
extends Control

# Título del juego en neón ciberpunk: halo magenta, aberración cromática
# animada (copias cian/magenta desfasadas), parpadeo por letra, saltos de
# glitch ocasionales, barrido de luz y una línea de neón con luz viajando
# debajo del texto. Dibuja letra por letra, así que el texto puede ser
# animado con set_text().

@export var text := "TECNICO DE COMPUTADORAS"
@export var font_size := 66

const MAIN := Color("f2ffff")
const DIM_LETTER := 0.35

var _t := 0.0
var _phase := PackedFloat32Array()
var _glitch_idx := -1
var _glitch_left := 0.0
var _glitch_gap := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_recalc()

func set_text(value: String) -> void:
	text = value
	_recalc()
	queue_redraw()

func _recalc() -> void:
	_phase.resize(text.length())
	for i in text.length():
		_phase[i] = float(i) * 0.7
	var f := get_theme_default_font()
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	custom_minimum_size = Vector2(w + 60.0, font_size * 1.8)

func _process(delta: float) -> void:
	_t += delta
	_tick_glitch(delta)
	queue_redraw()

func _tick_glitch(delta: float) -> void:
	if _glitch_left > 0.0:
		_glitch_left -= delta
		if _glitch_left <= 0.0:
			_glitch_idx = -1
		return
	_glitch_gap -= delta
	if _glitch_gap <= 0.0:
		_glitch_gap = 1.4 + randf() * 2.6
		_glitch_idx = randi() % maxi(text.length(), 1)
		_glitch_left = 0.05 + randf() * 0.14

func _draw() -> void:
	if text.is_empty():
		return
	var f := get_theme_default_font()
	var total: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x0 := (size.x - total) * 0.5
	var baseline := size.y * 0.5 + font_size * 0.36
	# Desfase cromático que respira.
	var ab := 1.6 + 1.6 * absf(sin(_t * 2.4))
	var px := x0
	for i in text.length():
		var ch := text[i]
		var adv: float = f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var p := Vector2(px, baseline)
		var phase: float = _phase[i] if i < _phase.size() else float(i) * 0.7
		var alpha := 0.84 + 0.16 * sin(_t * 3.2 + phase)
		# Parpadeo fuerte ocasional por letra.
		if sin(_t * 8.5 + phase * 2.3) > 0.975:
			alpha = DIM_LETTER
		var shift := Vector2.ZERO
		var col := MAIN
		if i == _glitch_idx:
			shift = Vector2(randf_range(-7.0, 7.0), randf_range(-2.5, 2.5))
			col = Color("9dfcff") if randf() > 0.5 else Color("ffd0e6")
		# Halo magenta y halo cian (glow de neón).
		draw_string_outline(f, p + Vector2(0, 1), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 18, Color(UiStyle.MAGENTA, 0.26 * alpha))
		draw_string_outline(f, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 9, Color(UiStyle.CYAN, 0.28 * alpha))
		# Aberración cromática: copias magenta y cian desfasadas.
		draw_string(f, p + shift + Vector2(-ab, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(UiStyle.MAGENTA, 0.72 * alpha))
		draw_string(f, p + shift + Vector2(ab, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(UiStyle.CYAN, 0.72 * alpha))
		# Núcleo del texto.
		draw_string(f, p + shift, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(col, alpha))
		px += adv

	# Línea de neón con luz viajando + remates magenta.
	var uy := baseline + font_size * 0.44
	draw_rect(Rect2(x0, uy, total, 2.0), Color(UiStyle.CYAN, 0.32))
	var head := fmod(_t * 260.0, total + 160.0)
	var hx := x0 + head - 80.0
	var a := maxf(x0, hx - 45.0)
	var b := minf(x0 + total, hx + 45.0)
	if b > a:
		draw_rect(Rect2(a, uy - 1.5, b - a, 5.0), Color(UiStyle.CYAN_SOFT, 0.95))
	draw_rect(Rect2(x0 - 16.0, uy - 4.0, 11.0, 10.0), Color(UiStyle.MAGENTA, 0.85))
	draw_rect(Rect2(x0 + total + 5.0, uy - 4.0, 11.0, 10.0), Color(UiStyle.MAGENTA, 0.85))

	# Barrido de scanline sobre las letras.
	var sy := fmod(_t * 0.7, 1.0) * (size.y - 12.0)
	draw_rect(Rect2(x0, sy, total, 9.0), Color(1, 1, 1, 0.05))
