@tool
extends GLTFDocumentExtension

const HORIZON_PARAMETERS = {
	"mirror": "hrz_mirror",
	"radius": "hrz_radius",
	"angle": "hrz_angle",
	"bottom_y": "hrz_bottom_y_off",
	"gouraud_middle": "hrz_gouraud_middle",
	"gouraud_height": "hrz_gouraud_height",
	"panorama_bottom": "hrz_pmx_bottom",
	"panorama_top": "hrz_pmx_top",
}
const CLOUD_PARAMETERS = {
	"nimbus": "cloud_nimbus",
	"fog": "cloud_fog",
	"visual_height": "cloud_visual_height",
	"wind_speed": "cloud_wind_speed",
	"wind_direction": "cloud_wind_direction",
	"y_offset": "cloud_y_offset",
	"height": "cloud_height",
}
const CAR_CLASSES = {
	"AAA": CarDatabase.CarClass.AAA,
	"AA": CarDatabase.CarClass.AA,
	"A": CarDatabase.CarClass.A,
	"B": CarDatabase.CarClass.B,
	"NONE": CarDatabase.CarClass.NONE,
}

func make_vector(data: Array) -> Vector3:
	return Vector3(data[0], data[1], data[2])

func make_basis(data: Dictionary) -> Basis:
	var z = make_vector(data["forward"])
	var y = make_vector(data["normal"])
	var x = make_vector(data["right"])
	return Basis(x, y, z)

func create_waypoints(waypoints: Array, root: Node):
	var node = Waypoints.new()
	node.name = "Waypoints"
	var curve = Curve3D.new()
	var nav_path = NavPath.new()
	var vecs = PackedVector3Array()
	var offsets = PackedFloat32Array()
	var orientations: Array[Basis]
	curve.up_vector_enabled = false
	curve.closed = true
	for waypoint in waypoints:
		var location = waypoint["position"]
		var orientation = waypoint["orientation"]
		var left_wall = waypoint["left_wall"]
		var right_wall = waypoint["right_wall"]
		var v = Vector3(location[0], location[1], location[2])
		var o = make_basis(orientation)
		curve.add_point(v)
		var forward_offset = Vector3(waypoint["forward_offset"], 0, 0)
		vecs.append(v)
		orientations.append(o)
		offsets.append(waypoint["forward_offset"])
	nav_path.points = vecs
	nav_path.orientations = orientations
	nav_path.racing_line_offset = offsets
	for waypoint in waypoints:
		nav_path.left_lane_widths.append(waypoint["left_lane_width"])
		nav_path.right_lane_widths.append(waypoint["right_lane_width"])
		nav_path.left_lane_counts.append(int(waypoint["num_left_lanes"]))
		nav_path.right_lane_counts.append(int(waypoint["num_right_lanes"]))
	node.waypoints = curve
	root.add_child(node, true)
	node.owner = root
	node.add_child(nav_path, true)
	nav_path.owner = root
	nav_path.name = "NavPath"
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

func find_gltf_node(state: GLTFState, name: String) -> Dictionary:
	var json = state.json
	var nodes = json["nodes"]
	for node in nodes:
		if node["name"] == name:
			return node
	return {}

func set_sky_parameters(sky: ShaderMaterial, values: Dictionary, names: Dictionary):
	for key in names:
		sky.set_shader_parameter(names[key], values[key])

func set_panorama(sky: ShaderMaterial, horizon: Dictionary, panorama: Texture2D):
	sky.set_shader_parameter("hrz_has_pmx", panorama != null and horizon.get("has_panorama", true))
	if panorama == null:
		return
	sky.set_shader_parameter("panorama_texture", panorama)
	var size = panorama.get_size()
	if size.x == size.y:
		sky.set_shader_parameter("pmx_atlas_v", Vector2(0.5 - 0.5 / 8.0, 1.0 / 8.0))

