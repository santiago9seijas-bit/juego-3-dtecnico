class_name TrashBin
extends Interactable

# Papelera: aquí se botan las piezas dañadas que salen de las computadoras.
# Se construye entera por código (malla, colisión, luz de resalte y rótulo).

var _highlight: MeshInstance3D

func _ready() -> void:
	prompt_text = "Botar la pieza dañada"

	var body := CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(0.8, 1.2, 0.8)
	body.shape = body_shape
	body.position = Vector3(0, 0.6, 0)
	add_child(body)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 1.1, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.26)
	mat.metallic = 0.6
	mat.roughness = 0.35
	box.material = mat
	mesh.mesh = box
	mesh.position = Vector3(0, 0.55, 0)
	add_child(mesh)

	_highlight = MeshInstance3D.new()
	var hi := BoxMesh.new()
	hi.size = Vector3(0.85, 1.2, 0.85)
	var hi_mat := StandardMaterial3D.new()
	hi_mat.albedo_color = Color(0.4, 1, 0.5, 0.3)
	hi_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hi.material = hi_mat
	_highlight.mesh = hi
	_highlight.position = Vector3(0, 0.6, 0)
	_highlight.visible = false
	add_child(_highlight)

	var label := Label3D.new()
	label.name = "Label"
	label.text = "PAPELERA"
	label.font_size = 48
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.5, 0)
	add_child(label)

	super._ready()

func interact(_player: Node3D) -> void:
	super.interact(_player)
	if Game.hud:
		Game.hud.throw_damaged()

func set_highlighted(on: bool) -> void:
	if _highlight:
		_highlight.visible = on
