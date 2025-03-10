@tool
extends GLTFDocumentExtension

func create_waypoints(waypoints: Array):
	var node = Waypoints.new()
	node.name = "Waypoints"
	var curve = Curve3D.new()
	curve.up_vector_enabled = false
	for waypoint in waypoints:
		var v = Vector3(waypoint[0], waypoint[1], waypoint[2])
		curve.add_point(v)
	node.waypoints = curve
	return node

func scale_light_energy(node: Node):
	if node is Light3D:
		node.light_energy /= 6830
	if node is DirectionalLight3D:
		node.shadow_reverse_cull_face = true
		node.shadow_enabled = true
		node.shadow_blur = 5.0
	for child in node.get_children():
		scale_light_energy(child)
	return OK

func dict_to_color(value: Dictionary) -> Color:
	return Color(value["red"], value["green"], value["blue"])
	
func dict_hsl_to_color(value: Dictionary) -> Color:
	return Color.from_hsv(value["hue"] / 255.0, value["saturation"] / 255.0, value["value"] / 255.0)

func dict_to_palette(value: Dictionary) -> CarColorSet:
	var color_set = CarColorSet.from_colors(
		self.dict_hsl_to_color(value["primary"]),
		self.dict_hsl_to_color(value["secondary"]),
		self.dict_hsl_to_color(value["driver"]),
		self.dict_hsl_to_color(value["interior"])
	)
	return color_set

func _make_skybox(state: GLTFState) -> Cubemap:
	var images = state.get_images()
	var json_images = state.json["images"]
	for i in len(json_images):
		if json_images[i].name == "horizon":
			var image = images[i].get_image()
			var cubemap = Cubemap.new()
			var empty = Image.create_empty(image.get_width(), image.get_height(), true, image.get_format())
			cubemap.create_from_images([image, image, empty, empty, image, image])
			return cubemap
	return null

func find_gltf_node(state: GLTFState, name: String) -> Dictionary:
	var json = state.json
	var nodes = json["nodes"]
	for node in nodes:
		if node["name"] == name:
			return node
	return {}

func create_environment(state: GLTFState, environment: Dictionary):
	var worldenv = load("res://core/resources/environment/environment.tscn").instantiate()
	var ambient = environment["ambient"]
	var horizon = environment["horizon"]
	var color = dict_to_color(ambient)
	var sun = self.find_gltf_node(state, "sun")
	worldenv.environment.ambient_light_color = color
	worldenv.environment.sky.sky_material.set_shader_parameter("ambient_color", color)
	worldenv.environment.sky.sky_material.set_shader_parameter("sun_side_color", dict_to_color(horizon["sun_side"]))
	worldenv.environment.sky.sky_material.set_shader_parameter("top_side_color", dict_to_color(horizon["sun_top"]))
	worldenv.environment.sky.sky_material.set_shader_parameter("opposite_side_color", dict_to_color(horizon["sun_opposite"]))
	worldenv.environment.sky.sky_material.set_shader_parameter("earth_bottom", dict_to_color(horizon["earth_bottom"]))
	worldenv.environment.sky.sky_material.set_shader_parameter("earth_top", dict_to_color(horizon["earth_top"]))
	worldenv.environment.sky.sky_material.set_shader_parameter("background_texture", self._make_skybox(state))
	worldenv.environment.sky.sky_material.set_shader_parameter("sun_texture", self.get_image_by_name(state, "sun"))
	worldenv.environment.sky.sky_material.set_shader_parameter("sky_texture", self.get_image_by_name(state, "clouds"))
	if sun.has("extras") and sun["extras"].has("SPT_sun"):
		var spt_sun = sun["extras"]["SPT_sun"]
		worldenv.environment.sky.sky_material.set_shader_parameter("sun_additive", spt_sun["additive"])
		worldenv.environment.sky.sky_material.set_shader_parameter("sun_radius", spt_sun["radius"] / 4000.0)
	return worldenv

func finalize_materials(json: Dictionary, materials: Array[Material]):
	var json_materials = json["materials"]
	for i in len(materials):
		var json_material = json_materials[i]
		var material = materials[i]
		if material is BaseMaterial3D:
			material.vertex_color_is_srgb = true
		if json_material.has("extensions"):
			var ext = json_material["extensions"]
			if ext.has("KHR_materials_specular"):
				material.metallic_specular = ext["KHR_materials_specular"]["specularFactor"]
		if json_material.has("extras"):
			var extras = json_material["extras"]
			var is_additive = false
			var is_transparent = false
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if extras.has("SPT_additive"):
				is_additive = extras["SPT_additive"]
			if extras["SPT_billboard"] and material is BaseMaterial3D:
				material.billboard_mode = BaseMaterial3D.BillboardMode.BILLBOARD_FIXED_Y
				if material.cull_mode != BaseMaterial3D.CullMode.CULL_DISABLED:
					material.cull_mode = BaseMaterial3D.CullMode.CULL_FRONT
			if is_additive and material is BaseMaterial3D:
				material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			if extras.has("SPT_transparent"):
				is_transparent = extras["SPT_transparent"]
			if is_transparent and material is BaseMaterial3D:
				material.refraction_enabled = true
				material.refraction_scale = 0.0
				material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
	return OK

func finalize_static_bodies(state: GLTFState, node: Node):
	var nodes = state.json["nodes"]
	for i in range(0, len(nodes)):
		var json_node = nodes[i]
		var checked_node = node.get_child(i, false)
		if !json_node.has("extras"):
			continue
		var extras = json_node["extras"]
		if not extras.has("SPT_surface_type"):
			continue
		var surface_type = extras["SPT_surface_type"]
		checked_node.set_meta("surface_type", surface_type)
	return OK


