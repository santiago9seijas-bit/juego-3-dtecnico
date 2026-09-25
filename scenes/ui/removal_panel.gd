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

class RamBoard:
	extends Control

	signal completed

	const DOT_RADIUS := 15.0
	const START_Y := 0.80
	const TARGET_Y := 0.38
	const REVERSE_START_Y := 0.42
	const REVERSE_TARGET_Y := 0.78
	const LIFT_TOLERANCE := 0.10

	var reverse := false
	var _start_y := START_Y
	var _target_y := TARGET_Y
	var _dot_x := [0.20, 0.80, 0.50]
	var _dot_y := [START_Y, START_Y, START_Y]
	var _dot_visible := [true, true, false]
	var _dot_lifted := [false, false, false]
	var _dragging := -1
	var _drag_offset := 0.0
	var _completed := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(360, 180)
		set_process(true)

	func configure(is_reverse: bool) -> void:
		reverse = is_reverse
		_start_y = REVERSE_START_Y if reverse else START_Y
		_target_y = REVERSE_TARGET_Y if reverse else TARGET_Y
		_dot_y = [_start_y, _start_y, _start_y]
		_dot_visible = [false, false, true] if reverse else [true, true, false]
		_dot_lifted = [false, false, false]
		_completed = false
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _dot_pos(index: int) -> Vector2:
		return Vector2(size.x * float(_dot_x[index]), size.y * float(_dot_y[index]))

	func _target_pos(index: int) -> Vector2:
		return Vector2(size.x * float(_dot_x[index]), size.y * _target_y)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				for i in 3:
					if not bool(_dot_visible[i]) or bool(_dot_lifted[i]):
						continue
					if event.position.distance_to(_dot_pos(i)) <= DOT_RADIUS + 12.0:
						_dragging = i
						_drag_offset = event.position.y - _dot_pos(i).y
						accept_event()
						return
			elif _dragging >= 0:
				var index := _dragging
				_dragging = -1
				_release_dot(index)
				accept_event()
		elif event is InputEventMouseMotion and _dragging >= 0:
			var index := _dragging
			var low := minf(_start_y, _target_y)
			var high := maxf(_start_y, _target_y)
			_dot_y[index] = clampf(
				(event.position.y - _drag_offset) / maxf(size.y, 1.0),
				low,
				high
			)
			queue_redraw()

	func _release_dot(index: int) -> void:
		var at_target := false
		if reverse:
			at_target = float(_dot_y[index]) >= _target_y - LIFT_TOLERANCE
		else:
			at_target = float(_dot_y[index]) <= _target_y + LIFT_TOLERANCE
		if at_target:
			_dot_y[index] = _target_y
			_dot_lifted[index] = true
			if reverse:
				if bool(_dot_lifted[2]):
					_dot_visible[0] = true
					_dot_visible[1] = true
			elif bool(_dot_lifted[0]) and bool(_dot_lifted[1]):
				_dot_visible[2] = true
			if bool(_dot_lifted[0]) and bool(_dot_lifted[1]) and bool(_dot_lifted[2]):
				_completed = true
				completed.emit()
		else:
			_dot_y[index] = _start_y
		queue_redraw()

	# Permite a las pruebas completar una secuencia sin depender de la
	# posición exacta del ratón; el jugador usa el arrastre real.
	func lift_dot_for_test(index: int) -> void:
		if index < 0 or index > 2 or not bool(_dot_visible[index]) or bool(_dot_lifted[index]):
			return
		_dot_y[index] = _target_y
		_release_dot(index)

	func _draw() -> void:
		var font := get_theme_default_font()
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var action := "insertar" if reverse else "extraer"
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.06, 0.10))
		for gx in range(0, int(size.x), 24):
			draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(UiStyle.CYAN, 0.07), 1.0)
		for gy in range(0, int(size.y), 24):
			draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(UiStyle.CYAN, 0.07), 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiStyle.CYAN, 0.55), false, 2.0)
		draw_string(font, Vector2(12, 22), "PUNTOS DE LA RAM · %s" % action,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 15, UiStyle.CYAN)
		var lifted := 0
		for value in _dot_lifted:
			if bool(value):
				lifted += 1
		var status := "1/2 · ARRASTRA LOS PUNTOS LATERALES HACIA ARRIBA"
		if reverse:
			status = "1/1 · ARRASTRA EL PUNTO CENTRAL HACIA ABAJO"
			if lifted >= 1:
				status = "2/2 · APARECEN LOS PUNTOS LATERALES"
		elif lifted >= 2:
			status = "2/2 · APARECE EL PUNTO CENTRAL"
		if lifted >= 3:
			status = "3/3 · RAM LISTA"
		draw_string(font, Vector2(12, 43), status,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 13, UiStyle.TEXT_DIM)
		var labels := ["IZQUIERDA", "DERECHA", "CENTRO"]
		for i in 3:
			if not bool(_dot_visible[i]):
				continue
			var target := _target_pos(i)
			var bottom := Vector2(target.x, size.y * _start_y)
			var current := _dot_pos(i)
			var line_color := Color(UiStyle.CYAN, 0.35) if not bool(_dot_lifted[i]) else Color(0.2, 1.0, 0.55, 0.8)
			draw_line(target, bottom, line_color, 3.0)
			draw_circle(target, DOT_RADIUS + 7.0, Color(line_color, 0.16 + 0.08 * pulse))
			draw_circle(target, DOT_RADIUS, Color(line_color, 0.65), false, 2.0)
			var dot_color := UiStyle.CYAN if i != 2 else UiStyle.AMBER
			if bool(_dot_lifted[i]):
				dot_color = Color(0.25, 1.0, 0.55)
			draw_circle(current, DOT_RADIUS + 8.0, Color(dot_color, 0.2))
			draw_circle(current, DOT_RADIUS, dot_color)
			draw_string(font, Vector2(target.x - 65.0, size.y - 8.0), labels[i],
				HORIZONTAL_ALIGNMENT_CENTER, 130.0, 12, UiStyle.TEXT_DIM)

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
	var _t := 0.0

	func _max_x() -> float:
		return WIDTH - HANDLE_W

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(WIDTH, 96)

	func _ready() -> void:
		_delta_x = _max_x() if reverse else 0.0
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	# Riel neón: pista oscura con retícula, zona objetivo pulsante y
	# manija magenta con halo (ciberpunk).
	func _draw() -> void:
		var font := get_theme_default_font()
		var ty := (size.y - TRACK_H) / 2.0
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var track := Rect2(0, ty, size.x, TRACK_H)
		# Riel oscuro con borde cian y marcas cada 20 px.
		draw_rect(track, Color(0.04, 0.06, 0.1))
		var x := 0.0
		while x <= size.x:
			draw_line(Vector2(x, ty + 5.0), Vector2(x, ty + TRACK_H - 5.0), Color(UiStyle.CYAN, 0.14), 1.0)
			x += 20.0
		draw_rect(track, Color(UiStyle.CYAN, 0.75), false, 2.0)
		# Zona objetivo (verde pulsante).
		var goal_x := 0.0 if reverse else _max_x()
		var goal := Rect2(goal_x, ty, HANDLE_W, TRACK_H)
		draw_rect(goal, Color(0.1, 0.9, 0.5, 0.14 + 0.12 * pulse))
		draw_rect(goal, Color(0.2, 1.0, 0.6, 0.5 + 0.5 * pulse), false, 2.0)
		# Manija con halo magenta.
		var hx := clampf(_delta_x, 0.0, _max_x())
		var handle := Rect2(hx + 3.0, ty + 4.0, HANDLE_W - 6.0, TRACK_H - 8.0)
		draw_rect(Rect2(handle.position - Vector2(4, 4), handle.size + Vector2(8, 8)), Color(UiStyle.MAGENTA, 0.2))
		draw_rect(handle, UiStyle.MAGENTA)
		draw_rect(handle, Color(1, 1, 1, 0.55), false, 2.0)
		if label != "":
			draw_string(font,
				Vector2(handle.position.x, handle.position.y + handle.size.y / 2.0 + 6.0),
				label, HORIZONTAL_ALIGNMENT_CENTER, handle.size.x, 16, Color.WHITE)

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
		var gc := Color(0.1, 0.1, 0.13, 0.95) if not button_pressed else Color(0.7, 0.7, 0.76, 0.95)
		if head_type == "phillips":
			draw_rect(Rect2(cx - glyph / 2.0, -lw / 2.0 + cy, glyph, lw), gc)
			draw_rect(Rect2(cx - lw / 2.0, cy - glyph / 2.0, lw, glyph), gc)
		else:
			draw_rect(Rect2(cx - glyph / 2.0, cy - lw / 2.0, glyph, lw), gc)

