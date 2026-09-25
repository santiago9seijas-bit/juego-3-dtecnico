class_name LiquidCoolingMinigame
extends PanelContainer

# Minijuego de refrigeración líquida por tablero:
#   1) se coloca el kit y aparece el mapa térmico;
#   2) se arrastran tuberías rectas, en L, en cruz y piezas especiales
#      que tienen la forma/tamaño de CPU, RAM, ROM, GPU, PSU o MB; las
#      rectas también pueden cubrir directamente los bloques calientes;
#   3) se conectan las piezas desde IN hasta OUT;
#   4) se pulsa el botón que «arroja» el líquido y se arrastra al inicio;
#   5) el ducto se llena hasta 100% y se activa la bomba.
#
# La misma mecánica se usa en la última pieza del servidor y en el
# tutorial de reparación. Las piezas se colocan libremente en la retícula;
# el tablero valida que cada una quede unida a IN, OUT o a otra tubería.

signal completed(data: Dictionary)
signal kit_placed

const CYAN := Color(0.2, 0.9, 1.0)
const GREEN := Color(0.25, 1.0, 0.55)
const AMBER := Color(1.0, 0.7, 0.15)
const RED := Color(1.0, 0.35, 0.38)
const PIPE_BLUE := Color(0.22, 0.68, 0.86)
const GRID_COLOR := Color(0.08, 0.24, 0.32, 0.75)

var expected_name := ""
var _part: Dictionary = {}
var _inserted := false
var _liquid_thrown := false
var _liquid_added := false
var _network_solved := false
var _completed := false
var _pump_step := 0

# Campos conservados para que las pruebas y el flujo antiguo puedan seguir
# consultando el número de puntos y el estado de la bomba.
var _connector_step := 0
var _connectors: Array[Button] = []
var _route: PipePuzzleBoard = null
var _board: PipePuzzleBoard = null

var _target_label: Label
var _status: Label
var _pipe_tray_label: Label
var _piece_tray: GridContainer
var _piece_cards: Array[PipePieceCard] = []
var _token_row: HBoxContainer
var _liquid_token: LiquidToken
var _pour_button: Button
var _remove_button: Button
var _progress: ProgressBar
var _pump_button: Button

const PIECE_DEFS := [
	{"type": "straight", "label": "━ RECTA", "count": 40, "color": Color(0.35, 0.8, 1.0)},
	{"type": "elbow", "label": "┗ EN L", "count": 10, "color": Color(1.0, 0.7, 0.2)},
	{"type": "cross", "label": "╋ CRUZ", "count": 3, "color": Color(0.8, 0.45, 1.0)},
	{"type": "cpu", "label": "▣ CPU 2×2", "count": 2, "color": Color(1.0, 0.35, 0.38)},
	{"type": "ram", "label": "▤ RAM 3×1", "count": 2, "color": Color(0.35, 1.0, 0.6)},
	{"type": "rom", "label": "▥ ROM 2×1", "count": 2, "color": Color(1.0, 0.55, 0.25)},
	{"type": "psu", "label": "▤ PSU 1×2", "count": 2, "color": Color(0.45, 0.9, 1.0)},
	{"type": "mb", "label": "▥ MB 2×1", "count": 2, "color": Color(0.75, 0.55, 1.0)},
	{"type": "gpu", "label": "◆ GPU 1×1", "count": 3, "color": Color(0.55, 0.65, 1.0)},
]

class PipePieceCard:
	extends PanelContainer
	var piece_type := ""
	var piece_label := ""
	var remaining := 0
	var piece_rotation := 0
	var _label: Label
	var _rotate_button: Button

	func setup(new_type: String, new_label: String, count: int, accent: Color) -> void:
		piece_type = new_type
		piece_label = new_label
		piece_rotation = 0
		custom_minimum_size = Vector2(132, 48)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		tooltip_text = "Arrastra la pieza · ↻, clic derecho o rueda para rotar"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.08, 0.12, 0.98)
		style.border_color = Color(accent.r, accent.g, accent.b, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(7)
		add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		add_child(row)
		_label = Label.new()
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 11)
		_label.add_theme_color_override("font_color", accent)
		row.add_child(_label)
		_rotate_button = Button.new()
		_rotate_button.text = "GIRAR"
		_rotate_button.custom_minimum_size = Vector2(43, 30)
		_rotate_button.add_theme_font_size_override("font_size", 10)
		_rotate_button.tooltip_text = "Girar 90° · también clic derecho, rueda o R"
		_rotate_button.pressed.connect(rotate)
		row.add_child(_rotate_button)
		set_remaining(count)

	func _update_label() -> void:
		if _label:
			_label.text = "%s\n×%d" % [piece_label, remaining]

	func rotate() -> void:
		piece_rotation = (piece_rotation + 1) % 4
		_update_label()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
				grab_focus()
			elif mouse.button_index == MOUSE_BUTTON_RIGHT and mouse.pressed:
				rotate()
				accept_event()
			elif mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
				rotate()
				accept_event()
			elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
				rotate()
				accept_event()
		elif event is InputEventKey:
			var key := event as InputEventKey
			if key.pressed and not key.echo and key.keycode == KEY_R:
				rotate()
				accept_event()

	func set_remaining(value: int) -> void:
		remaining = maxi(0, value)
		_update_label()
		if remaining <= 0:
			modulate = Color(1, 1, 1, 0.32)
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _rotate_button:
				_rotate_button.disabled = true
		else:
			modulate = Color.WHITE
			mouse_filter = Control.MOUSE_FILTER_STOP
			if _rotate_button:
				_rotate_button.disabled = false

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if remaining <= 0:
			return null
		var preview := Label.new()
		preview.text = piece_label
		preview.add_theme_color_override("font_color", Color.WHITE)
		set_drag_preview(preview)
		return {"pipe_piece": true, "type": piece_type, "rotation": piece_rotation}

