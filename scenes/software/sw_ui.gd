class_name SwUI
extends RefCounted

# Utilidades de UI compartidas por TODOS los minijuegos del mundo de
# software. Se construyen por código y siguen el look de UiStyle.
#
# El patrón de instrucciones es SIEMPRE el mismo y es el importante:
# el número va SOLO en su línea y la explicación queda JUSTO DEBAJO
# (nunca "1. texto 2. texto" en la misma línea).

static func label(text: String, size := 16, color := UiStyle.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func rich(text: String, size := 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("font_size", size)
	r.text = text
	return r

static func vbox(sep := 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", sep)
	return box

static func hbox(sep := 12) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", sep)
	return box

# Pasos 1, 2, 3… uno debajo del otro: número en su propia línea y la
# explicación sangrada en la línea siguiente.
# items: [{"n": 1, "text": "…"}, …]  (si no lleva "n" se numera solo)
static func steps(items: Array) -> VBoxContainer:
	var box := vbox(2)
	for i in items.size():
		var it: Dictionary = items[i] if items[i] is Dictionary else {"text": str(items[i])}
		var num := label(str(it.get("n", i + 1)), 21, UiStyle.CYAN)
		num.add_theme_color_override("font_color", UiStyle.CYAN_SOFT)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(num)

		var body := label(str(it.get("text", "")), 15, UiStyle.TEXT_DIM)
		body.add_theme_constant_override("line_spacing", 2)
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", 30)
		indent.add_child(body)
		box.add_child(indent)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		box.add_child(spacer)
	return box

# Título de sección en mayúsculas con una línea de color debajo
# (p. ej. "DRIVERS · NVIDIA", "SISTEMA OPERATIVO").
static func section_header(text: String, color := UiStyle.CYAN) -> VBoxContainer:
	var box := vbox(3)
	var title := label(text.to_upper(), 15, color)
	title.add_theme_color_override("font_color", color)
	box.add_child(title)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color(color, 0.55)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	return box

# Pastilla de estado: "SOLICITADO", "FALTA", "INSTALADO ✓"…
static func pill(text: String, color := UiStyle.CYAN) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.14)
	style.set_border_width_all(1)
	style.border_color = color
	style.set_corner_radius_all(9)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	panel.add_theme_stylebox_override("panel", style)
	# SIN autowrap: el mínimo de un Label con autowrap es de 1px de ancho,
	# y en una fila el HBox le daría exactamente 1px → la pastilla se
	# convertiría en una columna de texto de 300px de alto.
	var inner := label(text, 13, color)
	inner.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(inner)
	return panel

static func button(text: String, min_size := Vector2(170, 40), font := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	UiStyle.animate(b)
	return b

# Panel con borde de color (se usa para recuadros de aviso y diálogos).
static func card(color := UiStyle.CYAN, bg := Color("0a0f16")) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(2)
	style.border_color = color
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func bar(color: Color, height := 16.0) -> ProgressBar:
	var b := ProgressBar.new()
	# 80px mínimos: si la barra cae en una fila sin hueco para expandirse,
	# se vería como una línea de 1px y no se leería.
	b.custom_minimum_size = Vector2(80, height)
	b.max_value = 100.0
	b.value = 0.0
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0a1018")
	bg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	fill.shadow_size = 6
	fill.shadow_color = Color(color, 0.55)
	b.add_theme_stylebox_override("fill", fill)
	return b

# Fila "etiqueta | barra | 100%" para barras de progreso con rótulo.
static func bar_row(title: String, color: Color) -> Dictionary:
	var row := hbox(12)
	var name_label := label(title, 15, UiStyle.TEXT_DIM)
	name_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_label)
	var progress := bar(color)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(progress)
	var text := label("0%", 15, UiStyle.TEXT_DIM)
	text.custom_minimum_size = Vector2(80, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(text)
	return {"row": row, "bar": progress, "text": text}

static func set_bar(entry: Dictionary, ratio: float, color: Color) -> void:
	var value := clampf(ratio, 0.0, 1.0) * 100.0
	(entry.bar as ProgressBar).value = value
	var t := entry.text as Label
	t.text = "%d%%" % int(value)
	t.add_theme_color_override("font_color", color)

# Espaciador vertical.
static func gap(size := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# Convierte cualquier cosa en un Array de String (listas de tareas).
static func str_array(value) -> Array:
	var out: Array = []
	if value is Array:
		for v in value:
			out.append(str(v))
	return out
