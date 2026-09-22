class_name HoloCard
extends PanelContainer

# Marco animado estilo holograma para las tarjetas de los menús:
# una luz viaja por el borde, las líneas de barrido (scanlines) recorren
# el fondo y las esquinas brillan con pulso.

var _t := 0.0
var _path := PackedVector2Array()
var _path_len := 0.0
var _path_w := 0.0
var _path_h := 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	_update_path()
	if _path.is_empty() or _path_len <= 0.0:
		return
	var cyan := UiStyle.CYAN
	# Scanlines tenues sobre toda la tarjeta.
	var scan := Color(cyan.r, cyan.g, cyan.b, 0.035)
	var y := 2.0
	while y < size.y - 2.0:
		draw_line(Vector2(2.0, y), Vector2(size.x - 2.0, y), scan, 1.0)
		y += 4.0
	# Dos luces opuestas recorriendo el marco.
	var head := fmod(_t * 170.0, _path_len)
	_draw_beam(head, 120.0)
	_draw_beam(fmod(head + _path_len * 0.5, _path_len), 120.0)
	# Corchete de esquina con pulso.
	var a := 0.4 + 0.3 * sin(_t * 2.4)
	_draw_brackets(Color(cyan.r, cyan.g, cyan.b, a))

func _update_path() -> void:
	if _path_w == size.x and _path_h == size.y and not _path.is_empty():
		return
	_path = PackedVector2Array()
	_path_w = size.x
	_path_h = size.y
	var w := maxf(size.x - 4.0, 1.0)
	var h := maxf(size.y - 4.0, 1.0)
	_path_len = 2.0 * (w + h)
	var steps := clampi(int(_path_len / 6.0), 48, 700)
	for i in steps:
		_path.append(_point_at(float(i) / float(steps) * _path_len, w, h))

# Punto del perímetro (horario desde arriba a la izquierda).
func _point_at(d: float, w: float, h: float) -> Vector2:
	if d < w:
		return Vector2(2.0 + d, 2.0)
	d -= w
	if d < h:
		return Vector2(2.0 + w, 2.0 + d)
	d -= h
	if d < w:
		return Vector2(2.0 + w - d, 2.0 + h)
	d -= w
	return Vector2(2.0, 2.0 + h - d)

func _beam_points(from: float, length: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := clampi(int(length / 6.0), 8, 80)
	var w := maxf(size.x - 4.0, 1.0)
	var h := maxf(size.y - 4.0, 1.0)
	for i in steps + 1:
		var d := fmod(from + length * float(i) / float(steps), _path_len)
		pts.append(_point_at(d, w, h))
	return pts

func _draw_beam(from: float, length: float) -> void:
	var pts := _beam_points(from, length)
	var cyan := UiStyle.CYAN
	draw_polyline(pts, Color(cyan.r, cyan.g, cyan.b, 0.22), 8.0, true)
	draw_polyline(pts, Color(UiStyle.CYAN_SOFT.r, UiStyle.CYAN_SOFT.g, UiStyle.CYAN_SOFT.b, 0.95), 2.0, true)

func _draw_brackets(c: Color) -> void:
	var L := 20.0
	var m := 4.0
	var w := size.x - m
	var h := size.y - m
	var lw := 3.0
	# Arriba izquierda.
	draw_line(Vector2(m, m), Vector2(m + L, m), c, lw)
	draw_line(Vector2(m, m), Vector2(m, m + L), c, lw)
	# Arriba derecha.
	draw_line(Vector2(w - L, m), Vector2(w, m), c, lw)
	draw_line(Vector2(w, m), Vector2(w, m + L), c, lw)
	# Abajo derecha.
	draw_line(Vector2(w, h - L), Vector2(w, h), c, lw)
	draw_line(Vector2(w - L, h), Vector2(w, h), c, lw)
	# Abajo izquierda.
	draw_line(Vector2(m, h - L), Vector2(m, h), c, lw)
	draw_line(Vector2(m, h), Vector2(m + L, h), c, lw)