class LiquidToken:
	extends PanelContainer
	func _ready() -> void:
		custom_minimum_size = Vector2(170, 38)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.22, 0.38, 0.98)
		style.border_color = Color(0.2, 0.75, 1.0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(18)
		add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = "💧 ARRASTRA EL LÍQUIDO"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
		add_child(label)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview := Label.new()
		preview.text = "💧 LÍQUIDO"
		preview.add_theme_color_override("font_color", Color.WHITE)
		set_drag_preview(preview)
		return {"liquid_token": true}

class PipePuzzleBoard:
	extends Control
	signal changed
	signal rejected(message: String)
	signal solved
	signal liquid_started
	signal fill_changed(value: float)
	signal fill_complete

	const COLS := 10
	const ROWS := 4
	const RIGHT := 1
	const DOWN := 2
	const LEFT := 4
	const UP := 8
	const START_CELL := Vector2i(0, 0)
	const OUTPUT_CELL := Vector2i(0, 3)

	var active := false
	var components: Array[Dictionary] = []
	var targets: Array[Dictionary] = []
	var piece_counts: Dictionary = {}
	var connected_points := 0
	var fill_ratio := 0.0
	var flowing := false
	var _liquid_placed := false
	var _filling := false
	var _network_solved := false
	var _time := 0.0
	var _cell_size := 25.0
	var _origin := Vector2.ZERO
	var _occupancy: Dictionary = {}
	var _overlays: Array[Dictionary] = []
	var _free_placements: Array[Dictionary] = []
	var _placement_history: Array[Dictionary] = []
	var free_mode := true
	var _liquid_path: Array[Vector2i] = []

	func _ready() -> void:
		custom_minimum_size = Vector2(850, 220)
		mouse_filter = Control.MOUSE_FILTER_STOP
		configure()

	func _process(delta: float) -> void:
		_time += delta
		if flowing or _liquid_placed:
			queue_redraw()
		if _filling:
			fill_ratio = minf(1.0, fill_ratio + delta / 2.4)
			fill_changed.emit(fill_ratio)
			queue_redraw()
			if fill_ratio >= 1.0:
				_filling = false
				fill_complete.emit()

	func configure() -> void:
		components = [
			{"id": "cpu", "label": "CPU", "rect": Rect2i(2, 0, 2, 2)},
			{"id": "ram", "label": "RAM", "rect": Rect2i(2, 2, 3, 1)},
			{"id": "rom", "label": "ROM", "rect": Rect2i(6, 1, 2, 1)},
			{"id": "gpu", "label": "GPU", "rect": Rect2i(4, 1, 1, 1)},
			{"id": "psu", "label": "PSU", "rect": Rect2i(0, 1, 1, 2)},
			{"id": "mb", "label": "MB", "rect": Rect2i(7, 3, 2, 1)},
		]
		targets.clear()
		_occupancy.clear()
		_overlays.clear()
		_free_placements.clear()
		_placement_history.clear()
		_liquid_path = _make_liquid_path()
		connected_points = 0
		fill_ratio = 0.0
		flowing = false
		_liquid_placed = false
		_filling = false
		_network_solved = false
		_add_row_zero_targets()
		_add_row_one_targets()
		_add_row_two_targets()
		_add_row_three_targets()
		queue_redraw()

	func reset() -> void:
		active = false
		configure()
		piece_counts.clear()
		changed.emit()

	func set_piece_counts(counts: Dictionary) -> void:
		piece_counts = counts.duplicate()
		for key: Variant in piece_counts:
			piece_counts[key] = int(piece_counts[key])

	func set_active(value: bool) -> void:
		active = value
		queue_redraw()

	# Compatibilidad con la primera versión del minijuego: el tablero nuevo
	# expone el mismo progreso y el mismo estado de flujo.
	func set_progress(value: int) -> void:
		connected_points = value
		queue_redraw()

	func set_liquid(value: bool) -> void:
		_liquid_placed = value
		queue_redraw()

	func set_flowing(value: bool) -> void:
		flowing = value
		queue_redraw()

	func placed_count() -> int:
		if free_mode:
			return _placement_history.size()
		var count := 0
		for target: Dictionary in targets:
			if _target_complete(target):
				count += 1
		return count

	func _target_complete(target: Dictionary) -> bool:
		if bool(target.get("placed", false)):
			return true
		if str(target.get("type", "")) not in ["cpu", "ram", "rom", "gpu", "psu", "mb"]:
			return false
		for raw: Variant in target.get("cells", []):
			var cell: Vector2i = raw
			if not _occupancy.has(_key(cell)):
				return false
		return true

	func _target_has_occupied_cell(target: Dictionary) -> bool:
		for raw: Variant in target.get("cells", []):
			if _occupancy.has(_key(raw)):
				return true
		return false

	func _find_cover_target(cell: Vector2i) -> Dictionary:
		for target: Dictionary in targets:
			if bool(target.get("placed", false)):
				continue
			if str(target.get("type", "")) in ["cpu", "ram", "rom", "gpu", "psu", "mb"] and target.get("cells", []).has(cell):
				if not _occupancy.has(_key(cell)):
					return target
		return {}

	func target_count() -> int:
		return targets.size()

	func covered_component_count() -> int:
		var count := 0
		for component: Dictionary in components:
			if _component_covered(component):
				count += 1
		return count

	func network_is_solved() -> bool:
		return _network_solved

	func is_filled() -> bool:
		return _liquid_placed and fill_ratio >= 1.0

	func remaining_for(piece_type: String) -> int:
		return int(piece_counts.get(piece_type, 0))

	func _add_target(type: String, anchor: Vector2i, rotation: int, raw_cells: Array) -> void:
		var cells: Array[Vector2i] = []
		for raw: Variant in raw_cells:
			cells.append(raw)
		targets.append({
			"type": type,
			"anchor": anchor,
			"rotation": rotation,
			"cells": cells,
			"placed": false,
		})

	func _add_row_zero_targets() -> void:
		_add_target("straight", Vector2i(1, 0), 0, [Vector2i(1, 0)])
		_add_target("cpu", Vector2i(2, 0), 0, [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)])
		for x in range(4, 9):
			_add_target("straight", Vector2i(x, 0), 0, [Vector2i(x, 0)])
		_add_target("elbow", Vector2i(9, 0), 0, [Vector2i(9, 0)])

	func _add_row_one_targets() -> void:
		_add_target("psu", Vector2i(0, 1), 0, [Vector2i(0, 1), Vector2i(0, 2)])
		_add_target("straight", Vector2i(1, 1), 0, [Vector2i(1, 1)])
		_add_target("straight", Vector2i(5, 1), 0, [Vector2i(5, 1)])
		_add_target("rom", Vector2i(6, 1), 0, [Vector2i(6, 1), Vector2i(7, 1)])
		_add_target("gpu", Vector2i(4, 1), 0, [Vector2i(4, 1)])
		_add_target("straight", Vector2i(8, 1), 0, [Vector2i(8, 1)])
		_add_target("elbow", Vector2i(9, 1), 3, [Vector2i(9, 1)])

	func _add_row_two_targets() -> void:
		_add_target("straight", Vector2i(1, 2), 0, [Vector2i(1, 2)])
		_add_target("ram", Vector2i(2, 2), 0, [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)])
		for x in range(5, 8):
			_add_target("straight", Vector2i(x, 2), 0, [Vector2i(x, 2)])
		_add_target("cross", Vector2i(8, 2), 0, [Vector2i(8, 2)])
		_add_target("elbow", Vector2i(9, 2), 0, [Vector2i(9, 2)])

	func _add_row_three_targets() -> void:
		for x in range(1, 7):
			_add_target("straight", Vector2i(x, 3), 0, [Vector2i(x, 3)])
		_add_target("mb", Vector2i(7, 3), 0, [Vector2i(7, 3), Vector2i(8, 3)])
		_add_target("elbow", Vector2i(9, 3), 3, [Vector2i(9, 3)])

	func _make_liquid_path() -> Array[Vector2i]:
		var path: Array[Vector2i] = []
		for x in range(0, COLS):
			path.append(Vector2i(x, 0))
		for x in range(COLS - 1, -1, -1):
			path.append(Vector2i(x, 1))
		for x in range(0, COLS):
			path.append(Vector2i(x, 2))
		for x in range(COLS - 1, -1, -1):
			path.append(Vector2i(x, 3))
		return path

	func _key(cell: Vector2i) -> String:
		return "%d:%d" % [cell.x, cell.y]

	func _cell_from_position(local_position: Vector2) -> Vector2i:
		var cell_x := int(floor((local_position.x - _origin.x) / _cell_size))
		var cell_y := int(floor((local_position.y - _origin.y) / _cell_size))
		return Vector2i(cell_x, cell_y)

	func _in_bounds(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS

	func _find_target(type: String, cell: Vector2i) -> Dictionary:
		for target: Dictionary in targets:
			if bool(target.get("placed", false)) or str(target.get("type", "")) != type:
				continue
			if target.get("anchor", Vector2i(-99, -99)) == cell:
				return target
			if type in ["cpu", "ram", "rom", "gpu", "psu", "mb"] and target.get("cells", []).has(cell):
				return target
		return {}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		_update_geometry()
		if not active or not (data is Dictionary):
			return false
		var payload: Dictionary = data
		if bool(payload.get("pipe_piece", false)):
			var piece_type := str(payload.get("type", ""))
			var cell := _cell_from_position(_at_position)
			return int(piece_counts.get(piece_type, 0)) > 0 and _in_bounds(cell)
		if bool(payload.get("liquid_token", false)):
			return _network_solved and not _liquid_placed and _cell_from_position(_at_position) == START_CELL
		return false

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if not (data is Dictionary):
			return
		var payload: Dictionary = data
		if bool(payload.get("pipe_piece", false)):
			_place_from_payload(payload, at_position)
		elif bool(payload.get("liquid_token", false)):
			if not _can_drop_data(at_position, payload):
				rejected.emit("El líquido solo se coloca en IN, el inicio del ducto.")
				return
			_liquid_placed = true
			_filling = true
			liquid_started.emit()
			queue_redraw()

	func _placement_has_connection(placement: Dictionary) -> bool:
		var directions := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
		for raw: Variant in placement.get("cells", []):
			var cell: Vector2i = raw
			var mask := _port_mask(placement, cell)
			for direction: Vector2i in directions:
				var bit := _direction_bit(cell, cell + direction)
				if bit == 0 or (mask & bit) == 0:
					continue
				var neighbor := cell + direction
				if neighbor == START_CELL or neighbor == OUTPUT_CELL:
					return true
				if _occupancy.has(_key(neighbor)) and _piece_has_port(neighbor, cell):
					return true
		return false

	func _new_overlay(cell: Vector2i, requested_rotation := -1) -> Dictionary:
		var rotation := requested_rotation if requested_rotation >= 0 else _rotation_for_path_cell(cell)
		return {
			"type": "straight",
			"anchor": cell,
			"rotation": rotation,
			"cells": [cell],
			"placed": true,
			"overlay": true,
		}

	func _cells_for_type(type: String, anchor: Vector2i, rotation: int) -> Array[Vector2i]:
		var cells: Array[Vector2i] = []
		var turns := posmod(rotation, 4)
		match type:
			"cpu":
				for y in 2:
					for x in 2:
						cells.append(anchor + Vector2i(x, y))
			"ram":
				for i in 3:
					cells.append(anchor + (Vector2i(i, 0) if turns % 2 == 0 else Vector2i(0, i)))
			"rom", "mb":
				for i in 2:
					cells.append(anchor + (Vector2i(i, 0) if turns % 2 == 0 else Vector2i(0, i)))
			"psu":
				for i in 2:
					cells.append(anchor + (Vector2i(0, i) if turns % 2 == 0 else Vector2i(i, 0)))
			_:
				cells.append(anchor)
		return cells

	func _snap_special_anchor(type: String, cell: Vector2i) -> Vector2i:
		for component: Dictionary in components:
			if str(component.get("id", "")) != type:
				continue
			var rect: Rect2i = component.get("rect", Rect2i())
			if cell.x >= rect.position.x and cell.x < rect.position.x + rect.size.x and cell.y >= rect.position.y and cell.y < rect.position.y + rect.size.y:
				return rect.position
		return cell

	func _place_from_payload(payload: Dictionary, at_position: Vector2) -> void:
		var piece_type := str(payload.get("type", ""))
		var requested_rotation := int(payload.get("rotation", 0))
		var cell := _snap_special_anchor(piece_type, _cell_from_position(at_position))
		var remaining := int(piece_counts.get(piece_type, 0))
		if remaining <= 0:
			rejected.emit("Ya no te quedan piezas de ese tipo.")
			return
		var cells := _cells_for_type(piece_type, cell, requested_rotation)
		for raw: Variant in cells:
			var occupied: Vector2i = raw
			if not _in_bounds(occupied) or _occupancy.has(_key(occupied)) or occupied == START_CELL or occupied == OUTPUT_CELL:
				rejected.emit("No cabe esa pieza ahí: el espacio está ocupado o se sale del cuadro.")
				return
		var placement := {
			"type": piece_type,
			"anchor": cell,
			"rotation": requested_rotation,
			"placed_rotation": requested_rotation,
			"cells": cells,
			"placed": true,
			"free": true,
		}
		if not _placement_has_connection(placement):
			if piece_type in ["cpu", "ram", "rom", "gpu", "psu", "mb"]:
				rejected.emit("No pongas %s todavía: primero conecta una recta, L o cruz a uno de sus lados." % piece_type.to_upper())
			else:
				rejected.emit("Conecta primero una tubería vecina: esta pieza todavía no toca IN, OUT ni otra pieza.")
			return
		_place_free_piece(placement)
		piece_counts[piece_type] = remaining - 1
		_evaluate()
		changed.emit()
		queue_redraw()

	func _rotation_fits_target(target: Dictionary, requested_rotation: int) -> bool:
		var type := str(target.get("type", ""))
		if type in ["straight", "elbow", "cross", "cpu", "gpu"]:
			return true
		var original: Array = target.get("cells", [])
		var anchor: Vector2i = target.get("anchor", Vector2i.ZERO)
		var rotated := _rotate_cells(anchor, original, requested_rotation - int(target.get("rotation", 0)))
		var original_keys := {}
		for raw: Variant in original:
			var original_cell: Vector2i = raw
			original_keys[_key(original_cell)] = true
		var rotated_keys := {}
		for raw: Variant in rotated:
			var rotated_cell: Vector2i = raw
			rotated_keys[_key(rotated_cell)] = true
		if original_keys.size() != rotated_keys.size():
			return false
		for key: Variant in original_keys:
			if not rotated_keys.has(key):
				return false
		return true

	func _rotate_cells(anchor: Vector2i, cells: Array, steps: int) -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		var turns := posmod(steps, 4)
		for raw: Variant in cells:
			var cell: Vector2i = raw
			var relative := cell - anchor
			for _turn in range(turns):
				relative = Vector2i(-relative.y, relative.x)
			result.append(anchor + relative)
		return result

	func _rotation_for_path_cell(cell: Vector2i) -> int:
		var index := _liquid_path.find(cell)
		if index >= 0 and index + 1 < _liquid_path.size():
			if _liquid_path[index + 1].y == cell.y:
				return 0
			return 1
		if index > 0 and _liquid_path[index - 1].y == cell.y:
			return 0
		return 1

	func _place_overlay(cell: Vector2i, requested_rotation := -1) -> void:
		var rotation := requested_rotation if requested_rotation >= 0 else _rotation_for_path_cell(cell)
		var overlay := {
			"type": "straight",
			"anchor": cell,
			"rotation": rotation,
			"cells": [cell],
			"placed": true,
			"overlay": true,
		}
		_overlays.append(overlay)
		_placement_history.append(overlay)
		_occupancy[_key(cell)] = overlay

	func _place_free_piece(placement: Dictionary) -> void:
		_free_placements.append(placement)
		_placement_history.append(placement)
		for raw: Variant in placement.get("cells", []):
			var cell: Vector2i = raw
			_occupancy[_key(cell)] = placement

	func _place_target(target: Dictionary, requested_rotation := -1) -> void:
		if bool(target.get("placed", false)):
			return
		target["placed"] = true
		target["placed_rotation"] = requested_rotation if requested_rotation >= 0 else int(target.get("rotation", 0))
		_placement_history.append(target)
		for raw: Variant in target.get("cells", []):
			var cell: Vector2i = raw
			_occupancy[_key(cell)] = target

	func auto_fill() -> void:
		_overlays.clear()
		_free_placements.clear()
		_occupancy.clear()
		_placement_history.clear()
		for target: Dictionary in targets:
			var placement: Dictionary = target.duplicate(true)
			placement["free"] = true
			placement["placed_rotation"] = int(target.get("rotation", 0))
			_place_free_piece(placement)
		for key: Variant in piece_counts:
			piece_counts[key] = 0
		_evaluate()
		changed.emit()
		queue_redraw()

	func has_pieces() -> bool:
		return not _placement_history.is_empty()

	func remove_last() -> bool:
		if _liquid_placed or _placement_history.is_empty():
			return false
		var piece: Dictionary = _placement_history.pop_back()
		return _remove_piece(piece)

	func remove_at(cell: Vector2i) -> bool:
		if _liquid_placed:
			return false
		var piece: Dictionary = _occupancy.get(_key(cell), {})
		if piece.is_empty():
			return false
		var index := _placement_history.find(piece)
		if index >= 0:
			_placement_history.remove_at(index)
		return _remove_piece(piece)

	func _remove_piece(piece: Dictionary) -> bool:
		var type := str(piece.get("type", ""))
		for raw: Variant in piece.get("cells", []):
			var cell: Vector2i = raw
			if _occupancy.get(_key(cell), {}) == piece:
				_occupancy.erase(_key(cell))
		if bool(piece.get("free", false)):
			_free_placements.erase(piece)
		elif bool(piece.get("overlay", false)):
			_overlays.erase(piece)
		else:
			piece["placed"] = false
			piece.erase("placed_rotation")
		piece_counts[type] = int(piece_counts.get(type, 0)) + 1
		_evaluate()
		changed.emit()
		queue_redraw()
		return true

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var cell := _cell_from_position(event.position)
			if remove_at(cell):
				accept_event()

	func _component_covered(component: Dictionary) -> bool:
		var rect: Rect2i = component.get("rect", Rect2i())
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				if not _occupancy.has(_key(Vector2i(x, y))):
					return false
		return true

	func _evaluate() -> void:
		var was_solved := _network_solved
		var path := _find_connected_path()
		if free_mode:
			_network_solved = covered_component_count() == components.size() and not path.is_empty()
		else:
			_network_solved = placed_count() == targets.size() and not path.is_empty()
		if _network_solved:
			_liquid_path = path
		else:
			_liquid_path = _make_liquid_path()
		connected_points = 5 if _network_solved else 0
		if _network_solved and not was_solved:
			solved.emit()
		queue_redraw()

	func _direction_bit(from_cell: Vector2i, to_cell: Vector2i) -> int:
		var delta := to_cell - from_cell
		if delta == Vector2i(1, 0):
			return RIGHT
		if delta == Vector2i(0, 1):
			return DOWN
		if delta == Vector2i(-1, 0):
			return LEFT
		if delta == Vector2i(0, -1):
			return UP
		return 0

	func _port_mask(target: Dictionary, cell: Vector2i) -> int:
		var mask := 0
		var type := str(target.get("type", ""))
		var rotation := int(target.get("placed_rotation", target.get("rotation", 0)))
		if type == "straight":
			mask = (LEFT | RIGHT) if rotation == 0 else (UP | DOWN)
		elif type == "elbow":
			match rotation:
				0: mask = LEFT | DOWN
				1: mask = RIGHT | DOWN
				2: mask = RIGHT | UP
				3: mask = LEFT | UP
		elif type in ["cross", "cpu", "psu"]:
			mask = LEFT | RIGHT | UP | DOWN
		elif type in ["ram", "rom", "mb"]:
			mask = (LEFT | RIGHT) if rotation % 2 == 0 else (UP | DOWN)
		elif type == "gpu":
			mask = LEFT | RIGHT | UP | DOWN
		for raw: Variant in target.get("cells", []):
			var other: Vector2i = raw
			if other != cell:
				mask |= _direction_bit(cell, other)
		return mask

	func _piece_has_port(cell: Vector2i, toward: Vector2i) -> bool:
		var target: Dictionary = _occupancy.get(_key(cell), {})
		if target.is_empty():
			return false
		var bit := _direction_bit(cell, toward)
		return bit != 0 and (_port_mask(target, cell) & bit) != 0

	func _find_connected_path() -> Array[Vector2i]:
		var queue: Array[Vector2i] = [START_CELL]
		var visited := { _key(START_CELL): true }
		var previous := {}
		var directions := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			for direction: Vector2i in directions:
				var next := current + direction
				if not _in_bounds(next):
					continue
				var next_key := _key(next)
				if next == OUTPUT_CELL:
					if not _piece_has_port(current, next):
						continue
					var result: Array[Vector2i] = [OUTPUT_CELL]
					var cursor := current
					while cursor != START_CELL:
						result.append(cursor)
						cursor = previous.get(_key(cursor), START_CELL)
					result.append(START_CELL)
					result.reverse()
					return result
				if visited.has(next_key) or not _occupancy.has(next_key):
					continue
				var can_enter := false
				if current == START_CELL:
					can_enter = _piece_has_port(next, current)
				else:
					can_enter = _piece_has_port(current, next) and _piece_has_port(next, current)
				if can_enter:
					visited[next_key] = true
					previous[next_key] = current
					queue.append(next)
		return []

	func _path_connected() -> bool:
		return not _find_connected_path().is_empty()

	func place_liquid_at_start() -> bool:
		if not active or not _network_solved or _liquid_placed:
			return false
		_liquid_placed = true
		_filling = true
		liquid_started.emit()
		queue_redraw()
		return true

	func fill_for_test() -> void:
		if not _liquid_placed and not place_liquid_at_start():
			return
		_filling = false
		fill_ratio = 1.0
		fill_changed.emit(fill_ratio)
		fill_complete.emit()
		queue_redraw()

	func _cell_rect(cell: Vector2i) -> Rect2:
		return Rect2(_origin + Vector2(cell.x * _cell_size, cell.y * _cell_size), Vector2(_cell_size, _cell_size))

	func _cell_center(cell: Vector2i) -> Vector2:
		return _origin + Vector2((cell.x + 0.5) * _cell_size, (cell.y + 0.5) * _cell_size)

	func _update_geometry() -> void:
		var max_w := maxf(120.0, (size.x - 30.0) / float(COLS))
		var max_h := maxf(80.0, (size.y - 34.0) / float(ROWS))
		_cell_size = minf(36.0, minf(max_w, max_h))
		_origin = Vector2((size.x - COLS * _cell_size) * 0.5, 22.0)

	func _draw() -> void:
		_update_geometry()
		var board_rect := Rect2(Vector2.ZERO, size)
		draw_rect(board_rect, Color(0.018, 0.055, 0.085, 0.98))
		draw_rect(board_rect, Color(0.12, 0.55, 0.7, 0.9), false, 2.0)
		for x in range(COLS + 1):
			var px := _origin.x + x * _cell_size
			draw_line(Vector2(px, _origin.y), Vector2(px, _origin.y + ROWS * _cell_size), GRID_COLOR, 1.0)
		for y in range(ROWS + 1):
			var py := _origin.y + y * _cell_size
			draw_line(Vector2(_origin.x, py), Vector2(_origin.x + COLS * _cell_size, py), GRID_COLOR, 1.0)

		# Los puntos Heat se pintan primero: están rojos hasta que una pieza
		# ocupa todas sus casillas; entonces pasan a verde.
		for component: Dictionary in components:
			_draw_component(component)
		_draw_sockets()
		_draw_pieces()
		_draw_liquid()
		_draw_terminals()
		var legend_font := get_theme_default_font()
		draw_string(legend_font, Vector2(8, size.y - 5), "ROJO = CALIENTE  ·  VERDE = CUBIERTO", HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 9, Color(0.75, 0.85, 0.9))

	func _draw_component(component: Dictionary) -> void:
		var rect: Rect2i = component.get("rect", Rect2i())
		var covered := _component_covered(component)
		var fill := Color(0.62, 0.07, 0.10, 0.82)
		var border := Color(1.0, 0.22, 0.25, 0.95)
		if covered:
			fill = Color(0.05, 0.58, 0.25, 0.86)
			border = Color(0.25, 1.0, 0.55, 0.95)
		var pixel_rect := Rect2(
			_origin + Vector2(rect.position.x * _cell_size + 2.0, rect.position.y * _cell_size + 2.0),
			Vector2(rect.size.x * _cell_size - 4.0, rect.size.y * _cell_size - 4.0)
		)
		draw_rect(pixel_rect, fill)
		draw_rect(pixel_rect, border, false, 2.0)
		var font := get_theme_default_font()
		var label := str(component.get("label", ""))
		draw_string(font, pixel_rect.position + Vector2(0, pixel_rect.size.y * 0.62), label, HORIZONTAL_ALIGNMENT_CENTER, pixel_rect.size.x, 12, Color.WHITE)

	func _draw_sockets() -> void:
		if free_mode:
			return
		for target: Dictionary in targets:
			if _target_complete(target):
				continue
			for raw: Variant in target.get("cells", []):
				var cell: Vector2i = raw
				draw_circle(_cell_center(cell), 2.5, Color(0.4, 0.8, 0.95, 0.55))

	func _draw_pieces() -> void:
		if free_mode:
			for placement: Dictionary in _free_placements:
				_draw_piece(placement)
			return
		for target: Dictionary in targets:
			if bool(target.get("placed", false)):
				_draw_piece(target)
		for overlay: Dictionary in _overlays:
			_draw_piece(overlay)

	func _draw_piece(target: Dictionary) -> void:
		var type := str(target.get("type", ""))
		var color := Color(0.28, 0.72, 0.88)
		if _network_solved:
			color = Color(0.18, 0.88, 0.55)
		if flowing:
			color = Color(0.2, 0.75, 1.0)
		if type in ["cpu", "ram", "rom", "gpu", "psu", "mb"]:
			var cells: Array = target.get("cells", [])
			var first: Vector2i = cells[0]
			var last: Vector2i = cells[cells.size() - 1]
			var rect := Rect2(
				_origin + Vector2(first.x * _cell_size + 3.0, first.y * _cell_size + 3.0),
				Vector2((last.x - first.x + 1) * _cell_size - 6.0, (last.y - first.y + 1) * _cell_size - 6.0)
			)
			draw_rect(rect, Color(color.r, color.g, color.b, 0.35))
			draw_rect(rect, color, false, 3.0)
			draw_string(get_theme_default_font(), rect.position + Vector2(0, rect.size.y * 0.65), type.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, Color.WHITE)
			return
		var cell: Vector2i = target.get("anchor", Vector2i.ZERO)
		var center := _cell_center(cell)
		var mask := _port_mask(target, cell)
		for bit: int in [RIGHT, DOWN, LEFT, UP]:
			if (mask & bit) == 0:
				continue
			var direction := Vector2i.ZERO
			if bit == RIGHT:
				direction = Vector2i(1, 0)
			elif bit == DOWN:
				direction = Vector2i(0, 1)
			elif bit == LEFT:
				direction = Vector2i(-1, 0)
			else:
				direction = Vector2i(0, -1)
			draw_line(center, center + direction * (_cell_size * 0.5), color, 7.0)
		draw_circle(center, _cell_size * 0.18, color)

	func _draw_liquid() -> void:
		if not _liquid_placed or fill_ratio <= 0.0:
			return
		var amount := int(floor(fill_ratio * float(_liquid_path.size() - 1)))
		for i in range(amount):
			var from_cell := _liquid_path[i]
			var to_cell := _liquid_path[i + 1]
			var from := _cell_center(from_cell)
			var to := _cell_center(to_cell)
			var pulse := 0.55 + 0.35 * sin(_time * 5.0 + float(i))
			draw_line(from, to, Color(0.1, 0.55 * pulse, 1.0, 0.95), 5.0)
			draw_circle(from.lerp(to, fmod(_time * 0.8 + float(i) * 0.13, 1.0)), 4.0, Color(0.45, 0.9, 1.0))

	func _draw_terminals() -> void:
		var font := get_theme_default_font()
		var start_center := _cell_center(START_CELL)
		var output_center := _cell_center(OUTPUT_CELL)
		draw_circle(start_center, _cell_size * 0.34, Color(0.95, 0.55, 0.1))
		draw_circle(start_center, _cell_size * 0.22, Color(1.0, 0.85, 0.3))
		draw_string(font, start_center + Vector2(-18, -12), "IN", HORIZONTAL_ALIGNMENT_CENTER, 36, 11, Color.WHITE)
		draw_circle(output_center, _cell_size * 0.34, Color(0.18, 0.8, 0.45))
		draw_string(font, output_center + Vector2(-22, -12), "OUT", HORIZONTAL_ALIGNMENT_CENTER, 44, 11, Color.WHITE)

func _ready() -> void:
	custom_minimum_size = Vector2(900, 430)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("07131b")
	style.set_border_width_all(2)
	style.border_color = Color(CYAN, 0.75)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16.0
	style.content_margin_top = 10.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)

	var title := Label.new()
	title.text = "CUADRO DE REFRIGERACIÓN DEL SERVIDOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", CYAN)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Coloca el kit · GIRAR cambia la orientación · conecta IN → OUT · mueve las piezas libremente"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiStyle.TEXT)
	box.add_child(hint)

	_target_label = Label.new()
	_target_label.text = "ARRASTRA AQUÍ EL KIT LÍQUIDO"
	_target_label.custom_minimum_size = Vector2(0, 36)
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target_label.add_theme_font_size_override("font_size", 15)
	_target_label.add_theme_color_override("font_color", AMBER)
	_target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_target_label)

	_board = PipePuzzleBoard.new()
	_board.name = "PipePuzzleBoard"
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.visible = false
	box.add_child(_board)
	_board.changed.connect(_on_board_changed)
	_board.rejected.connect(_on_board_rejected)
	_board.solved.connect(_on_board_solved)
	_board.liquid_started.connect(_on_liquid_started)
	_board.fill_changed.connect(_on_fill_changed)
	_board.fill_complete.connect(_on_fill_complete)
	_route = _board

	_pipe_tray_label = Label.new()
	_pipe_tray_label.text = "TUBERÍAS · rectas, L y cruces libres · piezas especiales para CPU/RAM/ROM/GPU/PSU/MB · arrastra al cuadro"
	_pipe_tray_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pipe_tray_label.add_theme_font_size_override("font_size", 12)
	_pipe_tray_label.add_theme_color_override("font_color", AMBER)
	_pipe_tray_label.visible = false
	box.add_child(_pipe_tray_label)

	_piece_tray = GridContainer.new()
	_piece_tray.columns = 6
	_piece_tray.add_theme_constant_override("h_separation", 5)
	_piece_tray.add_theme_constant_override("v_separation", 4)
	_piece_tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_piece_tray.visible = false
	box.add_child(_piece_tray)

	_token_row = HBoxContainer.new()
	_token_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_token_row.add_theme_constant_override("separation", 8)
	_token_row.visible = false
	box.add_child(_token_row)
	_liquid_token = LiquidToken.new()
	_liquid_token.visible = false
	_token_row.add_child(_liquid_token)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	box.add_child(action_row)
	_remove_button = Button.new()
	_remove_button.text = "↶ QUITAR ÚLTIMA"
	_remove_button.custom_minimum_size = Vector2(170, 34)
	_remove_button.disabled = true
	_remove_button.tooltip_text = "También puedes hacer clic derecho sobre una pieza colocada"
	_remove_button.pressed.connect(_on_remove_last)
	action_row.add_child(_remove_button)
	_pour_button = Button.new()
	_pour_button.text = "BOTAR LÍQUIDO"
	_pour_button.custom_minimum_size = Vector2(190, 34)
	_pour_button.disabled = true
	_pour_button.pressed.connect(_on_pour_button)
	action_row.add_child(_pour_button)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	_progress.value = 0.0
	_progress.show_percentage = true
	_progress.custom_minimum_size = Vector2(0, 16)
	box.add_child(_progress)

	_pump_button = Button.new()
	_pump_button.text = "ENCENDER BOMBA"
	_pump_button.custom_minimum_size = Vector2(210, 36)
	_pump_button.disabled = true
	_pump_button.pressed.connect(_on_pump_pressed)
	box.add_child(_pump_button)

	_status = Label.new()
	_status.text = "El cuadro aparece cuando coloques el kit líquido."
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	box.add_child(_status)

	# Marcadores invisibles: conservan la API anterior de _connectors para
	# las pruebas, sin quitar el nuevo tablero visual.
	var compatibility := HBoxContainer.new()
	compatibility.visible = false
	box.add_child(compatibility)
	for label in ["CPU", "RAM", "ROM", "GPU", "MB"]:
		var marker := Button.new()
		marker.text = label
		compatibility.add_child(marker)
		_connectors.append(marker)