func make_cloud_field(bright: int, variance: int, seed_value: int) -> ImageTexture:
	const SIZE = 13
	var random = RandomNumberGenerator.new()
	random.seed = seed_value
	var field = PackedFloat32Array()
	field.resize(SIZE * SIZE)
	for i in len(field):
		var value = bright - (random.randi() % variance if variance > 0 else 0)
		var centered = (value - 128.0) / 128.0
		field[i] = (signf(centered) * sqrt(absf(centered)) + 1.0) * 127.5
	for _pass in 20:
		for z in SIZE:
			for x in SIZE:
				var pull = 0.0
				var count = 0
				for nz in range(max(z - 2, 0), min(z + 3, SIZE)):
					for nx in range(max(x - 2, 0), min(x + 3, SIZE)):
						if nx == x and nz == z:
							continue
						var neighbour = field[nz * SIZE + nx]
						pull += (neighbour - field[z * SIZE + x]) * pow((neighbour - 128.0) / 128.0, 2.0)
						count += 1
				field[z * SIZE + x] = clampf(field[z * SIZE + x] + pull / count * 0.5, 0.0, bright)
	var image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_R8)
	for z in SIZE:
		for x in SIZE:
			image.set_pixel(x, z, Color(field[z * SIZE + x] / 255.0, 0.0, 0.0))
	return ImageTexture.create_from_image(image)

func create_environment(state: GLTFState, environment: Dictionary):
	var worldenv = load("res://core/resources/environment/environment.tscn").instantiate()
	var ambient = environment["ambient"]
	var horizon = environment["horizon"]
	var sun = self.find_gltf_node(state, "sun")
	var sky: ShaderMaterial = worldenv.environment.sky.sky_material
	worldenv.environment.ambient_light_color = dict_to_color(ambient)
	sky.set_shader_parameter("sun_side_color", dict_to_color(horizon["sun_side"]))
	sky.set_shader_parameter("top_side_color", dict_to_color(horizon["sun_top"]))
	sky.set_shader_parameter("opposite_side_color", dict_to_color(horizon["sun_opposite"]))
	sky.set_shader_parameter("earth_bottom", dict_to_color(horizon["earth_bottom"]))
	sky.set_shader_parameter("earth_top", dict_to_color(horizon["earth_top"]))
	set_sky_parameters(sky, horizon, HORIZON_PARAMETERS)
	set_panorama(sky, horizon, self.get_image_by_name(state, "horizon"))
	sky.set_shader_parameter("sun_texture", self.get_image_by_name(state, "sun"))
	sky.set_shader_parameter("sky_texture", self.get_image_by_name(state, "clouds"))
	var clouds: Dictionary = environment.get("clouds", {})
	set_sky_parameters(sky, clouds, CLOUD_PARAMETERS)
	if clouds.has("type"):
		sky.set_shader_parameter("cloud_type", int(clouds["type"]))
		sky.set_shader_parameter("cloud_uv_scale", Vector2(clouds["u_scale"], clouds["v_scale"]))
	var cloud_field = make_cloud_field(int(clouds.get("bright", 235)), int(clouds.get("variance", 208)), hash(state.filename))
	sky.set_shader_parameter("cloud_field_texture", cloud_field)
	if environment.has("lightning"):
		var lightning: Dictionary = environment["lightning"]
		sky.set_shader_parameter("lightning_chance", int(lightning["chance"]))
		sky.set_shader_parameter("lightning_off_ticks", int(lightning["off_ticks"]))
	if environment.has("fog"):
		var fog: Dictionary = environment["fog"]
		sky.set_shader_parameter("fog_color", dict_to_color(fog["color"]))
		var clear = (100.0 - clampf(fog["density"], 0.0, 99.0)) * (1.0 - fog["horizon"])
		sky.set_shader_parameter("horizon_haze", clampf(20.0 / maxf(clear, 0.001), 0.0, 1.0))
	if sun.has("extras") and sun["extras"].has("SPT_sun"):
		var spt_sun = sun["extras"]["SPT_sun"]
		sky.set_shader_parameter("sun_additive", spt_sun["additive"])
		sky.set_shader_parameter("sun_in_front", spt_sun["is_front"])
		sky.set_shader_parameter("sun_world_radius", spt_sun["radius"])
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


func _load_stream(entry: Dictionary) -> Array[EngineSample]:
	var params: Dictionary = {}
	var tables: Array[EngineSampleTable] = []
	for table: Dictionary in entry["tables"]:
		var table_resource := EngineSampleTable.new()
		table_resource.volume.assign(table["volume"])
		table_resource.pitch.assign(table["pitch"])
		table_resource.is_load = table["type"] == "load"
		tables.append(table_resource)
	var result: Array[EngineSample] = []
	for sample: Dictionary in entry["samples"]:
		var decoded: PackedByteArray = Marshalls.base64_to_raw(sample["sample"]).decompress(1000000, FileAccess.COMPRESSION_GZIP)
		var wav: AudioStreamWAV = AudioStreamWAV.load_from_buffer(decoded, params)
		for table_resource: EngineSampleTable in tables:
			var engine_sample := EngineSample.new()
			engine_sample.sample = wav
			engine_sample.rear = entry["is_rear"]
			engine_sample.root_key = int(sample["root_key"])
			engine_sample.pitch_bend_range = int(sample["pitch_bend_range"])
			engine_sample.detune = int(sample["detune"])
			engine_sample.volume = int(sample["volume"])
			engine_sample.volume_random_range = int(sample["volume_random_range"])
			engine_sample.detune_random_range = int(sample["detune_random_range"])
			engine_sample.table = table_resource
			result.append(engine_sample)
	return result