# Zona de tornillos: marco neón con retícula y barra de progreso.
class ScrewArea:
	extends Control

	var total := 1
	var done := 0
	var _t := 0.0

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func set_progress(d: int) -> void:
		done = d
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.04, 0.05, 0.09))
		for gx in range(0, int(size.x), 24):
			draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(UiStyle.CYAN, 0.07), 1.0)
		for gy in range(0, int(size.y), 24):
			draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(UiStyle.CYAN, 0.07), 1.0)
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		draw_rect(rect, Color(UiStyle.CYAN, 0.45 + 0.3 * pulse), false, 2.0)
		# Barra de progreso abajo (magenta).
		var bar := Rect2(6.0, size.y - 12.0, size.x - 12.0, 6.0)
		draw_rect(bar, Color(0.1, 0.12, 0.16))
		var f := clampf(float(done) / float(maxi(total, 1)), 0.0, 1.0)
		if f > 0.0:
			draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2.0) * f, bar.size.y - 2.0)), UiStyle.MAGENTA)

# Texto de pista: tiembla si te equivocaste de destornillador.
class HintLabel:
	extends Label

	func _shake() -> void:
		var tween := create_tween()
		var base := position.x
		for i in 6:
			tween.tween_property(self, "position:x", base + (10.0 if i % 2 == 0 else -10.0), 0.04)
		tween.tween_property(self, "position:x", base, 0.05)

