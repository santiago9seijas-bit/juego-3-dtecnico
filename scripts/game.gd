extends Node

signal task_completed(pc_id: int)
signal game_started
signal game_finished

enum State { MENU, PLAYING, PAUSED, DONE }

const POINTS_PER_TASK := 100
const TIME_BONUS := 10.0
const MAX_CARRIED := 3
const WRONG_TIME_PENALTY := 5.0
const WRONG_POINT_PENALTY := 25
const BONUS_PER_MULT := 10
const MAX_MULTIPLIER := 5
const SETTINGS_PATH := "user://settings.cfg"

const TUTORIAL_PAGES := [
	"MOVIMIENTO\n\nUsa WASD para moverte y el MOUSE para mirar alrededor.\nAcercate a los escritorios con las computadoras y a las estaciones de repuestos.",
	"INTERACTUAR\n\nPasa el cursor por una computadora o estacion y presiona E para interactuar.\nCon ESC abres y cierras la pausa.",
	"REPUESTOS\n\nInteractua con una estacion (RAM, Disco, Fuente...) y elige el modelo que necesitas.\nLa mochila guarda hasta %d piezas: revisa tu inventario arriba a la derecha." % MAX_CARRIED,
	"REPARAR UNA PC\n\nExamina los slots para ver cual esta DAÑADA (tienes examinaciones limitadas y se recargan al reparar bien).\nArrastra el repuesto correcto al slot dañado para instalarlo.",
	"MINI JUEGOS\n\nPara sacar o poner una pieza veras un mini juego:\n- Desliza la pieza hacia la DERECHA (o izquierda al instalar).\n- Los tornillos se quitan con el destornillador: tecla 1 = LLANA, tecla 2 = CRUZ.",
	"PUNTAJE Y TIEMPO\n\nRepara computadoras para ganar puntos y tiempo extra.\nEvita errores: restan puntos y tiempo.\nAl terminar todas las PCs veras tu puntaje, errores y estrellas.",
]

const PART_TITLES := {
	"ram": "RAM",
	"hdd": "Disco Duro",
	"psu": "Fuente",
	"gpu": "Grafica",
	"mb": "Placa Madre",
	"cpu": "Procesador",
	"fan": "Fancooler",
}

const PART_VARIANTS := {
	"ram": [
		{"name": "Memoria RAM DDR3 8GB", "type": "ram"},
		{"name": "Memoria RAM DDR4 8GB", "type": "ram"},
		{"name": "Memoria RAM DDR5 16GB", "type": "ram"},
	],
	"hdd": [
		{"name": "Disco HDD 1TB", "type": "hdd"},
		{"name": "Disco SSD 256GB", "type": "hdd"},
		{"name": "Disco SSD 1TB", "type": "hdd"},
	],
	"psu": [
		{"name": "Fuente 450W", "type": "psu"},
		{"name": "Fuente 550W", "type": "psu"},
		{"name": "Fuente 750W", "type": "psu"},
	],
	"gpu": [
		{"name": "Grafica GTX 1650", "type": "gpu"},
		{"name": "Grafica RTX 3060", "type": "gpu"},
		{"name": "Grafica RTX 4080", "type": "gpu"},
	],
	"mb": [
		{"name": "Placa B450", "type": "mb"},
		{"name": "Placa B550", "type": "mb"},
		{"name": "Placa X570", "type": "mb"},
	],
	"cpu": [
		{"name": "Procesador i3-12100", "type": "cpu"},
		{"name": "Procesador i5-12400", "type": "cpu"},
		{"name": "Procesador i7-13700", "type": "cpu"},
	],
	"fan": [
		{"name": "Fancooler 120mm", "type": "fan"},
		{"name": "Fancooler de disipador", "type": "fan"},
		{"name": "Fancooler RGB 140mm", "type": "fan"},
	],
}

const LEVELS := [
	{"pc_count": 9, "time": 150.0},
	{"pc_count": 9, "time": 200.0},
	{"pc_count": 9, "time": 240.0},
]

const DOUBLE_PROBLEMS := [
	{"symptom": "Enciende con pitidos y luego se apaga", "fail": "ram", "fail2": "psu", "part": "Memoria RAM", "part2": "Fuente de poder"},
	{"symptom": "Pantalla negra y no responde los USB", "fail": "gpu", "fail2": "mb", "part": "Tarjeta Grafica", "part2": "Placa Madre"},
	{"symptom": "Se congela y pierde archivos del disco", "fail": "hdd", "fail2": "ram", "part": "Disco duro", "part2": "Memoria RAM"},
	{"symptom": "Se apaga tras sobrecalentarse", "fail": "cpu", "fail2": "psu", "part": "Procesador", "part2": "Fuente de poder"},
	{"symptom": "Sobrecalentamiento con mucho ruido", "fail": "fan", "fail2": "cpu", "part": "Fancooler", "part2": "Procesador"},
]

