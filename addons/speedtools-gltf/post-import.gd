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

func make_meter(node: Node) -> CarMeter:
	var meter_mesh = node as MeshInstance3D
	var regex = RegEx.create_from_string(".*\\((0_\\d+) to (0_\\d+)\\).*")
	var search = regex.search(meter_mesh.name)
	var start = float(search.get_string(1).replace("_", "."))
	var stop = float(search.get_string(2).replace("_", "."))
	var meter = CarMeter.new()
	meter.start = start
	meter.stop = stop
	meter.name = meter_mesh.name
	meter.mesh = meter_mesh.mesh
	meter_mesh.replace_by(meter)
	meter.transform = meter_mesh.transform
	meter.set_meta(&"extras", meter_mesh.get_meta(&"extras"))
	meter_mesh.free()
	return meter

func set_colliders(node: Node):
	if node is StaticBody3D:
		if node.name.contains("not_driveable"):
			node.collision_layer = Constants.collision_layer_to_mask([Constants.CollisionLayer.TRACK_WALLS])
			node.collision_mask = Constants.collision_layer_to_mask([Constants.CollisionLayer.TRACK_WALLS])
		for child in node.get_children():
			child.shape.backface_collision = true

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

func build_road_mesh(shape: ConcavePolygonShape3D) -> MeshInstance3D:
	var faces := shape.get_faces()
	if faces.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	var mesh = preload("res://core/resources/minimap_mesh.tscn").instantiate()
	mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func make_minimap_mesh(scene: Node):
	var track_collision = Constants.collision_layer_to_mask([Constants.CollisionLayer.TRACK_ROAD])
	var objects: Array[StaticBody3D]
	objects.assign(scene.get_children().filter(func(x): return x.name.contains("Collision") and x is StaticBody3D and x.collision_layer == track_collision))
	var mesh_container := Node3D.new()
	mesh_container.name = "MinimapMeshes"
	scene.add_child(mesh_container)
	mesh_container.owner = scene
	mesh_container.set_display_folded(true)
	for object in objects:
		var shape: CollisionShape3D = object.find_child("CollisionShape3D")
		var mesh = self.build_road_mesh(shape.shape)
		mesh_container.add_child(mesh, true)
		mesh.owner = scene

func double_sided_shadows(scene: Node):
	for child in scene.get_children():
		if child is MeshInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED

func apply_car_material(root: Node):
	pass
	var car_material = load("res://core/resources/materials/car_material.tres")
	var materials = []
	var matset = {}
	var meshes = []
	for child in root.get_children():
		if child is MeshInstance3D:
			meshes.append(child.mesh)

	for mesh in meshes:
		for surf in mesh.get_surface_count():
			matset[mesh.surface_get_material(surf)] = null
	for k in matset:
		materials.append(k)
	var mapping = {}
	for i in len(materials):
		var material = materials[i]
		if material is StandardMaterial3D and not material.refraction_enabled:
			var mat = car_material.duplicate()
			mapping[material] = mat
			mat.set_shader_parameter("texture_albedo", material.albedo_texture)
			mat.set_shader_parameter("roughness", material.roughness)
			mat.set_shader_parameter("texture_metallic", material.metallic_texture)
			mat.set_shader_parameter("texture_roughness", material.roughness_texture)
			mat.set_shader_parameter("metallic_texture_channel", material.metallic_texture_channel)
			mat.set_shader_parameter("uv1_scale", material.uv1_scale)
			mat.set_shader_parameter("uv1_offset", material.uv1_offset)
			mat.set_shader_parameter("uv2_scale", material.uv2_scale)
			mat.set_shader_parameter("uv1_offset", material.uv1_offset)
			mat.set_shader_parameter("specular", material.metallic_specular)
			mat.set_shader_parameter("metallic", material.metallic)
		else:
			mapping[material] = material
	for mesh in meshes:
		for surf in mesh.get_surface_count():
			mesh.surface_set_material(surf, mapping[mesh.surface_get_material(surf)])


func _set_materials_local_to_scene(car: Car):
	for child in car.get_children():
		if child is MeshInstance3D:
			for i in range(child.mesh.get_surface_count()):
				var surface = child.mesh.surface_get_material(i) as StandardMaterial3D
				surface.resource_local_to_scene = true


func _process_car_texture(car: Car):
	var image_to_parts = {}
	for child in car.get_children():
		if child is MeshInstance3D:
			for i in range(child.mesh.get_surface_count()):
				var surface = child.mesh.surface_get_material(i) as StandardMaterial3D
				if surface.refraction_enabled:
					continue
				var surf_image = surface.albedo_texture.get_image() as Image
				var prev = image_to_parts.get(surf_image, [])
				prev.append(child)
				image_to_parts[surf_image] = prev
				break
	var car_textures: Array[CarTexture] = []
	for image in image_to_parts:
		var car_texture = CarTexture.create_from_base_image(image)
		car_textures.append(car_texture)
		for part in image_to_parts[image]:
			var surfaces = part.mesh.get_surface_count()
			for i in range(surfaces):
				var material = part.mesh.surface_get_material(i) as StandardMaterial3D
				if not material.refraction_enabled:
					material.albedo_texture = car_texture
	car.car_textures = car_textures


