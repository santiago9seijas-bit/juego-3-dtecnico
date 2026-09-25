class_name UsbPiece
extends PanelContainer

# Ficha y hueco de la pestaña PENDRIVE de la ventana de software.
#   kind = "item"  → ficha del contenido del pendrive (se ARRASTRA)
#   kind = "slot"  → hueco que pide la PC (se le SUELTA encima)
#
# El arrastre va con el ratón (Godot: _get_drag_data / _drop_data). La
# página de la pestaña se reconstruye entera cuando algo cambia, así que
# esta ficha es de "usar y tirar": no guarda lógica de negocio.

signal dropped(slot_id: String, item_id: String)

const DRAG_KEY := "usb_item"

var kind := "item"
var piece_id := ""
var title := ""
var sub := ""
var filled_id := ""
var accept: Array = []
var accent: Color = UiStyle.CYAN
# Fichas que esta PC no pide: se ven, pero no se pueden arrastrar.
var draggable := true

var _title_label: Label
var _sub_label: Label

# Fábrica: item = lo que se arrastra, slot = hueco (filled_id = ya relleno).
static func make(kind_: String, id: String, title_: String, sub_: String,
		accent_: Color, accept_: Array = [], filled := "", draggable_ := true) -> UsbPiece:
	var piece := UsbPiece.new()
	piece.kind = kind_
	piece.piece_id = id
	piece.title = title_
	piece.sub = sub_
	piece.accent = accent_
	piece.accept = accept_
	piece.filled_id = filled
	piece.draggable = draggable_
	piece._build()
	return piece

func _build() -> void:
	name = "Usb_%s_%s" % [kind, piece_id]
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Cajitas PEQUEÑAS: la página entera tiene que caber sin scrolls largos.
	custom_minimum_size = Vector2(0, 46 if kind == "slot" else 40)

	# Un PanelContainer mete a TODOS sus hijos en el mismo rectángulo, así
	# que título y detalle van cada uno en su Label dentro de un VBox:
	# si no, los dos textos se imprimen uno encima del otro.
	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	add_child(box)

	_title_label = Label.new()
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title_label)

	_sub_label = Label.new()
	_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_label.add_theme_font_size_override("font_size", 11)
	_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_sub_label)

	_paint()

func _paint() -> void:
	var color := accent
	var bg := Color(accent.r, accent.g, accent.b, 0.12)
	if kind == "item":
		# Sin emojis: la fuente del juego no los trae y salen cuadros.
		_title_label.text = "▸  %s" % title
		_sub_label.text = sub
		_title_label.add_theme_color_override("font_color", UiStyle.TEXT)
		_sub_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		if filled_id != "":
			# Ya está colocado en su hueco: la ficha se queda apagada.
			color = Color(0.3, 1.0, 0.5)
			bg = Color(0.3, 1.0, 0.5, 0.10)
			_title_label.text = "✓  %s" % title
			_sub_label.text = "colocado en su hueco"
			_title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			modulate = Color(1, 1, 1, 0.6)
	else:
		if filled_id != "":
			color = Color(0.3, 1.0, 0.5)
			bg = Color(0.3, 1.0, 0.5, 0.12)
			_title_label.text = "✓  %s" % title
			_sub_label.text = "colocado · %s" % sub
			_title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			_sub_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
		else:
			_title_label.text = "⟵  %s" % title
			_sub_label.text = sub
			_title_label.add_theme_color_override("font_color", accent)
			_sub_label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	# Ficha que esta PC no pide: se ve atenuada y no se arrastra.
	if kind == "item" and not draggable and filled_id == "":
		modulate = Color(1, 1, 1, 0.62)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(2)
	style.border_color = color
	style.set_corner_radius_all(6)
	style.set_corner_detail(3)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)

# ------------------------------------------------------------------
# Arrastre
# ------------------------------------------------------------------
func _get_drag_data(_at: Vector2) -> Variant:
	if kind != "item" or filled_id != "" or not draggable:
		return null
	var preview := Label.new()
	preview.text = "  %s  " % _title_label.text
	preview.add_theme_font_size_override("font_size", 14)
	preview.add_theme_color_override("font_color", accent)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color("0a0f16")
	pstyle.set_border_width_all(2)
	pstyle.border_color = accent
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = 10.0
	pstyle.content_margin_right = 10.0
	pstyle.content_margin_top = 5.0
	pstyle.content_margin_bottom = 5.0
	preview.add_theme_stylebox_override("normal", pstyle)
	set_drag_preview(preview)
	return {DRAG_KEY: piece_id}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if kind != "slot" or not (data is Dictionary):
		return false
	if not (data as Dictionary).has(DRAG_KEY):
		return false
	if accept.is_empty():
		return true
	return str((data as Dictionary)[DRAG_KEY]) in accept

func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(slot_id(), str((data as Dictionary)[DRAG_KEY]))

func slot_id() -> String:
	return piece_id
