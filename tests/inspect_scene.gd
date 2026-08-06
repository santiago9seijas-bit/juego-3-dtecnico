extends Node

func _ready() -> void:
	var scene: PackedScene = load("res://blender escenarios /escenario.glb")
	var root: Node = scene.instantiate()
	add_child(root)
	var stats := {"static_bodies": 0, "meshes": 0, "collision_shapes": 0}
	_walk(root, 0, stats)
	print("STATS: ", stats)
	get_tree().quit()

func _walk(node: Node, depth: int, stats: Dictionary) -> void:
	var label := node.get_class()
	if node is StaticBody3D:
		stats.static_bodies += 1
		label += " <== StaticBody"
	if node is CollisionShape3D or node is CollisionPolygon3D or node is CollisionObject3D:
		if node is CollisionObject3D:
			stats.static_bodies += 0
		else:
			stats.collision_shapes += 1
		label += " <== colshape"
	if node is MeshInstance3D:
		stats.meshes += 1
	print("%s%s" % ["  ".repeat(depth), label])
	for child in node.get_children():
		_walk(child, depth + 1, stats)