func _make_performance(data: Dictionary) -> CarPerformance:
	var performance = CarPerformance.new()
	performance.mass = data["mass"]
	performance.torque_curve.assign(data["torque_curve"])
	performance.manual_gear_efficiency = data["manual_gear_efficiency"]
	performance.manual_velocity_to_rpm_ratio = data["manual_velocity_to_rpm_ratio"]
	performance.manual_number_of_gears = data["manual_number_of_gears"]
	performance.front_drive_ratio = data["front_drive_ratio"]
	performance.engine_redline_rpm = data["engine_redline_rpm"]
	performance.engine_minimum_rpm = data["engine_minimum_rpm"]
	performance.aerodynamic_downforce_multiplier = data["aerodynamic_downforce_multiplier"]
	performance.maximum_velocity = data["maximum_velocity"]
	performance.spoiler_function_type = data["spoiler_function_type"]
	performance.turn_in_ramp = data["turn_in_ramp"]
	performance.turn_out_ramp = data["turn_out_ramp"]
	performance.minimum_steering_acceleration = data["minimum_steering_acceleration"]
	performance.maximum_braking_deceleration = data["maximum_braking_deceleration"]
	performance.front_bias_brake_ratio = data["front_bias_brake_ratio"]
	performance.lateral_acceleration_grip_multiplier = data["lateral_acceleration_grip_multiplier"]
	performance.front_grip_bias = data["front_grip_bias"]
	performance.has_abs = data["has_abs"]
	performance.understeer_gradient = data["understeer_gradient"]
	performance.turning_circle_radius = data["turning_circle_radius"]
	performance.gas_off_factor = data["gas_off_factor"]
	performance.shift_blip_in_rpm.assign(data["shift_blip_in_rpm"])
	performance.brake_blip_in_rpm.assign(data["brake_blip_in_rpm"])
	performance.gear_shift_delay = data["gear_shift_delay"]
	performance.g_transfer_factor = data["g_transfer_factor"]
	performance.brake_decreasing_curve.assign(data["brake_decreasing_curve"])
	performance.brake_increasing_curve.assign(data["brake_increasing_curve"])
	return performance


func add_glares(node: Node, root: Node):
	if node is SpotLight3D:
		self.add_directional_glare(node, root)
	for child in node.get_children():
		add_glares(child, root)


func add_directional_glare(light: SpotLight3D, root: Node):
	var glare := preload("res://core/resources/directional_glare.tscn").instantiate()
	glare.color = light.light_color
	glare.size = pow(light.light_energy, 1.0/4.0)
	light.add_child(glare)
	glare.owner = root


func _post_import(scene):
	if scene.get_meta("type") == "track":
		var new_scene = RaceTrack.new()
		new_scene.name = scene.name
		scene.replace_by(new_scene)
		self.make_rigid_bodies(new_scene)
		self.double_sided_shadows(new_scene)
		for child in new_scene.get_children():
			self.set_colliders(child)
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
			animation_player.free()
		make_minimap_mesh(new_scene)
		return new_scene
	elif scene.get_meta("type") == "car":
		var dimensions = scene.get_meta("dimensions")
		var colors: Array[CarColorSet] = scene.get_meta("color_set")
		var new_scene: Node = load("res://core/car/car.tscn").instantiate()
		var shadow = new_scene.get_child(0)
		var collider = new_scene.get_child(2)
		shadow.size = Vector3(dimensions.x, 1.5, dimensions.z) * 1.15
		collider.shape.size = dimensions
		new_scene.palette = colors
		new_scene.name = scene.name
		scene.replace_by(new_scene)
		var performance = self._make_performance(scene.get_meta("performance"))
		new_scene.mass = performance.mass
		new_scene.performance = performance
		for node in new_scene.get_children():
			if node is GeometryInstance3D:
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				var extras = node.get_meta("extras", {})
				if extras.get("SPT_interior", false):
					node.layers = Constants.visual_layer_to_mask([Constants.VisualLayer.PLAYER_INTERIOR])
				else:
					node.layers = Constants.visual_layer_to_mask([Constants.VisualLayer.PLAYER])
			if node is Camera3D:
				node.cull_mask = Constants.visual_layer_to_mask([Constants.VisualLayer.PLAYER_INTERIOR, Constants.VisualLayer.TRACK, Constants.VisualLayer.OPPONENTS])
				node.fov = 60
			if node is MeshInstance3D:
				node.mesh.resource_local_to_scene = true
			if node.name.contains("_whl"):
				self.make_wheel(node)
			elif node.name.contains("_RPM"):
				node = self.make_meter(node)
				node.name = "tachometer"
			elif node.name.contains("_MPH"):
				node = self.make_meter(node)
				node.name = "speedometer"
		scene.free()
		scene = new_scene
		if colors:
			scene.color = colors[0]
		self._process_car_texture(scene)
		self._set_materials_local_to_scene(scene)

		var interior_dashboard = scene.find_child("interior_dashboard_lit")
		if interior_dashboard is MeshInstance3D:
			interior_dashboard.position += -0.001 * Vector3.MODEL_FRONT
			var material = interior_dashboard.mesh.surface_get_material(0) as StandardMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var dashbaord = scene.find_child("dashboard_lit")
		if dashbaord is MeshInstance3D:
			dashbaord.position += -0.001 * Vector3.MODEL_FRONT
		add_glares(scene, scene)
	return scene