func _load_stream(sample: Dictionary) -> EngineSample:
	var params = {
		#"edit/loop_mode": 2,
		#"edit/loop_end": -1,
		#"edit/loop_begin": 0,
		#"compress/mode": 0,
		#"force/max_rate_hz": 22050
	}
	var decoded = Marshalls.base64_to_raw(sample["sample"])
	var wav = AudioStreamWAV.load_from_buffer(decoded, params)
	var result = EngineSample.new()
	result.sample = wav
	result.rear = sample["is_rear"]
	for table in sample["tables"]:
		result.volume_tables.append(table["volume"])
		result.pitch_tables.append(table["pitch"])
		result.is_load_table.append(table["type"] == "load")
	return result


func process_car_extras(root: Node, data: Dictionary):
	var dimensions = data["dimensions"]
	var color_set: Array[CarColorSet]
	color_set.assign(data["colors"].map(self.dict_to_palette))
	
	root.set_meta("dimensions", Vector3(dimensions[0], dimensions[1], dimensions[2]))
	root.set_meta("performance", data["performance"])
	root.set_meta("type", "car")
	root.set_meta("color_set", color_set)
	var engine_audio = EngineAudio.new()
	var i = 0
	for sample in data["engine_samples"]:
		engine_audio.samples.append(self._load_stream(sample))
		#if i == 0:
			#engine_audio.samples[-1].sample = load("res://import/audio/front_out_0x24.wav")
		#if i == 1:
			#engine_audio.samples[-1].sample = load("res://import/audio/front_out_0x25.wav")
		#if i == 2:
			#engine_audio.samples[-1].sample = load("res://import/audio/front_out_0x26.wav")
		#if i == 3:
			#engine_audio.samples[-1].sample = load("res://import/audio/front_out_0x27.wav")
		#if i == 4:
			#engine_audio.samples[-1].sample = load("res://import/audio/front_out_0x28.wav")
		#engine_audio.samples[-1].sample.loop_mode = 1
		i += 1
	var emitter = preload("res://core/car/car_engine_audio.tscn").instantiate()
	emitter.stream = engine_audio
	root.add_child(emitter)
	emitter.owner = root

func get_image_by_name(state: GLTFState, name: String) -> CompressedTexture2D:
	var images = state.get_images()
	var json_images = state.json["images"]
	for i in len(images):
		if json_images[i]["name"] == name:
			return images[i]
	return null


func _load_track_streams(root: Node, sample: Dictionary):
	var position = sample["location"]
	var params = {}
	for data in sample["samples"]:
		var player = AudioStreamPlayer3D.new()
		root.add_child(player, true)
		player.owner = root
		player.position = Vector3(position[0], position[1], position[2])
		var decoded = Marshalls.base64_to_raw(data).decompress(10000000, FileAccess.COMPRESSION_GZIP)
		var wav = AudioStreamWAV.load_from_buffer(decoded, params)
		player.stream = wav
		player.autoplay = true
		player.attenuation_filter_cutoff_hz = 20500
		player.max_distance = 500
		player.max_db = 0

func _make_sources(root: Node, data: Dictionary):
	if data.has("audio_sources"):
		for source in data["audio_sources"]:
			self._load_track_streams(root, source)

func process_track_extras(state: GLTFState, root: Node, data: Dictionary):
	var node = self.create_environment(state, data["environment"])
	root.add_child(node)
	node.owner = root
	node = self.create_waypoints(data["waypoints"])
	root.add_child(node, true)
	node.owner = root
	root.set_meta("type", "track")
	var json_materials = state.json["materials"]
	var json_images = state.json["images"]
	var json_textures = state.json["textures"]
	var images = state.get_images()
	self._make_sources(root, data)

	for i in len(json_materials):
		var material = json_materials[i]
		if not material.has("extras"):
			continue
		if material["extras"].has("SPT_animation_images"):
			var image_idx = material["pbrMetallicRoughness"]["baseColorTexture"]["index"]
			var tex = json_textures[image_idx]
			var tex_source = tex["source"]
			var array_images = []
			for name in material["extras"]["SPT_animation_images"]:
				var img = self.get_image_by_name(state, name)
				array_images.append(img.get_image())
			var texture_array = Texture2DArray.new()
			texture_array.create_from_images(array_images)
			var mat = ShaderMaterial.new()
			if material["extras"].has("SPT_additive"):
				mat.shader = load("res://core/resources/shader/animated_texture_add.gdshader")
				mat.render_priority += 1
			else:
				mat.shader = load("res://core/resources/shader/animated_texture_blend.gdshader")
			var ticks = int(material["extras"]["SPT_animation_ticks"])
			mat.set_shader_parameter("layers", texture_array)
			mat.set_shader_parameter("ticks", ticks)
			for child_node in root.get_children():
				if child_node is ImporterMeshInstance3D:
					for surface_id in child_node.mesh.get_surface_count():
						if child_node.mesh.get_surface_material(surface_id) == state.get_materials()[i]:
							child_node.mesh.set_surface_material(surface_id, mat)

func process_scene_extras(state: GLTFState, root: Node):
	var main_scene_idx = state.json["scene"]
	var scene = state.json["scenes"][main_scene_idx]
	if !scene.has("extras"):
		return null
	var extras = scene["extras"]
	if extras.has("SPT_car"):
		process_car_extras(root, extras["SPT_car"])
	if extras.has("SPT_track"):
		process_track_extras(state, root, extras["SPT_track"])

func _import_post(state: GLTFState, root: Node):
	var err
	err = scale_light_energy(root)
	if err != OK:
		return err
	err = finalize_materials(state.json, state.materials)
	if err != OK:
		return err
	process_scene_extras(state, root)
	return OK
