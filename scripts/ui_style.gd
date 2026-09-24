class_name UiStyle
extends RefCounted

# Look de los menús: ciberpunk / técnico. Fondo con retícula, paneles
# oscuros con neón cian, botones con resplandor magenta al pasar el mouse
# y animaciones de entrada y de presión.

const BG := Color("05070d")
const CARD := Color("0a0f16")
const BTN := Color("0c1420")
const BTN_HOVER := Color("141f33")
const BTN_PRESS := Color("05090f")
const CYAN := Color("19e6ff")
const CYAN_SOFT := Color("7ef9ff")
const MAGENTA := Color("ff2e88")
const TEXT := Color("d7f4ff")
const TEXT_DIM := Color("6f8ba0")
const AMBER := Color("ffb020")
const RED := Color("ff5a5a")
const GRID_SHADER := "res://shaders/menu_grid.gdshader"

static var _theme: Theme = null

static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 18

	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_color("default_color", "RichTextLabel", TEXT)

	# Botones: contorno cian; al pasar el mouse, resplandor magenta.
	_theme.set_stylebox("normal", "Button", _box(BTN, CYAN, 6, Color(CYAN, 0.16)))
	_theme.set_stylebox("hover", "Button", _box(BTN_HOVER, MAGENTA, 14, Color(MAGENTA, 0.5)))
	_theme.set_stylebox("pressed", "Button", _box(BTN_PRESS, CYAN_SOFT, 4, Color(CYAN, 0.3)))
	_theme.set_stylebox("focus", "Button", _box(BTN_HOVER, MAGENTA, 10, Color(MAGENTA, 0.4)))
	_theme.set_stylebox("disabled", "Button", _box(Color("080b10"), Color("16202c"), 0, Color(0, 0, 0, 0)))
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_pressed_color", "Button", CYAN_SOFT)
	_theme.set_color("font_focus_color", "Button", Color.WHITE)
	_theme.set_color("font_disabled_color", "Button", TEXT_DIM)

	var card := _box(CARD, CYAN, 4, Color(CYAN, 0.14))
	card.content_margin_left = 22.0
	card.content_margin_right = 22.0
	card.content_margin_top = 18.0
	card.content_margin_bottom = 18.0
	_theme.set_stylebox("panel", "Panel", card)
	_theme.set_stylebox("panel", "PanelContainer", card)
	return _theme

# Fuente neón/tipo graffiti (inclinada y gruesa) para los marcadores
# del HUD: tiempo, puntaje y errores.
static func neon_font(skew: float = 0.26, embolden: float = 0.24) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	variation.variation_transform = Transform2D(0.0, Vector2.ONE, skew, Vector2.ZERO)
	variation.variation_embolden = embolden
	return variation