@onready var title_label: Label = %RemovalTitle
@onready var content: VBoxContainer = %RemovalContent
@onready var cancel_button: Button = %RemovalCancel

# Cautín: se arrastra el estaño por la pista dañada sin salirse.
class SolderTrack:
	extends Control

	signal completed
	# Se emite al tercer intento fuera de la pista: la soldadura FALLÓ.
	signal failed

	const TOLERANCE := 26.0
	const MAX_MISTAKES := 3

	var _pts := PackedVector2Array()
	var _progress := 0
	var _dragging := false
	var _mouse := Vector2.ZERO
	var _inside := false
	# Posición del punto de estaño: si sales de la pista vuelve al INICIO.
	var _point := Vector2.ZERO
	var _out := false
	var mistakes := 0
	# true = si te salidas 3 veces la pieza se pierde (soldado directo).
	var risky := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(440, 170)

	func _ready() -> void:
		_build_path()
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _build_path() -> void:
		_pts = PackedVector2Array()
		var steps := 64
		for i in steps + 1:
			var t := float(i) / float(steps)
			var x := 50.0 + 340.0 * t
			var y := 85.0 + sin(t * PI * 3.0) * 38.0
			_pts.append(Vector2(x, y))
		_progress = 0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_mouse = event.position
			_inside = true
			if _dragging:
				_follow(event.position)
			queue_redraw()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_mouse = event.position
			if event.pressed:
				if not _pts.is_empty() and event.position.distance_to(_pts[0]) <= TOLERANCE * 1.6:
					_dragging = true
					_out = false
					_point = _pts[0]
			elif _dragging:
				_dragging = false
			queue_redraw()

	func _follow(p: Vector2) -> void:
		var best := -1
		for i in range(_progress + 1, _pts.size()):
			if p.distance_to(_pts[i]) <= TOLERANCE:
				best = i
		if best >= 0:
			_out = false
			_progress = best
			_point = p
			if _progress >= _pts.size() - 1:
				_dragging = false
				completed.emit()
				return
		else:
			# Se salió de los bordes: el punto vuelve a su sitio original
			# (el pad INICIO) y solo cuenta UN fallo por salida.
			_point = _pts[0]
			_progress = 0
			if not _out:
				_out = true
				mistakes += 1
				Game.register_error()
				if mistakes >= MAX_MISTAKES:
					_dragging = false
					failed.emit()
					queue_redraw()
					return
		queue_redraw()

	func _dist_to_path(p: Vector2) -> float:
		var best := INF
		for i in _pts.size():
			best = minf(best, p.distance_to(_pts[i]))
		return best

	# Pista de placa neón: fondo con retícula, cobre brillante, estaño
	# derretido con halo y la punta del cautín echando chispas.
	func _draw() -> void:
		if _pts.is_empty():
			return
		var font := get_theme_default_font()
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		# Fondo de la placa con retícula tenue.
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.03, 0.07, 0.06))
		for gx in range(0, int(size.x), 24):
			draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(UiStyle.CYAN, 0.07), 1.0)
		for gy in range(0, int(size.y), 24):
			draw_line(Vector2(0, gy), Vector2(size.x, gy), Color(UiStyle.CYAN, 0.07), 1.0)
		# Pista: halo cian + canal oscuro + cobre.
		draw_polyline(_pts, Color(UiStyle.CYAN, 0.16 + 0.1 * pulse), 26.0, true)
		draw_polyline(_pts, Color(0.05, 0.06, 0.09), 18.0, true)
		draw_polyline(_pts, Color(0.78, 0.55, 0.24, 0.9), 3.0, true)
		# Soldadura derretida hasta donde ya pasó el cautín.
		if _progress > 0:
			var done_pts := PackedVector2Array()
			for i in _progress + 1:
				done_pts.append(_pts[i])
			draw_polyline(done_pts, Color(UiStyle.CYAN, 0.35), 20.0, true)
			draw_polyline(done_pts, Color(0.8, 0.9, 1.0), 10.0, true)
			draw_polyline(done_pts, Color(1, 1, 1, 0.75), 4.0, true)
		# Pads de inicio (magenta pulsante) y fin (verde pulsante).
		draw_circle(_pts[0], 14.0 + 3.0 * pulse, Color(UiStyle.MAGENTA, 0.35))
		draw_circle(_pts[0], 14.0, Color(0.95, 0.55, 0.2))
		draw_circle(_pts[0], 14.0, Color(1, 1, 1, 0.5), false, 2.0)
		var last: Vector2 = _pts[_pts.size() - 1]
		draw_circle(last, 14.0 + 3.0 * pulse, Color(0.2, 0.9, 0.55, 0.35))
		draw_circle(last, 14.0, Color(0.25, 0.85, 0.55))
		draw_circle(last, 14.0, Color(1, 1, 1, 0.5), false, 2.0)
		draw_string(font, _pts[0] + Vector2(-20, 36), "INICIO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, UiStyle.CYAN)
		draw_string(font, last + Vector2(-14, 36), "FIN", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.4, 1.0, 0.65))
		# Punta del cautín: halo de calor y chispas mientras suelda.
		# El punto de estaño se dibuja en _point (al salirse vuelve al INICIO).
		if _dragging:
			draw_circle(_point, 20.0 + 5.0 * pulse, Color(1, 0.5, 0.15, 0.25))
			draw_circle(_point, 13.0, Color(1, 0.55, 0.2, 0.5))
			draw_circle(_point, 6.0, Color(1, 0.85, 0.5))
			for i in 6:
				var a := _t * 9.0 + float(i) * PI / 3.0
				var off := Vector2(cos(a), sin(a)) * (12.0 + 6.0 * pulse)
				draw_circle(_point + off, 2.0, Color(1.0, 0.85, 0.4, 0.8))
			if _out:
				# Aviso rojo: el punto ya regresó, vuelve a agarrarlo ahí.
				draw_circle(_pts[0], 16.0 + 4.0 * pulse, Color(1.0, 0.25, 0.25, 0.5))
				draw_string(font, _pts[0] + Vector2(-46, -24), "¡VUELVE AL INICIO!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(1.0, 0.4, 0.4))
		elif _inside:
			draw_circle(_mouse, 6.0, Color(0.8, 0.8, 0.85, 0.8))
		# Intentos de salida que quedan antes de arruinar la pieza.
		if risky and (_dragging or mistakes > 0):
			var left := MAX_MISTAKES - mistakes
			draw_string(font, Vector2(10, size.y - 10), "Intentos: %d" % maxi(left, 0), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(1.0, 0.4, 0.4) if left <= 1 else Color(UiStyle.CYAN))

# Voltímetro analógico: la aguja barre la escala y hay que detenerla
# (clic o ESPACIO) dentro de la zona verde del voltaje pedido.
class VoltMeter:
	extends Control

	signal reading_ok
	signal missed

	const MAX_V := 15.0

	var rails: Array = [12.0, 5.0, 3.3]
	var idx := 0
	var tolerance := 1.0
	var speed := 5.5
	var _pos := 0.0
	var _dir := 1.0
	var _flash := ""
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(440, 220)

	func _ready() -> void:
		set_process(true)
		queue_redraw()

	func target() -> float:
		return float(rails[clampi(idx, 0, rails.size() - 1)])

	func readings_total() -> int:
		return rails.size()

	func _process(delta: float) -> void:
		_t += delta
		_pos += _dir * speed * delta
		if _pos >= MAX_V:
			_pos = MAX_V
			_dir = -1.0
		elif _pos <= 0.0:
			_pos = 0.0
			_dir = 1.0
		queue_redraw()

	func measure() -> void:
		if is_queued_for_deletion():
			return
		if absf(_pos - target()) <= tolerance:
			idx += 1
			_flash = "¡Lectura correcta!"
			if idx >= rails.size():
				reading_ok.emit()
			else:
				_dir = -_dir
		else:
			_flash = "¡Fuera de rango! Detén la aguja en la zona verde."
			missed.emit()
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			measure()
			accept_event()

	# Panel neón: escala con zona verde pulsante, aguja magenta con halo,
	# lectura digital grande y barrido de scanline.
	func _draw() -> void:
		var font := get_theme_default_font()
		var x0 := 20.0
		var bw := maxf(size.x - 40.0, 100.0)
		var by := 86.0
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		# Fondo del aparato con retícula.
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.04, 0.05, 0.09))
		for gx in range(0, int(size.x), 24):
			draw_line(Vector2(gx, 0), Vector2(gx, size.y), Color(UiStyle.CYAN, 0.07), 1.0)
		# Rótulos.
		draw_string(font, Vector2(x0, 26.0),
			"Lectura %d/%d — objetivo: %.1f V" % [mini(idx + 1, rails.size()), rails.size(), target()],
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, UiStyle.CYAN)
		draw_string(font, Vector2(x0, 50.0),
			"Clic (o ESPACIO) cuando la aguja entre en la zona verde",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, UiStyle.TEXT_DIM)
		# Lectura digital grande a la derecha.
		draw_string(font, Vector2(size.x - 150.0, 46.0), "%.1f V" % _pos,
			HORIZONTAL_ALIGNMENT_RIGHT, 140.0, 30, UiStyle.MAGENTA)
		# Escala.
		draw_rect(Rect2(x0, by, bw, 38.0), Color(0.06, 0.08, 0.12))
		var t := target()
		var lo := clampf(t - tolerance, 0.0, MAX_V)
		var hi := clampf(t + tolerance, 0.0, MAX_V)
		var lx := x0 + bw * lo / MAX_V
		var hx := x0 + bw * hi / MAX_V
		var zw := maxf(hx - lx, 8.0)
		draw_rect(Rect2(lx, by, zw, 38.0), Color(0.1, 0.9, 0.5, 0.35 + 0.25 * pulse))
		draw_rect(Rect2(lx, by, zw, 38.0), Color(0.3, 1.0, 0.6, 0.7 + 0.3 * pulse), false, 2.0)
		for v in range(0, int(MAX_V) + 1):
			var vx := x0 + bw * float(v) / MAX_V
			var big := v % 5 == 0
			var tick := 12.0 if big else 6.0
			draw_line(Vector2(vx, by + 38.0), Vector2(vx, by + 38.0 + tick), Color(UiStyle.CYAN, 0.85), 2.0 if big else 1.0)
			if big:
				draw_string(font, Vector2(vx - 10.0, by + 68.0), str(v), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 13, UiStyle.TEXT_DIM)
		draw_rect(Rect2(x0, by, bw, 38.0), Color(UiStyle.CYAN, 0.7), false, 2.0)
		# Aguja con halo magenta.
		var nx := x0 + bw * _pos / MAX_V
		draw_line(Vector2(nx, by - 18.0), Vector2(nx, by + 44.0), Color(UiStyle.MAGENTA, 0.3), 9.0, true)
		draw_line(Vector2(nx, by - 18.0), Vector2(nx, by + 44.0), UiStyle.MAGENTA, 3.0, true)
		draw_circle(Vector2(nx, by - 18.0), 9.0, Color(UiStyle.MAGENTA, 0.35))
		draw_circle(Vector2(nx, by - 18.0), 6.0, UiStyle.MAGENTA)
		# Barrido de scanline.
		var sy := fmod(_t * 60.0, size.y)
		draw_line(Vector2(0, sy), Vector2(size.x, sy), Color(1, 1, 1, 0.06), 3.0)
		if _flash != "":
			var good := _flash.begins_with("¡Lectura")
			draw_string(font, Vector2(x0, size.y - 14.0), _flash, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16,
				Color(0.4, 1.0, 0.6) if good else Color(1.0, 0.5, 0.5))


