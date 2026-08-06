extends CharacterBody3D

const SPEED := 6.5
const JUMP_VELOCITY := 4.5
const MOUSE_SENS := 0.003

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay

var current_interactable: Node3D = null

func _unhandled_input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING or Game.tutorial_active:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)
	elif event.is_action_pressed("interact"):
		_try_interact()

func _physics_process(delta: float) -> void:
	var frozen := Game.state != Game.State.PLAYING or Game.is_minigame_open
	if frozen or Game.tutorial_active:
		if not is_on_floor():
			velocity.y -= gravity * delta
			move_and_slide()
		if frozen:
			return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_back"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()

	_update_interactable()

func _update_interactable() -> void:
	var target := _raycast_interactable()
	if target == current_interactable:
		return
	if current_interactable and current_interactable is Interactable:
		current_interactable.set_highlighted(false)
	current_interactable = target
	if target and target is Interactable:
		target.set_highlighted(true)
	Game.hud.set_prompt(target)

func _raycast_interactable() -> Node3D:
	if not interact_ray.is_colliding():
		return null
	var collider := interact_ray.get_collider()
	if collider is Interactable:
		return collider as Node3D
	return null

func _try_interact() -> void:
	if Game.is_minigame_open:
		return
	var target := _raycast_interactable()
	if target:
		target.interact(self)
