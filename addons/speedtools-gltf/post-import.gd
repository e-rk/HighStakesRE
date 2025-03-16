@tool
extends EditorScenePostImport


func make_wheel(node: Node):
	if not node.name.contains("_whl"):
		return
	var wheel_mesh = node as MeshInstance3D
	var wheel = CarWheel.new()
	wheel.mesh = wheel_mesh.mesh
	wheel.name = wheel_mesh.name
	wheel.layers = Constants.visual_layer_to_mask([Constants.VisualLayer.PLAYER])
	wheel_mesh.replace_by(wheel)
	wheel.transform = wheel_mesh.transform
	if wheel_mesh.name.contains("front"):
		wheel.is_front = true
	wheel_mesh.free()

func set_wall_collision(node: Node):
	if node is StaticBody3D and node.name.contains("not_driveable"):
		node.collision_layer = Constants.collision_layer_to_mask([Constants.CollisionLayer.TRACK_WALLS])
		node.collision_mask = Constants.collision_layer_to_mask([Constants.CollisionLayer.TRACK_WALLS])

func _post_import(scene):
	if scene.get_meta("type") == "track":
		var new_scene = RaceTrack.new()
		new_scene.name = scene.name
		scene.replace_by(new_scene)
		for child in new_scene.get_children():
			self.set_wall_collision(child)
		return new_scene
	elif scene.get_meta("type") == "car":
		var dimensions = scene.get_meta("dimensions")
		var new_scene: Node = load("res://core/car/car.tscn").instantiate()
		var shadow = new_scene.get_child(0)
		var collider = new_scene.get_child(2)
		shadow.size = Vector3(dimensions.x, 1.5, dimensions.z) * 1.15
		collider.shape.size = dimensions
		new_scene.name = scene.name
		scene.replace_by(new_scene)
		var performance = CarPerformance.new()
		performance.data = scene.get_meta("performance")
		new_scene.mass = performance.mass()
		new_scene.performance = performance
		new_scene.collision_layer = Constants.collision_layer_to_mask([Constants.CollisionLayer.RACERS])
		new_scene.collision_mask = Constants.collision_layer_to_mask([Constants.CollisionLayer.RACERS, Constants.CollisionLayer.TRACK_WALLS])
		new_scene.continuous_cd = true
		new_scene.physics_material_override = load("res://core/resources/car-physics-material.tres")
		for node in new_scene.get_children():
			if node is VisualInstance3D:
				node.layers = Constants.visual_layer_to_mask([Constants.VisualLayer.PLAYER])
			self.make_wheel(node)
		scene = new_scene
	return scene