var _reverse := false
var _mode := ""
var _part_type := ""
var _screwdriver := "flat"
var _screw_total := 0
var _screws_removed := 0
var _screw_buttons: Array = []
var _driver_buttons: Dictionary = {}
var _hint_label: Label
var _screw_area: ScrewArea
var _slider_h: Slider
var _slider_v: Slider
var _slide_component: SlideComponent
var _ram_board: RamBoard
var _solder_track: SolderTrack
var _volt_meter: VoltMeter
var _stage_done: Callable = Callable()
var _combo := 0
var _multiplier := 1
var last_multiplier := 1
# Resultado de la última soldadura directa (false = falló 3 veces y la
# pieza quedó insalvable; el minijuego lo consulta al cerrar el panel).
var last_solder_ok := true
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

# Voltajes que se miden con el voltímetro en cada pieza.
const VOLT_RAILS := {
	"psu": [12.0, 5.0, 3.3],
	"mb": [5.0, 3.3],
}

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _mode == "volt":
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
			if _volt_meter:
				_volt_meter.measure()
			get_viewport().set_input_as_handled()
		return
	if _mode != "screws":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_screwdriver("flat")
				get_viewport().set_input_as_handled()
			KEY_2:
				_set_screwdriver("phillips")
				get_viewport().set_input_as_handled()

