extends Node

signal task_completed(pc_id: int)
signal game_started
signal game_finished
signal tutorial_finished
signal tutorial_exited

enum State { MENU, PLAYING, PAUSED, DONE }

const POINTS_PER_TASK := 100
const TIME_BONUS := 10.0
const MAX_CARRIED := 3
const WRONG_TIME_PENALTY := 5.0
const WRONG_POINT_PENALTY := 25
const BONUS_PER_MULT := 10
const MAX_MULTIPLIER := 5
const SETTINGS_PATH := "user://settings.cfg"

# Manual del técnico (menú de inicio): índice, pasos numerados y avisos,
# con otra sintaxis y otra paleta que las fichas de cada pieza.
const TUTORIAL_PAGES := [
	"[center][color=#ffb020][b]▌ 00 · ÍNDICE DEL MANUAL[/b][/color][/center]\n" +
	"[color=#3a4c60]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n" +
	"▸  [color=#3ce08a][b]01[/b][/color]   Moverse por la sala y mirar\n" +
	"▸  [color=#3ce08a][b]02[/b][/color]   Interactuar con E, pausar con ESC\n" +
	"▸  [color=#3ce08a][b]03[/b][/color]   Repuestos, estaciones y mochila\n" +
	"▸  [color=#3ce08a][b]04[/b][/color]   Slots dañados y examinaciones\n" +
	"▸  [color=#3ce08a][b]05[/b][/color]   Minijuegos: deslizar, tornillos, cautín\n" +
	"▸  [color=#3ce08a][b]06[/b][/color]   Puntaje, errores y tiempo\n" +
	"[color=#3a4c60]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n" +
	"[center][color=#6f8ba0]Una lección por página: léela, inténtalo y repite.[/color][/center]",

	"[center][color=#ffb020][b]▌ 01 · MOVERSE E INTERACTUAR[/b][/color][/center]\n\n" +
	"① Mira alrededor con el [color=#19e6ff][b]MOUSE[/b][/color] y camina con [color=#19e6ff][b]W A S D[/b][/color].\n" +
	"② Acércate a un escritorio o a una estación de repuestos.\n" +
	"③ Pulsa [color=#ffb020][b]E[/b][/color] cuando arriba aparezca el rótulo “E - …”.\n" +
	"④ [color=#ff6b8a][b]ESC[/b][/color] abre la pausa; REANUDAR vuelve al juego.\n\n" +
	"[color=#3a4c60]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n" +
	"[center][color=#3ce08a]✓  No hace falta mirar de frente: basta estar cerca.[/color][/center]",

	"[center][color=#ffb020][b]▌ 02 · REPUESTOS Y MOCHILA[/b][/color][/center]\n\n" +
	"▸  [b]Estaciones[/b]   RAM · DISCO · FUENTE · GRÁFICA · PLACA · CPU · FAN\n" +
	("▸  [b]Mochila[/b]      caben [color=#ffb020][b]%d piezas[/b][/color]; se ven arriba a la derecha.\n" % MAX_CARRIED) +
	"▸  [b]Tomar[/b]        E en la estación → elige el modelo → viaja en la mochila.\n" +
	"▸  [b]Botar[/b]        la pieza sale [color=#ff6b8a][b]DAÑADA[/b][/color] → llévala a la PAPELERA.\n\n" +
	"[color=#3a4c60]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n" +
	"[center][color=#ff6b8a]✗  Una pieza dañada NO se puede instalar.[/color][/center]",

	"[center][color=#ffb020][b]▌ 03 · SLOTS DAÑADOS Y EXAMINACIONES[/b][/color][/center]\n\n" +
	"① E sobre la PC → se abre REPARACIÓN DE COMPUTADORA.\n" +
	"② Pulsa [b]EXAMINAR[/b] en un slot: dice si está DAÑADA y qué modelo pide.\n" +
	"③ Tienes examinaciones limitadas; se recargan al reparar bien una PC.\n" +
	"④ Al examinar: SOBRETENSIÓN brilla [color=#b45cff][b]MORADO[/b][/color] · QUEMADA brilla [color=#9a9aa4][b]NEGRO[/b][/color].\n" +
	"⑤ Si el slot ofrece [b]SOLDAR[/b], elige: soldar directo o [b]VOLTAJE[/b] (mides primero y luego sueldas sin riesgo).\n" +
	"⑥ Si no, arrastra el repuesto al slot → mini juego → [color=#3ce08a][b]¡Reparado![/b][/color]\n\n" +
	"[color=#3a4c60]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n" +
	"[center][color=#6f8ba0]El SÍNTOMA es la pista: léelo antes de gastar examinaciones.[/color][/center]",

	"[center][color=#ffb020][b]▌ 04 · MINIJUEGOS Y HERRAMIENTAS[/b][/color][/center]\n\n" +
	"▸  [color=#19e6ff][b]Deslizar[/b][/color]     arrastra la pieza hasta el extremo verde.\n" +
	"▸  [color=#19e6ff][b]Tornillos[/b][/color]   [color=#ffb020][b]1[/b][/color] = LLANA   ·   [color=#ffb020][b]2[/b][/color] = CRUZ.\n" +
	"▸  [color=#19e6ff][b]Cautín[/b][/color]       sigue la pista con la soldadura sin salirte; es el camino del botón [b]SOLDAR[/b].\n" +
	"▸  [color=#19e6ff][b]Voltímetro[/b][/color]   detén la aguja en verde (clic o ESPACIO).\n\n" +
	"[color=#3a4c60]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n" +
	"[center][color=#ffb020]⌁  El destornillador equivocado no saca el tornillo.[/color][/center]",

	"[center][color=#ffb020][b]▌ 05 · PUNTAJE, ERRORES Y TIEMPO[/b][/color][/center]\n\n" +
	("▸  Reparar una PC:  [color=#3ce08a][b]+%d puntos[/b][/color] y te devuelve tiempo." % POINTS_PER_TASK) + "\n" +
	"▸  Error de pieza o de tornillo: [color=#ff6b8a][b]pierdes[/b][/color] puntos y segundos.\n" +
	"▸  Al terminar verás: puntaje, errores, tiempo y estrellas ★★★.\n" +
	"▸  Si el reloj llega a cero se cierra la partida con tu resumen.\n\n" +
	"[color=#3a4c60]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n" +
	"[center][color=#6f8ba0]★★★ = casi sin errores.  ★☆☆ = ya quedó reparada.[/color][/center]",
]