static func _box(bg: Color, border: Color, glow: int, glow_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.shadow_size = glow
	sb.shadow_color = glow_color
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 9.0
	sb.content_margin_bottom = 9.0
	return sb

# Aplica el tema a un árbol, envuelve cada pantalla en una tarjeta con
# borde de neón y deja listas las animaciones de sus botones.
static func apply(root: Control) -> void:
	if root == null:
		return
	root.theme = theme()
	_background(root)
	_wrap_surfaces(root)
	var buttons: Array = []
	var titles: Array = []
	_collect(root, buttons, titles)
	for b in buttons:
		animate(b as Button)
	for t in titles:
		accent(t as Label)

# Titulares en cian con resplandor (halo).
static func accent(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", CYAN)
	label.add_theme_color_override("font_outline_color", Color(CYAN.r, CYAN.g, CYAN.b, 0.35))
	label.add_theme_constant_override("font_outline_size", 6)

# Título de pantalla (TutorialScreen, etc.): neón con halo cian y contorno
# magenta, más grande que un acento común y con parpadeo suave.
static func neon_title(label: Label) -> void:
	if label == null or label.has_meta("ui_neon"):
		return
	label.set_meta("ui_neon", true)
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color("f2ffff"))
	label.add_theme_color_override("font_outline_color", MAGENTA)
	label.add_theme_constant_override("font_outline_size", 12)
	label.add_theme_color_override("font_shadow_color", Color(CYAN, 0.85))
	label.add_theme_constant_override("shadow_outline_size", 10)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	var tween := label.create_tween()
	tween.set_loops()
	tween.tween_interval(2.2)
	tween.tween_property(label, "modulate:a", 0.82, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

static func _collect(node: Node, buttons: Array, titles: Array) -> void:
	for child in node.get_children():
		if child is Button:
			buttons.append(child)
		elif child is Label and String(child.name).contains("Title"):
			titles.append(child)
		_collect(child, buttons, titles)

static func _collect_buttons(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button:
			out.append(child)
		_collect_buttons(child, out)

# Retícula de fondo: la pantalla se ve como un panel técnico.
static func _background(root: Control) -> void:
	var bg := root.get_node_or_null("Bg")
	if bg is ColorRect:
		var shader: Shader = load(GRID_SHADER)
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			(bg as ColorRect).material = mat

static func _wrap_surfaces(root: Control) -> void:
	var containers: Array = []
	_collect_wrappable(root, containers)
	for container in containers:
		# Tarjeta con marco animado (luz recorriendo el borde).
		var card := HoloCard.new()
		card.name = "Surface"
		container.add_child(card)
		reparent(container.get_child(0), card)

static func _collect_wrappable(node: Node, out: Array) -> void:
	for child in node.get_children():
		if (child is CenterContainer or child is MarginContainer) \
			and child.get_child_count() == 1 \
			and child.get_child(0) is VBoxContainer \
			and not (child.get_parent() is PanelContainer):
			out.append(child)
		_collect_wrappable(child, out)

# Mover un nodo borra su owner y con él los %nodos únicos: se guarda y
# se restaura para que las referencias sigan funcionando.
static func reparent(node: Node, parent: Node) -> void:
	if node == null or parent == null or node.get_parent() == parent:
		return
	var own: Node = node.owner
	var owners := {}
	_collect_owners(node, owners)
	node.get_parent().remove_child(node)
	parent.add_child(node)
	if own != null:
		node.owner = own
	for n in owners:
		if is_instance_valid(n):
			n.owner = owners[n]

static func _collect_owners(node: Node, out: Dictionary) -> void:
	for child in node.get_children():
		if child.owner != null:
			out[child] = child.owner
		_collect_owners(child, out)

# Animación al presionar: el botón se encoge y vuelve con rebote.
static func animate(button: Button) -> void:
	if button == null or button.has_meta("ui_anim"):
		return
	button.set_meta("ui_anim", true)
	button.pressed.connect(_on_pressed.bind(button))

static func _on_pressed(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.pivot_offset = button.size / 2.0
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2(0.94, 0.94), 0.05)
	tween.tween_property(button, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Entrada suave de las pantallas.
static func fade_in(control: Control) -> void:
	if control == null:
		return
	_restart(control, "ui_fade")
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	control.set_meta("ui_fade", tween)

# Los botones entran desde la izquierda, uno tras otro.
static func enter_screen(screen: Control) -> void:
	if screen == null:
		return
	_restart(screen, "ui_slide")
	var base_x := screen.position.x
	screen.position.x = base_x - 190.0
	var slide := screen.create_tween()
	slide.tween_property(screen, "position:x", base_x, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	screen.set_meta("ui_slide", slide)

	var buttons: Array = []
	_collect_buttons(screen, buttons)
	var i := 0
	for b in buttons:
		var button: Button = b
		_restart(button, "ui_btnfade")
		button.modulate.a = 0.0
		var tween := button.create_tween()
		tween.tween_interval(0.05 * i)
		tween.tween_property(button, "modulate:a", 1.0, 0.22) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		button.set_meta("ui_btnfade", tween)
		i += 1

static func _restart(node: Object, key: String) -> void:
	if node.has_meta(key):
		var prev: Tween = node.get_meta(key)
		if prev and prev.is_valid():
			prev.kill()
