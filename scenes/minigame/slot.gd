class_name RepairSlot
extends PanelContainer

signal part_dropped(slot: RepairSlot, data: Dictionary)
signal remove_requested(slot: RepairSlot)
signal examine_requested(slot: RepairSlot)
signal repair_requested(slot: RepairSlot)
# Segunda vía de reparación: medir el voltímetro PRIMERO y luego soldar.
signal measure_first_requested(slot: RepairSlot)

const FAULT_NONE := ""
# Colores de borde más marcados (pulsan en _process con borde grueso).
const VOLT_COLOR := Color(0.82, 0.46, 1.0)
const BURN_COLOR := Color(0.86, 0.86, 0.94)
const SWAP_COLOR := Color(1.0, 0.3, 0.42)

@export var slot_type := "ram"

var part: Dictionary = {}
var revealed := false
# En el servidor el hueco activo está vacío: se muestra como destino de
# instalación, no como una pieza dañada.
var install_target := false
# Tipo de daño (volt / burn / swap) y cómo se arregla (solder / swap).
var fault := "swap"
var fix := "swap"
# true = la soldadura falló 3 veces sin haber medido: ya no se puede rescatar.
var ruined := false

var _t := 0.0
var _style_normal: StyleBoxFlat
var _style_fault: StyleBoxFlat

@onready var title_label: Label = $VBox/TitleLabel
@onready var part_label: Label = $VBox/PartLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var remove_button: Button = $VBox/RemoveButton
@onready var examine_button: Button = $VBox/ExamineButton
@onready var box: VBoxContainer = $VBox

var repair_button: Button
var volt_button: Button

func _ready() -> void:
	remove_button.pressed.connect(func() -> void: remove_requested.emit(self))
	examine_button.pressed.connect(func() -> void: examine_requested.emit(self))
	_style_normal = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	# Botón SOLDAR: aparece solo cuando esa pieza se arregla con el cautín.
	repair_button = Button.new()
	repair_button.name = "RepairButton"
	repair_button.text = "SOLDAR"
	repair_button.add_theme_font_size_override("font_size", 13)
	repair_button.visible = false
	repair_button.pressed.connect(func() -> void: repair_requested.emit(self))
	box.add_child(repair_button)
	# Segunda opción: medir el voltaje ANTES de soldar (el soldado queda seguro).
	volt_button = Button.new()
	volt_button.name = "VoltButton"
	volt_button.text = "VOLTAJE"
	volt_button.tooltip_text = "Mide los rieles con el voltímetro y luego sueldas (si fallas, la pieza no se pierde)."
	volt_button.add_theme_font_size_override("font_size", 13)
	volt_button.visible = false
	volt_button.pressed.connect(func() -> void: measure_first_requested.emit(self))
	box.add_child(volt_button)
	# Se colocan ENCIMA de Examinar/Sacar: así esos dos botones quedan a la
	# misma altura en todos los slots (los huecos libres ocupan el resto).
	var examine_idx := box.get_children().find(examine_button)
	if examine_idx >= 0:
		box.move_child(volt_button, examine_idx)
		box.move_child(repair_button, examine_idx)
	set_process(true)

func set_fault(new_fault: String, new_fix: String) -> void:
	fault = new_fault if new_fault != "" else "swap"
	fix = new_fix if new_fix != "" else "swap"
	# Cada PC nueva vuelve a ofrecer el rescate con el cautín.
	ruined = false
	_refresh()

# El brillo del fallo se ve recién cuando el slot está examinado.
func _glow_active() -> bool:
	return revealed and has_broken_part()