func open(part_type: String, reverse := false, mode := "") -> void:
	_reverse = reverse
	_part_type = part_type
	last_multiplier = 1
	last_solder_ok = true
	_clear_content()
	var accion := "Instalar" if reverse else "Desarmar"
	title_label.text = "%s - %s" % [accion, Game.part_title(part_type)]
	# Reparar con el cautín: solo la pista de soldadura, sin cambiar nada.
	if mode == "solder":
		title_label.text = "Soldar - %s" % Game.part_title(part_type)
		_build_solder(func() -> void: done.emit(), "", true)
		return
	# Vía segura: PRIMERO se miden los rieles con el voltímetro y DESPUÉS
	# se suelda (si aquí fallas, la pieza no se pierde).
	if mode == "volt_solder":
		title_label.text = "Medir y soldar - %s" % Game.part_title(part_type)
		_build_volt(func() -> void: _build_solder(func() -> void: done.emit(), "ya mediste: este soldado es SEGURO", false), "Paso 1 — mide los rieles con el voltímetro")
		return
	# Niveles con mecánicas nuevas: al INSTALAR placa o fuente primero se
	# suelda, luego va el desarme de siempre y al final el voltímetro.
	if reverse and Game.uses_tech(part_type):
		var total := 4 if part_type == "psu" else 3
		_build_solder(func() -> void: _build_tech_mid(part_type, total), "Paso 1 de %d" % total)
		return
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

