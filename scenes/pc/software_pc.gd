class_name SoftwarePC
extends Interactable

# Computadora del mundo de software (sección 2): no lleva piezas dentro,
# abre un minijuego de SOFTWARE según su tipo:
#   "download"  → NAVEGADOR para bajar drivers e imágenes de sistema.
#   "drivers"   → instalador de controladores por sección de fabricante.
#   "os_install"→ instalador de sistema operativo (idioma + animación).
#   "virus"     → análisis y cuarentena de archivos infectados.
#   "processes" → ADMINISTRADOR DE TAREAS (procesos maliciosos).
#   "os_swap"   → desinstalar el sistema viejo e instalar otro.
#   "ads"       → desinstalador de programas de anuncios (bloatware).
# Se construye entera por código (monitor, base, luz de resalte, rótulo).

var pc_id := 0
var kind := "download"
var symptom := ""
# La tarea del nivel que resuelve esta PC (items, count, decoy, kind…).
var task: Dictionary = {}
# Progreso de esta PC: se guarda aquí para que cerrar la ventana del
# minijuego no pierda descargas, instalaciones ni archivos en cuarentena.
var state: Dictionary = {}

const KIND_TITLES := {
	"download": "INTERNET",
	"drivers": "DRIVERS",
	"os_install": "SISTEMA",
	"virus": "VIRUS",
	"processes": "PROCESOS",
	"os_swap": "CAMBIAR SO",
	"ads": "ANUNCIOS",
}
const KIND_COLORS := {
	"download": Color(0.1, 0.85, 1.0),
	"drivers": Color(1.0, 0.18, 0.53),
	"os_install": Color(0.1, 0.85, 1.0),
	"virus": Color(1.0, 0.18, 0.53),
	"processes": Color(1.0, 0.69, 0.13),
	"os_swap": Color(0.48, 0.36, 1.0),
	"ads": Color(0.1, 0.85, 1.0),
}

var _highlight: MeshInstance3D
var _screen_mat: StandardMaterial3D
var _label: Label3D
# Tira LED del escritorio: marca la estación y se pone verde al repararla.
var _desk_led_mat: StandardMaterial3D

func _ready() -> void:
	prompt_text = "Reparar PC %d" % pc_id
	_build()
	Game.task_completed.connect(_on_completed)
	super._ready()

func _build() -> void:
	var accent: Color = KIND_COLORS.get(kind, UiStyle.CYAN)

	# El rayo de interacción tiene que dar justo en su caja (como en la
	# PC de hardware): el escritorio mide 1.3 de ancho, el monitor un poco
	# menos, y entre escritorio y escritorio quedan 0.65 de paso.
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 1.0, 0.4)
	var body := CollisionShape3D.new()
	body.shape = shape
	add_child(body)

	# Pantalla (todo en uno) con el color del tipo de problema.
	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(1.0, 0.62, 0.06)
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_color = Color(0.04, 0.07, 0.11)
	_screen_mat.emission_enabled = true
	_screen_mat.emission = accent
	_screen_mat.emission_energy_multiplier = 0.7
	screen_mesh.material = _screen_mat
	screen.mesh = screen_mesh
	screen.position = Vector3(0, 0.14, 0)
	add_child(screen)

	# Cabezal y base sobre el escritorio.
	var neck := MeshInstance3D.new()
	var neck_mesh := BoxMesh.new()
	neck_mesh.size = Vector3(0.12, 0.24, 0.12)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.22, 0.24, 0.3)
	frame_mat.metallic = 0.5
	frame_mat.roughness = 0.4
	neck_mesh.material = frame_mat
	neck.mesh = neck_mesh
	neck.position = Vector3(0, -0.3, 0.02)
	add_child(neck)

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.4, 0.06, 0.22)
	base_mesh.material = frame_mat
	base.mesh = base_mesh
	base.position = Vector3(0, -0.42, 0.02)
	add_child(base)

	# Teclado delante de la pantalla.
	var keyboard := MeshInstance3D.new()
	var key_mesh := BoxMesh.new()
	key_mesh.size = Vector3(0.5, 0.03, 0.18)
	var key_mat := StandardMaterial3D.new()
	key_mat.albedo_color = Color(0.12, 0.13, 0.16)
	key_mesh.material = key_mat
	keyboard.mesh = key_mesh
	keyboard.position = Vector3(0, -0.435, 0.3)
	add_child(keyboard)

	# Luz de resalte al apuntarle con la mira.
	_highlight = MeshInstance3D.new()
	var hi_mesh := BoxMesh.new()
	hi_mesh.size = Vector3(1.16, 1.06, 0.47)
	var hi_mat := StandardMaterial3D.new()
	hi_mat.albedo_color = Color(0.4, 1, 0.5, 0.3)
	hi_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hi_mat.emission_enabled = true
	hi_mat.emission = Color(0.4, 1, 0.5)
	hi_mesh.material = hi_mat
	_highlight.mesh = hi_mesh
	_highlight.visible = false
	add_child(_highlight)

	# Rótulo con el tipo de estación.
	_label = Label3D.new()
	_label.name = "Label"
	_label.text = KIND_TITLES.get(kind, "PC")
	_label.font_size = 46
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = accent
	_label.position = Vector3(0, 0.95, 0)
	add_child(_label)

	# Tira LED en el borde frontal del escritorio: da color a la estación
	# (mismo tono que su pantalla y su rótulo) para leer las siete PCs de un
	# vistazo. Es decorativa: NO tiene colisión, así la mira del jugador
	# sigue llegando sin tropiezos al monitor.
	var led_mesh := BoxMesh.new()
	led_mesh.size = Vector3(1.2, 0.07, 0.04)
	_desk_led_mat = StandardMaterial3D.new()
	_desk_led_mat.albedo_color = Color(accent.r * 0.2, accent.g * 0.2, accent.b * 0.2)
	_desk_led_mat.emission_enabled = true
	_desk_led_mat.emission = accent
	_desk_led_mat.emission_energy_multiplier = 1.6
	led_mesh.material = _desk_led_mat
	var led := MeshInstance3D.new()
	led.name = "DeskLed"
	led.mesh = led_mesh
	led.position = Vector3(0, -0.58, 0.45)
	add_child(led)

# Al resolverse, la pantalla pasa a verde y el rótulo deja de pedir acción.
func _on_completed(pc_id: int) -> void:
	if pc_id != self.pc_id:
		return
	state.clear()
	prompt_text = "PC %d · lista" % pc_id
	if _screen_mat:
		_screen_mat.emission = Color(0.2, 0.95, 0.5)
		_screen_mat.emission_energy_multiplier = 0.5
	if _label:
		_label.modulate = Color(0.35, 1.0, 0.6)
		_label.text = "LISTA"
	# La tira LED del escritorio pasa a VERDE: se ve desde el otro lado de
	# la sala qué PCs quedaron listas.
	if _desk_led_mat:
		_desk_led_mat.emission = Color(0.2, 0.95, 0.5)
		_desk_led_mat.emission_energy_multiplier = 2.2
		_desk_led_mat.albedo_color = Color(0.04, 0.19, 0.1)

func interact(_player: Node3D) -> void:
	super(_player)
	if pc_id in Game.repaired:
		return
	if Game.hud:
		Game.hud.open_software(self)

func set_highlighted(on: bool) -> void:
	if _highlight:
		_highlight.visible = on