func _process(delta: float) -> void:
	if not _glow_active():
		return
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 3.2)
	var sb := _style_fault
	if sb == null:
		return
	sb.set_border_width_all(4)
	if fault == "volt":
		# Sobretensión: halo morado que respira, borde grueso y contundente.
		sb.border_color = Color(VOLT_COLOR.r, VOLT_COLOR.g, VOLT_COLOR.b, 0.7 + 0.3 * pulse)
		sb.shadow_color = Color(VOLT_COLOR.r, VOLT_COLOR.g, VOLT_COLOR.b, 0.6 + 0.35 * pulse)
		sb.shadow_size = int(round(8.0 + 12.0 * pulse))
	elif fault == "burn":
		# Quemada: zona negra (ceniza) con borde claro que late encima.
		sb.border_color = Color(BURN_COLOR.r, BURN_COLOR.g, BURN_COLOR.b, 0.6 + 0.4 * pulse)
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.9)
		sb.shadow_size = int(round(10.0 + 12.0 * pulse))
	else:
		# Daño normal: rojo neón que también pulsa.
		sb.border_color = Color(SWAP_COLOR.r, SWAP_COLOR.g, SWAP_COLOR.b, 0.7 + 0.3 * pulse)
		sb.shadow_color = Color(SWAP_COLOR.r, SWAP_COLOR.g, SWAP_COLOR.b, 0.35 + 0.3 * pulse)
		sb.shadow_size = int(round(4.0 + 8.0 * pulse))

func set_part(new_part: Dictionary) -> void:
	if not new_part.is_empty():
		install_target = false
	if new_part.is_empty():
		part = {}
		_refresh()
		return
	part = {
		"name": new_part.get("name", ""),
		"type": new_part.get("type", slot_type),
		"good": new_part.get("good", true),
	}
	_refresh()

func clear_part() -> void:
	part = {}
	_refresh()

func set_revealed(new_value: bool) -> void:
	revealed = new_value
	_refresh()

func set_install_target(on: bool) -> void:
	install_target = on
	_refresh()

func is_empty() -> bool:
	return part.is_empty()

func has_broken_part() -> bool:
	return not part.is_empty() and not part.get("good", true)

# Esta pieza se arregla soldando en vez de cambiarla (salvo si quedó
# insalvable tras fallar la soldadura sin haber medido el voltaje).
func can_solder() -> bool:
	return fix == "solder" and revealed and has_broken_part() and not ruined

func fault_label() -> String:
	if fault == "volt":
		return "SOBRETENSIÓN"
	if fault == "burn":
		return "QUEMADA"
	return ""

func _apply_style() -> void:
	var base := _style_normal
	if base == null:
		return
	if _glow_active():
		if _style_fault == null:
			_style_fault = base.duplicate() as StyleBoxFlat
		if fault == "volt":
			_style_fault.bg_color = Color(0.15, 0.09, 0.24)
		elif fault == "burn":
			_style_fault.bg_color = Color(0.02, 0.02, 0.03)
		else:
			_style_fault.bg_color = Color(0.2, 0.08, 0.11)
		# Borde grueso para que el color del daño se note de un vistazo.
		_style_fault.set_border_width_all(4)
		_style_fault.border_color = SWAP_COLOR
		add_theme_stylebox_override("panel", _style_fault)
	else:
		add_theme_stylebox_override("panel", base)

func _refresh() -> void:
	_apply_style()
	if repair_button:
		repair_button.visible = can_solder()
	if volt_button:
		volt_button.visible = can_solder()
	if part.is_empty():
		part_label.text = "- -"
		part_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		status_label.text = "INSTALAR AQUÍ" if install_target else "espacio libre"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.8, 0.9) if install_target else Color(1, 1, 1, 0.5))
		remove_button.visible = false
		examine_button.visible = false
	else:
		remove_button.visible = true
		examine_button.visible = true
		if not revealed:
			part_label.text = "?"
			part_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
			status_label.text = "?"
			status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		else:
			part_label.text = str(part.name)
			part_label.add_theme_color_override("font_color", Color.WHITE)
			if part.get("good", true):
				status_label.text = "OK"
				status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
			elif ruined:
				# Falló soldando sin medir: ya no hay rescate con el cautín.
				status_label.text = "DAÑADA\nINSALVABLE"
				status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			else:
				var fl := fault_label()
				status_label.text = "DAÑADA" if fl == "" else "DAÑADA\n%s" % fl
				match fault:
					"volt":
						status_label.add_theme_color_override("font_color", VOLT_COLOR)
					"burn":
						status_label.add_theme_color_override("font_color", Color(0.86, 0.86, 0.94))
					_:
						status_label.add_theme_color_override("font_color", SWAP_COLOR)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	part_dropped.emit(self, data)