func _build_tech_mid(part_type: String, total: int) -> void:
	var volt := func() -> void:
		_build_volt(func() -> void: done.emit(), "Paso %d de %d" % [total, total])
	match part_type:
		"psu":
			_build_psu(volt, "Paso 2 de %d" % total, "Paso 3 de %d" % total)
		_:
			_build_screws(volt, "Paso 2 de %d" % total)

func _build_solder(on_done: Callable, step_text: String, can_fail := false) -> void:
	_clear_content()
	_mode = "solder"
	_stage_done = on_done
	var prefix := (step_text + " — ") if step_text != "" else ""
	var extra := " ¡Te quedan %d salidas antes de arruinar la pieza!" % SolderTrack.MAX_MISTAKES if can_fail else ""
	_make_hint("%sSujeta el cautín en el INICIO y arrastra la soldadura por toda la pista hasta el FIN sin salirte.%s" % [prefix, extra])
	var center := CenterContainer.new()
	content.add_child(center)
	var track := SolderTrack.new()
	track.risky = can_fail
	center.add_child(track)
	_solder_track = track
	track.completed.connect(func() -> void:
		last_solder_ok = true
		_fire_stage())
	if can_fail:
		track.failed.connect(func() -> void:
			last_solder_ok = false
			last_multiplier = 1
			done.emit())