func process_car_extras(state: GLTFState, root: Node, data: Dictionary):
	var dimensions = data["dimensions"]
	var color_set: Array[CarColorSet]
	color_set.assign(data["colors"].map(self.dict_to_palette))
	var manifest := CarManifest.new()
	manifest.colors = color_set
	manifest.car_class = CAR_CLASSES[data["car_class"]]
	manifest.police = data.get("police", false)
	var manifest_path = "%s/%s_manifest.res" % [state.base_path, state.filename]
	ResourceSaver.save(manifest, manifest_path)

	root.set_meta("dimensions", Vector3(dimensions[0], dimensions[1], dimensions[2]))
	root.set_meta("performance", data["performance"])
	root.set_meta("type", "car")
	root.set_meta("color_set", color_set)
	var engine_audio = EngineAudio.new()
	for sample in data["engine_samples"]:
		engine_audio.samples.append_array(self._load_stream(sample))
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

func _make_uv_scroll(source: BaseMaterial3D, speed: float) -> ShaderMaterial:
	const SHADER: Shader = preload("res://core/resources/shader/uv_scroll.gdshader")
	const DOUBLE_SIDED_SHADER: Shader = preload("res://core/resources/shader/uv_scroll_double_sided.gdshader")
	var material := ShaderMaterial.new()
	material.resource_name = source.resource_name
	material.shader = DOUBLE_SIDED_SHADER if source.cull_mode == BaseMaterial3D.CULL_DISABLED else SHADER
	material.render_priority = source.render_priority
	material.set_shader_parameter(&"texture_albedo", source.albedo_texture)
	material.set_shader_parameter(&"albedo", source.albedo_color)
	material.set_shader_parameter(&"roughness", source.roughness)
	material.set_shader_parameter(&"specular", source.metallic_specular)
	material.set_shader_parameter(&"metallic", source.metallic)
	material.set_shader_parameter(&"vertex_color_use_as_albedo", source.vertex_color_use_as_albedo)
	material.set_shader_parameter(&"uv_scroll", speed)
	return material

func process_track_extras(state: GLTFState, root: Node, data: Dictionary):
	const HANDEDNESS: Dictionary[String, RaceTrack.TrafficHandedness] = {
		"left": RaceTrack.TrafficHandedness.Left,
		"right": RaceTrack.TrafficHandedness.Right,
	}
	var environment = data["environment"]
	var node = self.create_environment(state, environment)
	root.add_child(node)
	node.owner = root
	node = self.create_waypoints(data["waypoints"], root)
	root.set_meta("type", "track")
	root.set_meta("night", environment["weather"]["night"])
	root.set_meta("weather", environment["weather"]["rain"])
	root.set_meta("handedness", HANDEDNESS[data["traffic_handedness"]])
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
			self._replace_material(root, state.get_materials()[i], mat)
		elif material["extras"].has("SPT_uv_scroll"):
			var source = state.get_materials()[i]
			if source is BaseMaterial3D:
				var speed = float(material["extras"]["SPT_uv_scroll"])
				self._replace_material(root, source, self._make_uv_scroll(source, speed))

func _replace_material(root: Node, old: Material, new: Material):
	for child_node in root.get_children():
		if child_node is ImporterMeshInstance3D:
			for surface_id in child_node.mesh.get_surface_count():
				if child_node.mesh.get_surface_material(surface_id) == old:
					child_node.mesh.set_surface_material(surface_id, new)

func process_scene_extras(state: GLTFState, root: Node):
	var main_scene_idx = state.json["scene"]
	var scene = state.json["scenes"][main_scene_idx]
	if !scene.has("extras"):
		return null
	var extras = scene["extras"]
	if extras.has("SPT_car"):
		process_car_extras(state, root, extras["SPT_car"])
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
