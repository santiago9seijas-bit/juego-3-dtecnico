class_name OsInstallMinigame
extends VBoxContainer

# PC SIN SISTEMA OPERATIVO: hay que instalar uno desde el pendrive.
# Delega todo el flujo (SO, idioma, animación y cartel final) en OsFlow.

signal finished

var state: Dictionary = {}
var flow: OsFlow
var items: Array = []

func setup(new_state: Dictionary, task: Dictionary) -> void:
	state = new_state if new_state != null else {}
	items = SwUI.str_array(task.get("items", []))
	if items.is_empty():
		items = ["so_windows", "so_mac", "so_linux"]
	add_theme_constant_override("separation", 8)
	add_child(SwUI.rich(
		"[color=#7ef9ff][b]Esta PC no arranca[/b][/color]: no tiene sistema operativo. " +
		"Instálale uno que ya esté en el pendrive."))
	flow = OsFlow.new()
	add_child(flow)
	flow.setup(state, items)
	flow.installed.connect(func() -> void: finished.emit())

func _process(delta: float) -> void:
	if flow:
		flow.tick(delta)