func _build_volt(on_done: Callable, step_text: String) -> void:
	_clear_content()
	_mode = "volt"
	_stage_done = on_done
	var prefix := (step_text + " — ") if step_text != "" else ""
	_make_hint("%sDetén la aguja del voltímetro en la zona verde: haz clic o pulsa ESPACIO." % prefix)
	var center := CenterContainer.new()
	content.add_child(center)
	var meter := VoltMeter.new()
	meter.rails = VOLT_RAILS.get(_part_type, [12.0, 5.0, 3.3])
	center.add_child(meter)
	_volt_meter = meter
	meter.reading_ok.connect(func() -> void: _fire_stage())
	meter.missed.connect(func() -> void: Game.register_error())

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
	_screw_area = null
	_slider_h = null
	_slider_v = null
	_slide_component = null
	_ram_board = null
	_solder_track = null
	_volt_meter = null
	_stage_done = Callable()

func _fire_stage() -> void:
	if _stage_done.is_valid():
		_stage_done.call()
	else:
		done.emit()

func _make_hint(text: String) -> Label:
	var l := HintLabel.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UiStyle.TEXT)
	l.add_theme_color_override("font_outline_color", Color(UiStyle.CYAN.r, UiStyle.CYAN.g, UiStyle.CYAN.b, 0.5))
	l.add_theme_constant_override("font_outline_size", 3)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(l)
	_hint_label = l
	return l

# Sliders neón (RAM y procesador): riel oscuro con borde cian y
# zona agarrada magenta con halo.
func _style_slider(s: Slider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.06, 0.08, 0.12)
	track.border_color = Color(UiStyle.CYAN, 0.7)
	track.set_border_width_all(2)
	track.set_corner_radius_all(5)
	track.shadow_size = 8
	track.shadow_color = Color(UiStyle.CYAN, 0.25)
	var grab := StyleBoxFlat.new()
	grab.bg_color = UiStyle.MAGENTA
	grab.set_corner_radius_all(5)
	grab.shadow_size = 10
	grab.shadow_color = Color(UiStyle.MAGENTA, 0.6)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grab_area", grab)
	s.add_theme_stylebox_override("grab_area_highlight", grab)

func _build_ram() -> void:
	_mode = "ram"
	var nombre := Game.part_title("ram")
	if _reverse:
		_make_hint("%s: primero baja el punto central; después baja los puntos izquierdo y derecho para insertarlo" % nombre)
	else:
		_make_hint("%s: primero sube los dos puntos laterales; después sube el punto central para extraerlo" % nombre)
	var center := CenterContainer.new()
	content.add_child(center)
	var board := RamBoard.new()
	board.configure(_reverse)
	center.add_child(board)
	_ram_board = board
	board.completed.connect(func() -> void: _fire_stage())

func _build_slide_right(part_type: String, on_done: Callable = Callable(), step_text := "") -> void:
	_clear_content()
	_stage_done = on_done
	var nombre: String = Game.part_title(part_type)
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