const SINGLE_PROBLEMS := [
	{"symptom": "No enciende al presionar el boton", "fail": "psu", "part": "Fuente de poder"},
	{"symptom": "Prende pero no da imagen", "fail": "gpu", "part": "Tarjeta Grafica"},
	{"symptom": "Se congela con programas pesados", "fail": "hdd", "part": "Disco duro"},
	{"symptom": "Se apaga solo de repente", "fail": "psu", "part": "Fuente de poder"},
	{"symptom": "Arranca con pitidos y no inicia", "fail": "ram", "part": "Memoria RAM"},
	{"symptom": "No carga el sistema operativo", "fail": "hdd", "part": "Disco duro"},
	{"symptom": "No reconoce la grafica instalada", "fail": "mb", "part": "Placa Madre"},
	{"symptom": "Se reinicia al abrir juegos", "fail": "gpu", "part": "Tarjeta Grafica"},
	{"symptom": "Pitidos largos, memoria defectuosa", "fail": "ram", "part": "Memoria RAM"},
	{"symptom": "El procesador se sobrecalienta y falla", "fail": "cpu", "part": "Procesador"},
	{"symptom": "La PC hace mucho ruido y vibra", "fail": "fan", "part": "Fancooler"},
	{"symptom": "El ventilador no gira y se calienta", "fail": "fan", "part": "Fancooler"},
]

var state: State = State.MENU
var current_level := 1
var unlocked_levels := 1
var pc_count := 5
var task_count := 5
var repaired: Array[int] = []
var score := 0
var time_left := 150.0
var current_tasks: Array[Dictionary] = []
var carried_parts: Array[Dictionary] = []
var errors := 0
var volume := 1.0
var tutorial_seen := false

var _task_counter := 1000

var hud: Node = null

var tutorial_active := false:
	set(value):
		tutorial_active = value
		_apply_mouse_mode()

var is_minigame_open := false:
	set(value):
		is_minigame_open = value
		_apply_mouse_mode()

func _ready() -> void:
	_load_settings()
	_apply_volume()

func _process(delta: float) -> void:
	if state == State.PLAYING:
		if not tutorial_active:
			time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			_finish_level()

func examine_limit() -> int:
	return [4, 3, 2][clampi(current_level - 1, 0, 2)]

func screw_count_range() -> Vector2i:
	return [Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6)][clampi(current_level - 1, 0, 2)]

func phillips_probability() -> float:
	return [0.5, 0.65, 0.8][clampi(current_level - 1, 0, 2)]

func stars_for_score() -> int:
	var max_score := maxi(1, task_count * POINTS_PER_TASK)
	var ratio := clampf(float(score) / float(max_score), 0.0, 1.0)
	if ratio >= 0.8:
		return 3
	if ratio >= 0.5:
		return 2
	return 1 if repaired.size() > 0 else 0

func register_error() -> void:
	errors += 1

func tutorial_level_text() -> String:
	var limit := examine_limit()
	var screw_range: Vector2i = screw_count_range()
	var phi := phillips_probability()
	return ("Te llegaran constantemente equipos: repara todos los que puedas antes de que se termine el tiempo.\n\n") + \
		("En este nivel tienes %d examinaciones por slot dañado (menos que en el nivel 1).\n" % limit if current_level > 1 else "Tienes %d examinaciones por slot: usalas para descubrir que esta DAÑADO sin errores.\n" % limit) + \
		("Tambien habra %d-%d tornillos por pieza, y hay %d%% de probabilidad de que sean de cabeza CRUZ (usa la tecla 2).\n" % [screw_range.x, screw_range.y, int(phi * 100.0)]) + \
		"Cuida tus errores: restan puntos, tiempo y mala nota."

func add_multiplier_bonus(multiplier: int) -> void:
	var bonus := maxi(0, multiplier - 1) * BONUS_PER_MULT
	score += bonus

func _finish_level() -> void:
	if state == State.DONE:
		return
	state = State.DONE
	_apply_mouse_mode()
	if current_level >= unlocked_levels and unlocked_levels < LEVELS.size():
		unlocked_levels += 1
	game_finished.emit()