const PART_TITLES := {
	"ram": "RAM",
	"hdd": "Disco Duro",
	"psu": "Fuente",
	"gpu": "Grafica",
	"mb": "Placa Madre",
	"cpu": "Procesador",
	"fan": "Fancooler",
	# Tutoriales de mecánica (no son piezas: son herramientas del taller).
	"volt": "Voltímetro",
	"solder": "Soldadura con Cautín",
	"trash": "Papelera",
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

const SECTION_NAMES := [
	"SECCIÓN DE REPARACIÓN",
	"SECCIÓN DE SOFTWARE",
	"SECCIÓN DE SERVIDORES",
]

# Fichas de cada sección: se leen al pasar el mouse sobre el botón.
const SECTION_INFO := [
	"Diagnóstico y sustitución de hardware: memorias, discos duros, fuentes, gráficas, placas madre, procesadores y fancoolers.\n\n" +
	"Recorrerás la sala de servicio, examinarás cada computadora averiada, tomarás el repuesto correcto de la estantería y lo instalarás en el slot dañado. Juegas contra el reloj: cada reparación suma puntos y te devuelve unos segundos de tiempo.\n\n" +
	"Está disponible en modo tutorial, sin prisa y sin penalizaciones, y en modo nivel con cronómetro para poner a prueba lo aprendido.",
	"Instalación de sistemas operativos, controladores, limpieza de virus y optimización del equipo.\n\n" +
	"[color=#6f8ba0]Sección bloqueada: se habilitará más adelante.[/color]",
	"Montaje y mantenimiento de servidores: red, almacenamiento, usuarios y copias de seguridad.\n\n" +
	"[color=#6f8ba0]Sección bloqueada: se habilitará más adelante.[/color]",
]

const TUTORIALS_MENU_TEXT := \
	"Una habitación, una sola computadora y lo que quieres aprender: sin cronómetro, sin puntaje y sin penalizaciones.\n\n" + \
	"Al entrar verás para qué sirve la pieza o la herramienta y qué pasa cuando falla. Después practicas el paso completo: examinar, sacar, instalar o soldar. Puedes repetirlo las veces que quieras hasta que te salga de memoria.\n\n" + \
	"Hay un tutorial para cada una de las siete piezas (RAM, disco duro, fuente, gráfica, placa madre, procesador y fancooler) y tres más para las mecánicas del taller: voltímetro, cautín con soldadura y papelera."

# Ficha corta de cada pieza: para que sirve y que descompone la PC si falla.
const PART_INFO := {
	"ram": {
		"use": "Memoria volátil y temporal: guarda los datos y programas en uso para que el procesador los consulte al instante.",
		"fails": "La PC pita y no da imagen, se congela, se reinicia sola o falla al abrir varios programas a la vez.",
	},
	"hdd": {
		"use": "Almacenamiento permanente: guarda el sistema operativo, los programas y todos tus archivos.",
		"fails": "No carga el sistema, la PC se pone lenta, archivos corruptos, pantallazos azules o pérdida de datos.",
	},
	"psu": {
		"use": "Convierte la corriente de la pared (AC) en las tensiones que usan los componentes: 12V, 5V y 3.3V.",
		"fails": "La PC no enciende, se apaga o se reinicia sola, y bajo carga puede dañar otros componentes.",
	},
	"gpu": {
		"use": "Procesa todos los gráficos y 3D, y envía la imagen hacia los monitores.",
		"fails": "No da imagen, aparecen líneas o colores raros, los juegos se cierran o el controlador no carga.",
	},
	"mb": {
		"use": "Es el circuito base: conecta y alimenta a todos los demás componentes entre sí.",
		"fails": "No reconoce la RAM ni los discos, no enciende, puertos muertos o fallos intermitentes.",
	},
	"cpu": {
		"use": "El cerebro de la PC: ejecuta todas las instrucciones del software y hace cada cálculo.",
		"fails": "Se apaga por sobrecalentamiento, pierde rendimiento, se congela o muestra errores azules.",
	},
	"fan": {
		"use": "Enfría el procesador y la carcasa disipando el calor que generan los componentes.",
		"fails": "Sobrecalentamiento, la PC se pone lenta por protección, hace mucho ruido y puede apagarse.",
	},
	# Fichas de las mecánicas (tutoriales que no son de una pieza).
	"volt": {
		"use": "Mide los voltajes que circulan por la placa y la fuente (12V, 5V y 3.3V) para comprobar que los rieles están dentro de rango.",
		"fails": "Si un rie sale de rango por una sobretensión, la PC se apaga, reinicia sola o quema otros componentes: al examinar la pieza afectada verás un brillo MORADO.",
	},
	"solder": {
		"use": "El cautín derrite la soldadura para reparar conexiones: repara pistas y pines quemados sin cambiar la pieza entera.",
		"fails": "Sin soldar, las conexiones quedan sueltas: la pieza sigue dañada aunque cambies todo lo demás. Una pieza quemada (brillo NEGRO) se arregla con el cautín.",
	},
	"trash": {
		"use": "Aquí se botan las piezas dañadas que sacas de las computadoras: la mochila solo admite %d piezas y las dañadas ocupan lugar." % MAX_CARRIED,
		"fails": "Si no las botas, la mochila se llena y no puedes sacar ni instalar otra pieza: te bloqueas a mitad de reparación.",
	},
}

# Piezas disponibles: los niveles 1-2 NO traen procesador ni fancooler
# (solo lo que aparece ahí) y los niveles 3-4 solo placa y fuente.
const ALL_PARTS := ["ram", "hdd", "psu", "gpu", "mb", "cpu", "fan"]
const BASIC_PARTS := ["ram", "hdd", "psu", "gpu", "mb"]
const BOARD_PARTS := ["psu", "mb"]

# Los 6 niveles de la sección 1:
#   1-2: piezas básicas, sala pequeña (3 PCs), cajas juntas y papelera.
#   3-4: placas y fuentes con voltímetro y cautín con soldadura (4 PCs).
#   5-6: todas las piezas y mecánicas en una sala mediana, 5 PCs,
#        cajas en fila y la papelera al frente de los escritorios.
const LEVELS := [
	{"pc_count": 3, "time": 120.0, "parts": BASIC_PARTS, "room": "small"},
	{"pc_count": 3, "time": 160.0, "parts": BASIC_PARTS, "room": "small"},
	{"pc_count": 4, "time": 190.0, "parts": BOARD_PARTS, "room": "small", "volt": true, "solder": true},
	{"pc_count": 4, "time": 230.0, "parts": BOARD_PARTS, "room": "small", "volt": true, "solder": true},
	{"pc_count": 5, "time": 270.0, "parts": ALL_PARTS, "room": "medium", "volt": true, "solder": true},
	{"pc_count": 5, "time": 330.0, "parts": ALL_PARTS, "room": "medium", "volt": true, "solder": true},
]

# ------------------------------------------------------------------
# Tipos de daño: al EXAMINAR se ven con un brillo distinto.
#   volt → sobretensión (brillo MORADO): la pieza sufrió picos de voltaje.
#   burn → quemada (brillo NEGRO): se puede arreglar soldando.
#   swap → daño normal: hay que cambiarla por el repuesto.
# Y cómo se arregla cada una: SOLDAR (cautín) o SWAP (cambiarla).
# ------------------------------------------------------------------
const FAULT_VOLT := "volt"
const FAULT_BURN := "burn"
const FAULT_SWAP := "swap"
const FIX_SOLDER := "solder"
const FIX_SWAP := "swap"

# Piezas que pueden sufrir daños de voltaje (placa, fuente, fancooler)
# y piezas que pueden quemarse (se arreglan soldando).
const VOLTAGE_PARTS := ["mb", "psu", "fan"]
const BURN_PARTS := ["ram", "gpu", "cpu", "mb", "psu", "fan"]

# Tres tutoriales de mecánica, además de los de cada pieza:
#   volt → voltímetro, solder → cautín, trash → papelera.
const MECHANIC_TUTORIALS := ["volt", "solder", "trash"]
const MECHANIC_PART := {"volt": "mb", "solder": "fan", "trash": "ram"}
# Etiqueta corta de cada botón de mecánica (la fila es angosta).
const MECHANIC_SHORT := {"volt": "VOLTMETRO", "solder": "CAUTÍN", "trash": "PAPELERA"}

func fault_for(part_type: String) -> String:
	# Los fallos de voltaje/quemadura solo existen donde hay voltímetro y cautín.
	if not level_uses_volt() and not level_uses_solder():
		return FAULT_SWAP
	if part_type in VOLTAGE_PARTS and randf() < 0.55:
		return FAULT_VOLT
	if part_type in BURN_PARTS and randf() < 0.45:
		return FAULT_BURN
	return FAULT_SWAP

# Un daño de voltaje a veces se cambia y a veces solo se suelda; una
# quemadura casi siempre se arregla con el cautín.
func fix_for(fault: String) -> String:
	if not level_uses_solder():
		return FIX_SWAP
	if fault == FAULT_VOLT:
		return FIX_SOLDER if randf() < 0.5 else FIX_SWAP
	if fault == FAULT_BURN:
		return FIX_SOLDER if randf() < 0.65 else FIX_SWAP
	return FIX_SWAP

const DOUBLE_PROBLEMS := [
	{"symptom": "Enciende con pitidos y luego se apaga", "fail": "ram", "fail2": "psu", "part": "Memoria RAM", "part2": "Fuente de poder"},
	{"symptom": "Pantalla negra y no responde los USB", "fail": "gpu", "fail2": "mb", "part": "Tarjeta Grafica", "part2": "Placa Madre"},
	{"symptom": "Se congela y pierde archivos del disco", "fail": "hdd", "fail2": "ram", "part": "Disco duro", "part2": "Memoria RAM"},
	{"symptom": "Se apaga tras sobrecalentarse", "fail": "cpu", "fail2": "psu", "part": "Procesador", "part2": "Fuente de poder"},
	{"symptom": "Sobrecalentamiento con mucho ruido", "fail": "fan", "fail2": "cpu", "part": "Fancooler", "part2": "Procesador"},
	{"symptom": "Voltaje inestable: se apaga y la placa pierde los periféricos", "fail": "psu", "fail2": "mb", "part": "Fuente de poder", "part2": "Placa Madre"},
	{"symptom": "La fuente quema los cables y la placa queda sin señal", "fail": "psu", "fail2": "mb", "part": "Fuente de poder", "part2": "Placa Madre"},
]

const SINGLE_PROBLEMS := [
	# Fallos ligados a las mecánicas nuevas: sobretensiones (voltímetro)
	# y quemaduras (se arreglan soldando con el cautín).
	{"symptom": "La placa tiene un capacitor quemado por sobretensión", "fail": "mb", "part": "Placa Madre"},
	{"symptom": "Sobretensión en los rieles: se apaga al arrancar", "fail": "psu", "part": "Fuente de poder"},
	{"symptom": "El fancooler se quemó y huele a plástico", "fail": "fan", "part": "Fancooler"},
	{"symptom": "Cortocircuito: la placa suelta chispas", "fail": "mb", "part": "Placa Madre"},
	{"symptom": "La fuente quema los cables de alimentación", "fail": "psu", "part": "Fuente de poder"},
	{"symptom": "Quemadura en la ranura de la memoria", "fail": "ram", "part": "Memoria RAM"},
	{"symptom": "La gráfica se quemó con un pico de voltaje", "fail": "gpu", "part": "Tarjeta Grafica"},
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

# Modo tutorial: habitación pequeña, una sola pieza y SIN cronómetro.
var tutorial_mode := false
var tutorial_part := "ram"
# Mecánica que enseña el tutorial actual ("", "volt", "solder", "trash").
var tutorial_mechanic := ""

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
	if state != State.PLAYING or tutorial_mode:
		return
	if not tutorial_active:
		time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		_finish_level()

func examine_limit() -> int:
	return [4, 3, 2][clampi(current_level - 1, 0, 2)]

func _level(idx := -1) -> Dictionary:
	var i := current_level if idx < 0 else idx
	return LEVELS[clampi(i - 1, 0, LEVELS.size() - 1)]

# Piezas que existen en este nivel: definen estanterías, slots y fallas.
func level_parts() -> Array:
	return _level().get("parts", ALL_PARTS)

# Niveles 1-4: sala pequeña con todo cerca; 5-6: la sala mediana
# (5 PCs en fila, cajas juntas y la papelera al frente de los escritorios).
func uses_small_room() -> bool:
	return _level().get("room", "big") == "small"

func uses_medium_room() -> bool:
	return _level().get("room", "big") == "medium"

# En los niveles con sala cerrada (pequeña o mediana) no se ve el escenario.
func uses_closed_room() -> bool:
	return uses_small_room() or uses_medium_room()

func level_uses_volt() -> bool:
	if tutorial_mode and tutorial_mechanic in ["volt", "solder"]:
		return true
	return _level().get("volt", false)

func level_uses_solder() -> bool:
	if tutorial_mode and tutorial_mechanic in ["volt", "solder"]:
		return true
	return _level().get("solder", false)

# Mecánicas nuevas (voltímetro y cautín) sobre placa madre y fuente.
func uses_tech(part_type: String) -> bool:
	if tutorial_mode:
		return tutorial_mechanic == "volt" and part_type in ["mb", "psu"]
	return part_type in ["mb", "psu"] and level_uses_volt() and level_uses_solder()

# La pieza que trae la caja/estación de un tutorial de mecánica.
func tutorial_station_part() -> String:
	return MECHANIC_PART.get(tutorial_part, tutorial_part)

# La papelera se usa en los niveles y en el tutorial de papelera
# (en los demás tutoriales no hay piezas dañadas).
func level_has_trash() -> bool:
	return (not tutorial_mode) or tutorial_mechanic == "trash"

func _problem_ok(p: Dictionary) -> bool:
	var parts: Array = level_parts()
	if p.fail not in parts:
		return false
	var fail2: String = p.get("fail2", "")
	return fail2 == "" or fail2 in parts

func _level_singles() -> Array:
	var out: Array = []
	for p in SINGLE_PROBLEMS:
		if _problem_ok(p):
			out.append(p)
	return out

func _level_doubles() -> Array:
	var out: Array = []
	for p in DOUBLE_PROBLEMS:
		if _problem_ok(p):
			out.append(p)
	return out

# ------------------------------------------------------------------
# Mochila: además de los repuestos buenos carga las piezas dañadas,
# que hay que botar a la papelera para liberar espacio.
# ------------------------------------------------------------------
func add_damaged(part: Dictionary) -> bool:
	if tutorial_mode and tutorial_mechanic != "trash":
		return false
	if carried_parts.size() >= MAX_CARRIED:
		return false
	carried_parts.append({
		"name": part.get("name", ""),
		"type": part.get("type", ""),
		"good": false,
	})
	return true

func damaged_count() -> int:
	var n := 0
	for p in carried_parts:
		if not p.get("good", true):
			n += 1
	return n

func trash_damaged() -> int:
	var n := 0
	for i in range(carried_parts.size() - 1, -1, -1):
		if not carried_parts[i].get("good", true):
			carried_parts.remove_at(i)
			n += 1
	return n

func screw_count_range() -> Vector2i:
	return screw_count_range_for(current_level)

func phillips_probability() -> float:
	return phillips_probability_for(current_level)

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

# Cómo se practica cada mecánica en su tutorial.
const MECHANIC_TUTORIAL_TEXT := {
	"volt": "Entrarás a una sala sin cronómetro con una placa que sufrió una sobretensión: al examinarla el slot brilla en MORADO. Examina el slot, toma la placa de la caja y pasa la cadena completa: primero sueldas con el cautín, después atornillas y al final mides los rieles con el voltímetro hasta detener la aguja en la zona verde.",
	"solder": "Entrarás a una sala sin cronómetro con un fancooler quemado: al examinarlo el slot brilla en NEGRO. No hace falta cambiarlo: examina el slot y pulsa SOLDAR para arrastrar la soldadura por toda la pista con el cautín hasta el final (pero cuidado: si te sales 3 veces la pieza se pierde). Si prefieres ir seguro, pulsa VOLTAJE, mides los rieles con el voltímetro y recién ahí sueldas: así un fallo no arruina la pieza.",
	"trash": "Entrarás con la mochila ocupada: examina la PC, saca la pieza dañada (queda marcada como DAÑADA en el inventario) y llévala a la papelera para liberar espacio antes de instalar el repuesto bueno.",
}

# Ficha de la pieza en párrafos completos (para el menú de tutoriales).
func part_long_text(part_type: String) -> String:
	var info: Dictionary = PART_INFO.get(part_type, {})
	var title: String = PART_TITLES.get(part_type, part_type)
	var how: String
	if part_type in MECHANIC_TUTORIALS:
		how = MECHANIC_TUTORIAL_TEXT.get(part_type, "")
	else:
		how = "Entrarás a una habitación sin cronómetro con una sola computadora que tiene exactamente esta pieza dañada. Toma el repuesto de la caja, examina la PC y arrástralo al slot dañado. Es el tutorial de %s y puedes repetirlo todas las veces que quieras." % title
	return ("[color=#19e6ff][b]QUÉ ES[/b][/color]\n%s\n\n" % info.get("use", "")) + \
		("[color=#ff6b8a][b]QUÉ PASA SI FALLA[/b][/color]\n%s\n\n" % info.get("fails", "")) + \
		("[color=#19e6ff][b]EN EL TUTORIAL[/b][/color]\n%s" % how)

# Tiempo total del nivel en curso (para el reloj del HUD y sus avisos).
func level_time_total() -> float:
	var lvl: Dictionary = LEVELS[clampi(current_level - 1, 0, LEVELS.size() - 1)]
	return float(lvl.get("time", 120.0))

# Ficha corta de cada nivel en párrafos completos: qué hay, cómo se
# juega y los controles. Se lee al pasar el mouse sobre el botón.
func level_info_text(level_idx: int) -> String:
	var lvl: Dictionary = LEVELS[clampi(level_idx - 1, 0, LEVELS.size() - 1)]
	var names: Array = []
	for t: String in lvl.get("parts", ALL_PARTS):
		names.append(PART_TITLES.get(t, t))
	var mech: Array = ["papelera para botar las piezas dañadas"]
	if lvl.get("volt", false):
		mech.push_front("voltímetro")
	if lvl.get("solder", false):
		mech.push_front("cautín con soldadura")
	var extra := ""
	if lvl.get("room", "big") == "small":
		extra = " La sala es pequeña: los escritorios, las cajas de repuestos (una al lado de la otra) y la papelera están todos cerca."
	elif lvl.get("room", "big") == "medium":
		extra = " La sala es mediana: los %d escritorios van en fila, las cajas de repuestos quedan una al lado de la otra y la papelera queda al lado de la fila de escritorios, a un paso de donde sacas las piezas dañadas." % int(lvl.pc_count)
	var daños := ""
	if lvl.get("volt", false) or lvl.get("solder", false):
		daños = (
			"[color=#ffb020][b]DAÑOS Y REPARACIONES[/b][/color]\n" +
			"Al examinar, una pieza con sobretensión brilla en MORADO y una quemada brilla en NEGRO. " +
			"Las quemadas (y parte de las de voltaje) se arreglan soldando y ahí tú eliges: SOLDAR directo (si te sales 3 veces de la pista la pieza queda INSALVABLE y hay que cambiarla) o VOLTAJE, donde primero mides los rieles con el voltímetro y luego sueldas sin riesgo de perder la pieza. " +
			"Las demás hay que cambiarlas, y la pieza que sacas queda DAÑADA en la mochila hasta botarla a la papelera.\n\n"
		)
	return (
		("[color=#19e6ff][b]QUÉ HAY EN ESTE NIVEL[/b][/color]\n" +
		"%d computadoras contra un cronómetro de %d segundos. Cada reparación suma %d puntos y devuelve %d segundos. " +
		"Solo aparecen estas piezas: %s.%s\n\n" +
		"[color=#ff6b8a][b]CÓMO JUGAR[/b][/color]\n" +
		"Pulsa E sobre una computadora para examinar sus slots (tienes %d examinaciones) y descubre qué componente falló. " +
		"Después toma el repuesto en la estantería y arrástralo al slot dañado: las piezas traen de %d a %d tornillos y hay un %d%% de probabilidad de que sean de cabeza cruz (destornillador 2). " +
		"La pieza dañada que saques queda marcada como DAÑADA en tu mochila y hay que botarla a la papelera antes de seguir cargando. Mecánicas de este nivel: %s.\n\n" +
		daños +
		"[color=#19e6ff][b]CONTROLES[/b][/color]\n" +
		"WASD para moverte, el mouse para mirar, E para interactuar y ESC para pausar. Usa la tecla 1 para el destornillador llano y la 2 para el de cabeza cruz.")
	) % [
		int(lvl.pc_count),
		int(lvl.time),
		POINTS_PER_TASK,
		int(TIME_BONUS),
		", ".join(names),
		extra,
		[4, 3, 2][clampi(level_idx - 1, 0, 2)],
		screw_count_range_for(level_idx).x,
		screw_count_range_for(level_idx).y,
		int(phillips_probability_for(level_idx) * 100.0),
		" y ".join(mech),
	]

func screw_count_range_for(idx: int) -> Vector2i:
	return [Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6)][clampi(idx - 1, 0, 2)]

func phillips_probability_for(idx: int) -> float:
	return [0.5, 0.65, 0.8][clampi(idx - 1, 0, 2)]

func add_multiplier_bonus(multiplier: int) -> void:
	var bonus := maxi(0, multiplier - 1) * BONUS_PER_MULT
	score += bonus

func _finish_level() -> void:
	if state == State.DONE:
		return
	state = State.DONE
	_apply_mouse_mode()
	# Las secciones 2 (software) y 3 (servidores) se quedan bloqueadas por ahora.
	game_finished.emit()

func start_level(level_idx: int) -> void:
	tutorial_mode = false
	tutorial_mechanic = ""
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

# Arranca un tutorial: una habitación pequeña con UNA sola PC que tiene
# exactamente la pieza indicada, sin cronómetro y sin penalizaciones.
# También acepta las mecánicas del taller: "volt", "solder" y "trash".
func start_tutorial(part_type: String) -> void:
	tutorial_mode = true
	tutorial_part = part_type
	tutorial_mechanic = part_type if part_type in MECHANIC_TUTORIALS else ""
	current_level = 1
	pc_count = 1
	task_count = 1
	time_left = LEVELS[0].time
	current_tasks = [_tutorial_task(tutorial_station_part())]
	repaired.clear()
	score = 0
	errors = 0
	carried_parts.clear()
	is_minigame_open = false
	tutorial_active = false
	state = State.PLAYING
	_apply_mouse_mode()
	game_started.emit()

# Síntomas fijos de los tutoriales de mecánica.
const MECHANIC_SYMPTOM := {
	"volt": "Sobretensión en los rieles: la PC se apaga sola",
	"solder": "Fancooler quemado: la conexión quedó fundida",
	"trash": "Arranca con pitidos y no inicia",
}

func _tutorial_task(part_type: String) -> Dictionary:
	_task_counter += 1
	# Cada mecánica enseña un camino distinto de reparación.
	var fault := FAULT_SWAP
	var fix := FIX_SWAP
	if tutorial_mechanic == "volt":
		fault = FAULT_VOLT
		fix = FIX_SWAP
	elif tutorial_mechanic == "solder":
		fault = FAULT_BURN
		fix = FIX_SOLDER
	var symptom: String = str(MECHANIC_SYMPTOM.get(tutorial_mechanic, ""))
	if symptom == "":
		for p in SINGLE_PROBLEMS:
			if p.fail == part_type:
				symptom = p.symptom
				break
	if symptom == "":
		symptom = "%s dañada: hay que reemplazarla." % PART_TITLES.get(part_type, part_type)
	return {
		"id": _task_counter,
		"symptom": symptom,
		"fail": part_type,
		"fail2": "",
		"part": PART_TITLES.get(part_type, part_type),
		"part2": "",
		"variant": random_variant(part_type).name,
		"variant2": "",
		"fault": fault,
		"fix": fix,
		"fault2": "",
		"fix2": "",
	}

func part_info_text(part_type: String) -> String:
	var info: Dictionary = PART_INFO.get(part_type, {})
	var title: String = PART_TITLES.get(part_type, part_type)
	return "[b]%s[/b]\n\n[color=#7fd4ff][b]PARA QUÉ SIRVE[/b][/color]\n%s\n\n[color=#ffb0b0][b]SI FALLA[/b][/color]\n%s" % [
		title.to_upper(),
		info.get("use", ""),
		info.get("fails", ""),
	]

func finish_tutorial() -> void:
	tutorial_mode = false
	state = State.MENU
	_apply_mouse_mode()
	tutorial_exited.emit()

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
	if tutorial_mode:
		# En tutorial no se anota nada: la PC queda disponible para repetir.
		task_completed.emit(pc_id)
		tutorial_finished.emit()
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
	var singles: Array = _level_singles()
	var doubles: Array = _level_doubles()
	var p: Dictionary
	if randf() < 0.3 and doubles.size() > 0:
		p = doubles[randi() % doubles.size()]
	else:
		p = singles[randi() % singles.size()]
	_task_counter += 1
	var v1: Dictionary = random_variant(p.fail)
	var v2: Dictionary = {}
	if p.get("fail2", "") != "":
		v2 = random_variant(p.fail2)
	var fault := fault_for(p.fail)
	return {
		"id": _task_counter,
		"symptom": p.symptom,
		"fail": p.fail,
		"fail2": p.get("fail2", ""),
		"part": p.part,
		"part2": p.get("part2", ""),
		"variant": v1.name,
		"variant2": v2.get("name", ""),
		"fault": fault,
		"fix": fix_for(fault),
		"fault2": fault_for(p.fail2) if p.get("fail2", "") != "" else "",
		"fix2": "",
	}

func _build_tasks() -> void:
	current_tasks.clear()
	var singles: Array = _level_singles()
	var doubles: Array = _level_doubles()
	if singles.is_empty():
		singles = SINGLE_PROBLEMS.duplicate()
	singles.shuffle()
	doubles.shuffle()
	var pool: Array = []
	if doubles.size() > 0:
		pool.append(doubles.pop_front())
	var need := pc_count - pool.size()
	while need > 0 and doubles.size() > 0:
		pool.append(doubles.pop_front())
		need -= 1
	while need > 0 and singles.size() > 0:
		pool.append(singles.pop_front())
		need -= 1
	# Sobran PCs y ya no quedan problemas únicos del nivel: se repiten
	# (o se recurre a la lista completa) en vez de romper la generación.
	var refill: Array = singles
	if refill.is_empty():
		refill = _level_singles()
	if refill.is_empty():
		refill = SINGLE_PROBLEMS
	while need > 0 and refill.size() > 0:
		pool.append(refill[randi() % refill.size()])
		need -= 1
	pool.shuffle()
	for i in pc_count:
		var p: Dictionary = pool[i]
		var v1: Dictionary = random_variant(p.fail)
		var v2: Dictionary = {}
		if p.get("fail2", "") != "":
			v2 = random_variant(p.fail2)
		var fault := fault_for(p.fail)
		var fault2 := fault_for(p.fail2) if p.get("fail2", "") != "" else ""
		current_tasks.append({
			"id": i + 1,
			"symptom": p.symptom,
			"fail": p.fail,
			"fail2": p.get("fail2", ""),
			"part": p.part,
			"part2": p.get("part2", ""),
			"variant": v1.name,
			"variant2": v2.get("name", ""),
			"fault": fault,
			"fix": fix_for(fault),
			"fault2": fault2,
			"fix2": fix_for(fault2) if fault2 != "" else "",
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