func setup(new_expected_name: String) -> void:
	expected_name = new_expected_name
	_part = {}
	_inserted = false
	_liquid_thrown = false
	_liquid_added = false
	_network_solved = false
	_pump_step = 0
	_connector_step = 0
	_completed = false
	if _board:
		_board.reset()
		_board.visible = false
	if _target_label:
		_target_label.text = "ARRASTRA AQUÍ EL KIT LÍQUIDO"
		_target_label.add_theme_color_override("font_color", AMBER)
	_pipe_tray_label.visible = false
	_piece_tray.visible = false
	_token_row.visible = false
	if _liquid_token:
		_liquid_token.visible = false
	_pour_button.disabled = true
	_remove_button.disabled = true
	_pump_button.disabled = true
	_pump_button.text = "ENCENDER BOMBA"
	_progress.value = 0.0
	for child in _piece_tray.get_children():
		child.queue_free()
	_piece_cards.clear()
	_refresh_status()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _inserted or _completed or not (data is Dictionary):
		return false
	var part: Dictionary = data
	return str(part.get("type", "")) == "liquid" and bool(part.get("good", true)) and (expected_name == "" or str(part.get("name", "")) == expected_name)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(Vector2.ZERO, data):
		if data is Dictionary:
			_status.text = "Ese modelo no corresponde al kit líquido de este servidor."
			_status.add_theme_color_override("font_color", RED)
		return
	_part = data
	_inserted = true
	_target_label.text = "✓ KIT COLOCADO · MONTA LAS TUBERÍAS"
	_target_label.add_theme_color_override("font_color", GREEN)
	_board.visible = true
	_board.set_active(true)
	_pipe_tray_label.visible = true
	kit_placed.emit()
	_piece_tray.visible = true
	_build_piece_tray()
	_refresh_status()