func start_level(level_idx: int) -> void:
	current_level = level_idx
	var lvl: Dictionary = LEVELS[level_idx - 1]
	pc_count = lvl.pc_count
	task_count = pc_count
	time_left = lvl.time
	_build_tasks()
	repaired.clear()
	score = 0
	errors = 0
	carried_parts.clear()
	is_minigame_open = false
	tutorial_active = false
	state = State.PLAYING
	_apply_mouse_mode()
	game_started.emit()

func start_game() -> void:
	start_level(current_level)

func pause_game() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	_apply_mouse_mode()

func resume_game() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	_apply_mouse_mode()

func quit_to_menu() -> void:
	state = State.MENU
	_apply_mouse_mode()

func all_done() -> bool:
	return repaired.size() >= task_count

func mark_repaired(pc_id: int) -> void:
	if pc_id in repaired:
		return
	repaired.append(pc_id)
	score += POINTS_PER_TASK
	time_left = clampf(time_left + TIME_BONUS, 0.0, LEVELS[current_level - 1].time)
	task_completed.emit(pc_id)
	if all_done():
		_finish_level()

func pick_part_variant(variant: Dictionary) -> bool:
	if carried_parts.size() >= MAX_CARRIED:
		return false
	carried_parts.append({"name": variant.name, "type": variant.type, "good": true})
	return true

func remove_carried(data: Dictionary) -> void:
	var idx := carried_parts.find(data)
	if idx >= 0:
		carried_parts.remove_at(idx)

func random_variant(part_type: String) -> Dictionary:
	var variants: Array = PART_VARIANTS[part_type]
	return variants[randi() % variants.size()]

func penalize() -> void:
	time_left = maxf(0.0, time_left - WRONG_TIME_PENALTY)
	score = maxi(0, score - WRONG_POINT_PENALTY)
	register_error()

func new_task() -> Dictionary:
	var p: Dictionary
	if randf() < 0.3 and DOUBLE_PROBLEMS.size() > 0:
		p = DOUBLE_PROBLEMS[randi() % DOUBLE_PROBLEMS.size()]
	else:
		p = SINGLE_PROBLEMS[randi() % SINGLE_PROBLEMS.size()]
	_task_counter += 1
	var v1: Dictionary = random_variant(p.fail)
	var v2: Dictionary = {}
	if p.get("fail2", "") != "":
		v2 = random_variant(p.fail2)
	return {
		"id": _task_counter,
		"symptom": p.symptom,
		"fail": p.fail,
		"fail2": p.get("fail2", ""),
		"part": p.part,
		"part2": p.get("part2", ""),
		"variant": v1.name,
		"variant2": v2.get("name", ""),
	}

func _build_tasks() -> void:
	current_tasks.clear()
	var singles: Array = SINGLE_PROBLEMS.duplicate()
	var doubles: Array = DOUBLE_PROBLEMS.duplicate()
	singles.shuffle()
	doubles.shuffle()
	var pool: Array = []
	pool.append(doubles.pop_front())
	var need := pc_count - 1
	while need > 0 and doubles.size() > 0:
		pool.append(doubles.pop_front())
		need -= 1
	while need > 0 and singles.size() > 0:
		pool.append(singles.pop_front())
		need -= 1
	while need > 0:
		pool.append(singles[randi() % singles.size()])
		need -= 1
	pool.shuffle()
	for i in pc_count:
		var p: Dictionary = pool[i]
		var v1: Dictionary = random_variant(p.fail)
		var v2: Dictionary = {}
		if p.get("fail2", "") != "":
			v2 = random_variant(p.fail2)
		current_tasks.append({
			"id": i + 1,
			"symptom": p.symptom,
			"fail": p.fail,
			"fail2": p.get("fail2", ""),
			"part": p.part,
			"part2": p.get("part2", ""),
			"variant": v1.name,
			"variant2": v2.get("name", ""),
		})

func _apply_mouse_mode() -> void:
	var show := state != State.PLAYING or is_minigame_open or tutorial_active
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show else Input.MOUSE_MODE_CAPTURED

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	tutorial_seen = bool(cfg.get_value("general", "tutorial_seen", false))
	volume = clampf(float(cfg.get_value("general", "volume", 1.0)), 0.0, 1.0)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "tutorial_seen", tutorial_seen)
	cfg.set_value("general", "volume", volume)
	cfg.save(SETTINGS_PATH)

func set_tutorial_seen(value: bool) -> void:
	tutorial_seen = value
	_save_settings()

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_settings()

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))