func _build_psu(on_done: Callable = Callable(), step1 := "Paso 1 de 2", step2 := "Paso 2 de 2") -> void:
	_clear_content()
	var tail := on_done
	if not tail.is_valid():
		tail = func() -> void: done.emit()
	if _reverse:
		_build_slide_right("psu", func() -> void: _build_screws(tail, step2), step1)
	else:
		_build_screws(func() -> void: _build_slide_right("psu", tail, step2), step1)

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
	var area := ScrewArea.new()
	area.custom_minimum_size = Vector2(300, 170)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.total = _screw_total
	area.done = 0 if not _reverse else _screw_total
	content.add_child(area)
	_screw_area = area

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
	normal.bg_color = Color(0.08, 0.1, 0.14)
	normal.set_corner_radius_all(6)
	normal.border_color = Color(UiStyle.CYAN, 0.55)
	normal.set_border_width_all(2)
	normal.shadow_size = 6
	normal.shadow_color = Color(UiStyle.CYAN, 0.22)
	var active := StyleBoxFlat.new()
	active.bg_color = Color(0.14, 0.1, 0.16)
	active.set_corner_radius_all(6)
	active.border_color = accent
	active.set_border_width_all(3)
	active.shadow_size = 12
	active.shadow_color = Color(accent, 0.55)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", active)
	b.add_theme_stylebox_override("pressed", active)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
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
	normal.shadow_size = 8
	normal.shadow_color = Color(color, 0.5)
	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.15)
	hover.set_corner_radius_all(21)
	hover.border_color = color.lightened(0.45)
	hover.set_border_width_all(2)
	hover.shadow_size = 14
	hover.shadow_color = Color(color.lightened(0.3), 0.8)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.1, 0.1, 0.13)
	pressed.set_corner_radius_all(21)
	pressed.border_color = UiStyle.CYAN
	pressed.set_border_width_all(2)
	pressed.shadow_size = 6
	pressed.shadow_color = Color(UiStyle.CYAN, 0.4)
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
		if _screw_area:
			_screw_area.set_progress(colored)
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
		if _screw_area:
			_screw_area.set_progress(_screws_removed)
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
	var nombre := Game.part_title("cpu")
	if _reverse:
		_make_hint("Paso 1: desliza %s hacia la IZQUIERDA para colocarlo" % nombre)
		_slider_h = _make_hslider(100.0)
		_slider_h.value_changed.connect(_on_cpu_h_reverse)
	else:
		_make_hint("Paso 1: desliza %s hacia la DERECHA" % nombre)
		_slider_h = _make_hslider(0.0)
		_slider_h.value_changed.connect(_on_cpu_h)

func _make_hslider(initial: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.value = initial
	s.step = 1.0
	s.custom_minimum_size = Vector2(320, 30)
	_style_slider(s)
	content.add_child(s)
	return s

func _make_vslider(initial: float) -> VSlider:
	var s := VSlider.new()
	s.min_value = 0.0
	s.max_value = 100.0
	s.value = initial
	s.step = 1.0
	s.custom_minimum_size = Vector2(30, 150)
	_style_slider(s)
	var center := CenterContainer.new()
	center.add_child(s)
	content.add_child(center)
	return s

func _unlock_cpu_vertical(initial: float) -> void:
	_slider_h.editable = false
	var nombre := Game.part_title("cpu")
	var direction := "ABAJO" if _reverse else "ARRIBA"
	_make_hint("Paso 2: ahora desliza %s hacia %s" % [nombre, direction])
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
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", UiStyle.TEXT)
	l.add_theme_color_override("font_outline_color", Color(UiStyle.MAGENTA.r, UiStyle.MAGENTA.g, UiStyle.MAGENTA.b, 0.7))
	l.add_theme_constant_override("font_outline_size", 5)
	l.text = "Multiplicador: x%d" % _multiplier
	content.add_child(l)
	_multiplier_label = l

func _update_multiplier_label() -> void:
	if not _multiplier_label:
		return
	_multiplier_label.text = "Multiplicador: x%d%s" % [_multiplier, "  (racha perfecta!)" if _multiplier >= Game.MAX_MULTIPLIER else ""]
	if _multiplier >= Game.MAX_MULTIPLIER:
		_multiplier_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		_multiplier_label.add_theme_color_override("font_outline_color", Color(1, 0.6, 0.1))
	elif _multiplier > 1:
		_multiplier_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.65))
		_multiplier_label.add_theme_color_override("font_outline_color", Color(0.1, 0.9, 0.5, 0.8))
	else:
		_multiplier_label.add_theme_color_override("font_color", UiStyle.TEXT)
		_multiplier_label.add_theme_color_override("font_outline_color", Color(UiStyle.MAGENTA.r, UiStyle.MAGENTA.g, UiStyle.MAGENTA.b, 0.7))

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