func _build_piece_tray() -> void:
	for child in _piece_tray.get_children():
		child.queue_free()
	_piece_cards.clear()
	var counts := {}
	for definition: Dictionary in PIECE_DEFS:
		var card := PipePieceCard.new()
		card.setup(str(definition.type), str(definition.label), int(definition.count), definition.color)
		_piece_tray.add_child(card)
		_piece_cards.append(card)
		counts[str(definition.type)] = int(definition.count)
	_board.set_piece_counts(counts)

func _on_board_changed() -> void:
	if _board == null:
		return
	for card: PipePieceCard in _piece_cards:
		card.set_remaining(_board.remaining_for(card.piece_type))
	_remove_button.disabled = not _board.has_pieces()
	_connector_step = 5 if _board.network_is_solved() else 0
	if _board.network_is_solved():
		_network_solved = true
		_pour_button.disabled = false
		_status.text = "Cuadro completo: CPU, RAM, ROM, GPU, PSU y MB están cubiertos. Ya puedes botar líquido."
		_status.add_theme_color_override("font_color", GREEN)
	else:
		_network_solved = false
		_pour_button.disabled = true
		if _board.free_mode:
			_status.text = "Piezas colocadas: %d · calor cubierto: %d/%d · conecta IN → OUT." % [_board.placed_count(), _board.covered_component_count(), _board.components.size()]
		else:
			_status.text = "Piezas colocadas: %d/%d · las piezas rojas deben taparse." % [_board.placed_count(), _board.target_count()]
		_status.add_theme_color_override("font_color", AMBER)

