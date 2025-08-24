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

func make_rigid_body(scene: Node, node: Node):
	var object = preload("res://core/track/track_object.tscn").instantiate()
	scene.add_child(object)
	object.owner = scene
	object.name = "RigidBody3D"
	object.transform = node.transform
	object.collision_layer = Constants.collision_layer_to_mask([Constants.CollisionLayer.OBJECTS])
	object.collision_mask = Constants.collision_layer_to_mask([Constants.CollisionLayer.TRACK_ROAD, Constants.CollisionLayer.TRACK_WALLS, Constants.CollisionLayer.TRACK_CEILING, Constants.CollisionLayer.RACERS, Constants.CollisionLayer.TRAFFIC, Constants.CollisionLayer.POLICE, Constants.CollisionLayer.OBJECTS])
	var attrs = node.get_meta("extras")["SPT_object"]
	object.mass = attrs["mass"]
	var dimension = Vector3(
		attrs["dimensions"][0],
		attrs["dimensions"][1],
		attrs["dimensions"][2],
	)
	var collider = CollisionShape3D.new()
	object.add_child(collider)
	collider.owner = scene
	collider.name = "CollisionShape3D"
	var shape = BoxShape3D.new()
	shape.size = dimension
	collider.shape = shape
	node.transform = Transform3D()
	node.owner = null
	node.get_parent().remove_child(node)
	object.add_child(node)
	node.owner = scene

func make_rigid_bodies(scene: Node):
	var objects = scene.get_children().filter(func(x): return x.get_meta("extras", {}).has("SPT_object"))
	for object in objects:
		self.make_rigid_body(scene, object)

func _post_import(scene):
	if scene.get_meta("type") == "track":
		var new_scene = RaceTrack.new()
		new_scene.name = scene.name
		scene.replace_by(new_scene)
		self.make_rigid_bodies(new_scene)
		for child in new_scene.get_children():
			self.set_wall_collision(child)
		var animation_player = new_scene.find_child("AnimationPlayer") as AnimationPlayer
		if animation_player:
			var animation_library = animation_player.get_animation_library(&"")
			for animation_name in animation_library.get_animation_list():
				var object = animation_name.rstrip("-action-Action_DEFAULT")
				var animation = animation_library.get_animation(animation_name)
				for track in [Animation.TrackType.TYPE_POSITION_3D, Animation.TrackType.TYPE_ROTATION_3D]:
					var idx = animation.find_track(object, track)
					if idx != -1:
						animation.track_set_path(idx, ".")
				var player = AnimationPlayer.new()
				player.root_node = "../" + object
				player.add_animation_library(&"", animation_library)
				player.set_meta(&"action", animation_name)
				var object_node = new_scene.find_child(object)
				new_scene.add_child(player)
				player.owner = new_scene
			animation_player.queue_free()
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
		for node in new_scene.get_children():
			if node is VisualInstance3D:
				node.layers = Constants.visual_layer_to_mask([Constants.VisualLayer.PLAYER])
			self.make_wheel(node)
		scene = new_scene
	return scene
