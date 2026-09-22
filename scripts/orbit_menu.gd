class_name OrbitMenu
extends Container

# Menú orbital: una esfera tipo AGUJERO NEGRO queda a la izquierda y los
# botones se curvan sobre un arco que la rodea, con forma de píldora
# (todo "curvo", como en los menús del juego).

const HOLE_VIOLET := Color("7a2bff")
const HOLE_CYAN := Color("19e6ff")
const HOLE_PINK := Color("ff2e88")

@export var sphere_radius: float = 74.0
@export var side_margin: float = 18.0
@export var gap: float = 14.0
@export var max_span_deg: float = 140.0
@export var min_span_deg: float = 26.0
@export var max_button_width: float = 400.0

var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_hook_children()
	queue_sort()
	update_minimum_size()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_CHILD_ORDER_CHANGED:
			if is_node_ready():
				_hook_children()
				_refresh()
		NOTIFICATION_SORT_CHILDREN:
			_sort_children_now()

# Botones visibles que van en el arco (los ocultos esperan a aparecer).
func _buttons(visible_only: bool) -> Array:
	var out: Array = []
	for child in get_children():
		if child is Button and (not visible_only or (child as Button).visible):
			out.append(child)
	return out

# Añade píldora a los botones y avisa si algún botón cambia de visibilidad.
func _hook_children() -> void:
	for raw in _buttons(false):
		var b: Button = raw
		if not b.visibility_changed.is_connected(_refresh):
			b.visibility_changed.connect(_refresh)
		_style_pill(b)

func _refresh() -> void:
	queue_sort()
	update_minimum_size()

# Los botones del menú quedan con las puntas redondeadas (píldora).
func _style_pill(button: Button) -> void:
	if button.has_meta("orbit_pill"):
		return
	button.set_meta("orbit_pill", true)
	var height := button.get_combined_minimum_size().y
	var radius := maxi(10, int(height * 0.5) - 1)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var base := button.get_theme_stylebox(state, "Button") as StyleBoxFlat
		if base == null:
			continue
		var pill := base.duplicate() as StyleBoxFlat
		pill.set_corner_radius_all(radius)
		button.add_theme_stylebox_override(state, pill)

# Geometría del arco: radio suficiente para no invadir la esfera y
# ángulo total calculado con la longitud de los botones.
func _geom() -> Dictionary:
	var btns := _buttons(true)
	var widths := PackedFloat32Array()
	var heights := PackedFloat32Array()
	var total := 0.0
	var max_w := 0.0
	var max_h := 0.0
	for raw in btns:
		var b: Button = raw
		var content: Vector2 = b.get_combined_minimum_size()
		var w := clampf(content.x, 150.0, max_button_width)
		var h := clampf(content.y, 34.0, 74.0)
		widths.append(w)
		heights.append(h)
		max_w = maxf(max_w, w)
		max_h = maxf(max_h, h)
		total += h + gap
	var cx := side_margin + sphere_radius
	var r := maxf(sphere_radius + max_w * 0.5 + side_margin, sphere_radius * 3.0)
	var span := total / r
	var max_span := deg_to_rad(max_span_deg)
	if span > max_span:
		span = max_span
		r = total / span
	span = maxf(span, deg_to_rad(min_span_deg))
	return {
		"buttons": btns,
		"widths": widths,
		"heights": heights,
		"max_w": max_w,
		"max_h": max_h,
		"cx": cx,
		"r": r,
		"span": span,
	}

func _get_minimum_size() -> Vector2:
	var g := _geom()
	var r: float = g["r"]
	var span: float = g["span"]
	var cx: float = g["cx"]
	var max_w: float = g["max_w"]
	var max_h: float = g["max_h"]
	var width := cx + r + max_w * 0.5
	var height := maxf(r * 2.0 * sin(span * 0.5) + max_h, sphere_radius * 2.0 + 16.0)
	return Vector2(width, height)

func _sort_children_now() -> void:
	var g := _geom()
	var btns: Array = g["buttons"]
	if btns.is_empty():
		return
	var r: float = g["r"]
	var span: float = g["span"]
	var cx: float = g["cx"]
	var widths: PackedFloat32Array = g["widths"]
	var heights: PackedFloat32Array = g["heights"]
	var cy := size.y * 0.5
	var lengths := PackedFloat32Array()
	var total := 0.0
	for i in btns.size():
		var l := heights[i] + gap
		lengths.append(l)
		total += l
	# El primer botón va arriba y el último abajo, con el mismo espacio
	# entre uno y otro a lo largo del arco.
	var acc := 0.0
	for i in btns.size():
		var mid := acc + lengths[i] * 0.5
		var a := span * 0.5 - span * (mid / total)
		var button := btns[i] as Button
		button.custom_minimum_size = Vector2(widths[i], heights[i])
		var pos := Vector2(
			cx + cos(a) * r - widths[i] * 0.5,
			cy - sin(a) * r - heights[i] * 0.5)
		fit_child_in_rect(button, Rect2(pos, Vector2(widths[i], heights[i])))
		acc += lengths[i]

# Pinta el agujero negro (halo, disco girando y horizonte de eventos)
# y la línea de órbita punteada que siguen los botones.
func _draw() -> void:
	var g := _geom()
	var r: float = g["r"]
	var span: float = g["span"]
	var cx: float = g["cx"]
	var cy := size.y * 0.5
	var hole := Vector2(cx, cy)
	var rad := sphere_radius

	# Resplandor exterior del disco.
	for i in 7:
		var f := float(i) / 6.0
		var rr := rad * (3.0 - 1.9 * f)
		draw_circle(hole, rr, Color(HOLE_VIOLET.r, HOLE_VIOLET.g, HOLE_VIOLET.b, 0.03 + 0.045 * f))

	# Disco de acreción: dos elipses inclinadas que giran despacio.
	draw_set_transform(hole, _t * 0.7, Vector2(1.0, 0.36))
	draw_arc(Vector2.ZERO, rad * 1.75, 0.0, TAU, 72, Color(HOLE_CYAN, 0.28), 9.0, true)
	var hot := 0.6 + _t * 0.7
	draw_arc(Vector2.ZERO, rad * 1.75, hot, hot + PI, 40, Color(HOLE_PINK, 0.95), 5.0, true)
	draw_arc(Vector2.ZERO, rad * 1.75, hot + PI, hot + TAU, 40, Color(HOLE_CYAN, 0.75), 4.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Órbita punteada de los botones.
	var seg := span / 14.0
	for i in 14:
		var a0 := -span * 0.5 + seg * float(i)
		draw_arc(hole, r, a0, a0 + seg * 0.5, 6, Color(HOLE_CYAN, 0.20), 2.0, true)

	# Horizonte de eventos: aro brillante y núcleo negro.
	draw_circle(hole, rad + 7.0, Color(HOLE_PINK, 0.32))
	draw_circle(hole, rad + 3.0, Color(HOLE_CYAN, 0.7))
	draw_circle(hole, rad, Color(0.008, 0.008, 0.02))
	# Destello que da la vuelta al borde del agujero.
	var shine := -1.3 + _t * 0.7
	draw_arc(hole, rad * 0.9, shine, shine + 1.1, 20, Color(1.0, 1.0, 1.0, 0.45), 3.0, true)