func _on_board_rejected(message: String) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", RED)

func _on_board_solved() -> void:
	_network_solved = true
	_pour_button.disabled = false
	_status.text = "¡Circuito conectado! Pulsa BOTAR LÍQUIDO y arrastra el recipiente a IN."
	_status.add_theme_color_override("font_color", GREEN)

func _on_remove_last() -> void:
	if _board and _board.remove_last():
		_status.text = "Pieza quitada. Puedes recolocar o rotar la tubería."
		_status.add_theme_color_override("font_color", AMBER)


func _on_pour_button() -> void:
	if not _network_solved or _liquid_added or _completed:
		return
	_liquid_thrown = true
	_pour_button.disabled = true
	_token_row.visible = true
	_liquid_token.visible = true
	_status.text = "El líquido está en la mano: arrástralo al círculo IN del reservorio."
	_status.add_theme_color_override("font_color", AMBER)

func _on_liquid_started() -> void:
	_liquid_added = true
	_remove_button.disabled = true
	_liquid_token.visible = false
	_token_row.visible = false
	_status.text = "Líquido colocado en IN · llenando el ducto…"
	_status.add_theme_color_override("font_color", CYAN)

func _on_fill_changed(value: float) -> void:
	_progress.value = value * 100.0
	if value < 1.0:
		_status.text = "Llenando el ducto: %d%%" % int(value * 100.0)
		_status.add_theme_color_override("font_color", CYAN)

func _on_fill_complete() -> void:
	_progress.value = 100.0
	_pump_button.disabled = false
	_status.text = "DUCTO AL 100% · ya puedes encender la bomba."
	_status.add_theme_color_override("font_color", GREEN)

func _on_pump_pressed() -> void:
	if _completed or not _network_solved or not _board.is_filled():
		return
	_pump_step = 1
	_pump_button.disabled = true
	_board.flowing = true
	_board.queue_redraw()
	_finish()

func _finish() -> void:
	if _completed:
		return
	_completed = true
	_board.flowing = true
	_target_label.text = "✓ REFRIGERACIÓN LÍQUIDA INSTALADA"
	_target_label.add_theme_color_override("font_color", GREEN)
	_status.text = "Circuito completo: el servidor está refrigerado."
	_status.add_theme_color_override("font_color", GREEN)
	completed.emit(_part)

func _refresh_status() -> void:
	if _status == null:
		return
	if not _inserted:
		_status.text = "El cuadro aparece cuando coloques el kit líquido."
		_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	elif not _network_solved:
		_status.text = "Arrastra las tuberías desde abajo y conéctalas libremente desde IN."
		_status.add_theme_color_override("font_color", AMBER)
	elif not _liquid_thrown:
		_status.text = "Cuadro conectado. Pulsa BOTAR LÍQUIDO."
		_status.add_theme_color_override("font_color", CYAN)
	elif not _liquid_added:
		_status.text = "Arrastra el líquido al punto IN."
		_status.add_theme_color_override("font_color", AMBER)

# Ayuda para pruebas automatizadas; el jugador usa el arrastre real.
func insert_for_test(data: Dictionary) -> void:
	_drop_data(Vector2.ZERO, data)

func connect_for_test() -> void:
	if _board == null:
		return
	_board.set_active(true)
	_board.auto_fill()
	_on_board_changed()
	if not _liquid_added:
		fill_for_test()

func fill_for_test() -> void:
	if _board == null:
		return
	if not _board.network_is_solved():
		_board.auto_fill()
		_on_board_changed()
	if not _liquid_added:
		_board.place_liquid_at_start()
	_board.fill_for_test()
	_on_fill_changed(1.0)
	_on_fill_complete()

func pump_for_test() -> void:
	if not _board.is_filled():
		fill_for_test()
	_on_pump_pressed()
