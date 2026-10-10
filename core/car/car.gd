class_name Car
extends RigidBody3D

@export var performance: CarPerformance

@export_range(-1.0, 1.0) var steering: float = 0.0:
	set(value):
		steering = clamp(value, -1.0, 1.0)
	get:
		return steering

@export_range(0.0, 1.0) var throttle: float = 0.0:
	set(value):
		throttle = clamp(value, 0.0, 1.0)
	get:
		return throttle

@export var handbrake: bool = false

@export var controls_locked: bool = false

@export_range(0.0, 1.0) var brake: float = 0.0:
	set(value):
		brake = clamp(value, 0.0, 1.0)
	get:
		return brake

@export var gear := CarTypes.Gear.NEUTRAL:
	set(value):
		gear = clamp(value, CarTypes.Gear.REVERSE, self.max_gear())
	get:
		return gear

@export var handling_model: HandlingModel

@export var lights_on : bool:
	set(value):
		lights_on = value
		self._enable_lights(self.head_lights, value)
		self._enable_lights(self.tail_lights, value)
		if self.interior_dashboard_lit:
			self.interior_dashboard_lit.visible = value
		if self.dashboard_lit:
			self.dashboard_lit.visible = value
	get:
		return lights_on

@export var siren_on : bool:
	set(value):
		siren_on = value
		self._enable_lights(self.siren_lights, value)
	get:
		return siren_on

@export var color : CarColorSet:
	set(value):
		color = value
		self._set_car_color(value)
	get:
		return color

@export var palette: Array[CarColorSet]

@export var car_textures: Array[CarTexture] = []

@export var spectated: bool = true:
	set(value):
		if value != spectated:
			self._set_spectated(value)
		spectated = value

@export var minimap_color: Color = Color.SILVER:
	set(value):
		self.minimap_material.albedo_color = value

var current_rpm := 0.0
var current_steering := 0.0
var current_throttle := 0.0
var current_brake := 0.0
var current_gear := CarTypes.Gear.NEUTRAL
var linear_acceleration := Vector3.ZERO
var prev_linear_velocity := Vector3.ZERO
var prev_angular_velocity := Vector3.ZERO
var skip_counter := 0
var handbrake_accumulator := 0
var gear_shift_counter := 0
var shifted_down := false
var g_transfer := 0.0
var has_contact_with_ground := true
var head_lights: Array[Light3D] = []
var tail_lights: Array[Light3D] = []
var brake_lights: Array[Light3D] = []
var directional_lights: Array[Light3D] = []
var reverse_lights: Array[Light3D] = []
var siren_lights: Array[Light3D] = []
var tail_light_energy : float = 0.0
var brake_light_energy : float = 0.0

var handling_model_params := HandlingModel.HandlingState.new()
var handling_model_output := HandlingModel.HandlingOutput.new()
var collision_params := HandlingModelRE.CollisionParams.new()
var collision_output := HandlingModelRE.CollisionOutput.new()
var steering_bone := -1
var steering_bone_rest := Quaternion.IDENTITY

@onready var collider: CollisionShape3D = $Collider
@onready var interior_camera: Camera3D = get_node_or_null("Interior camera")
@onready var interior_wheel: MeshInstance3D = get_node_or_null("steering")
@onready var rpm_meter: MeshInstance3D = get_node_or_null("tachometer")
@onready var mph_meter: MeshInstance3D = get_node_or_null("speedometer")
@onready var interior_dashboard_lit: MeshInstance3D = get_node_or_null("interior_dashboard_lit")
@onready var dashboard_lit: MeshInstance3D = get_node_or_null("dashboard_lit")
@onready var road_raycasts: Node3D = $RoadRaycasts
@onready var road_raycast_down: RayCast3D = $RoadRaycasts/Down
@onready var road_raycast_up: RayCast3D = $RoadRaycasts/Up
@onready var synchronizer: CarSynchronizer = $CarSynchronizer
@onready var wall_prober: RayCast3D = $WallProber
@onready var minimap_mesh: MeshInstance3D = $MinimapMesh
@onready var minimap_material: StandardMaterial3D = minimap_mesh.get_active_material(0) as StandardMaterial3D
@onready var steering_skeleton: Skeleton3D = $driver_rig/Skeleton3D
@onready var driver: MeshInstance3D = $driver_rig/Skeleton3D/driver


func _ready() -> void:
	if handling_model == null:
		handling_model = HandlingModelRE.new()
	var nodes := self.get_children().filter(func(x: Node) -> bool: return x is Light3D)
	self.head_lights.assign(nodes.filter(func(x): return x.name.begins_with("headlight")))
	self.tail_lights.assign(nodes.filter(func(x): return x.name.begins_with("taillight")))
	self.brake_lights.assign(nodes.filter(func(x): return x.name.begins_with("brakelight")))
	self.reverse_lights.assign(nodes.filter(func(x): return x.name.begins_with("reverse")))
	self.directional_lights.assign(nodes.filter(func(x): return x.name.begins_with("directional")))
	self.siren_lights.assign(nodes.filter(func(x): return x.name.begins_with("siren")))
	self._enable_lights(self.head_lights, self.lights_on)
	self._enable_lights(self.tail_lights, self.lights_on)
	self._enable_lights(self.brake_lights, false)
	self._enable_lights(self.reverse_lights, false)
	self._enable_lights(self.directional_lights, false)
	if self.tail_lights:
		self.tail_light_energy = self.tail_lights[0].light_energy
	if self.brake_lights:
		self.brake_light_energy = self.brake_lights[0].light_energy
	else:
		self.brake_light_energy = 2 * tail_light_energy
	if not self.interior_wheel:
		self.interior_wheel = self.find_child("*Steering*")
	self.minimap_mesh.show()
	if self.steering_skeleton:
		self._find_steering_bone()


func _find_steering_bone() -> void:
	var bone := self.steering_skeleton.find_bone("rotation")
	self.steering_bone = bone
	self.steering_bone_rest = steering_skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()


func _enable_lights(lights: Array, show_lights: bool) -> void:
	for light in lights:
		light.visible = show_lights


func _set_car_color(color: CarColorSet) -> void:
	for texture in self.car_textures:
		texture.color_set = color


func get_interior_camera() -> Camera3D:
	return self.interior_camera

func dimensions() -> Vector3:
	return collider.shape.size


func max_gear() -> CarTypes.Gear:
	return self.performance.max_gear()


func _do_road_raycasts(raycast_position: Vector3) -> Dictionary:
	self.road_raycasts.global_position = raycast_position
	self.road_raycasts.force_update_transform()
	self.road_raycast_down.force_raycast_update()
	self.road_raycast_up.force_raycast_update()
	var collision_position = Vector3(raycast_position.x, -INF, raycast_position.z)
	var normal = Vector3.UP
	if self.road_raycast_down.is_colliding():
		collision_position = self.road_raycast_down.get_collision_point()
		normal = self.road_raycast_down.get_collision_normal()
	elif self.road_raycast_up.is_colliding():
		collision_position = self.road_raycast_up.get_collision_point()
		normal = -self.road_raycast_up.get_collision_normal()
	var result = {
		"distance": (position.y - collision_position.y),
		"normal": normal,
	}
	return result


func basis_from_normal(normal: Vector3) -> Basis:
	var x = self.basis.z.cross(normal).normalized()
	var z = normal.cross(x)
	return Basis(-x, normal, z)


func get_positional_attributes(position: Vector3) -> Dictionary:
	var result = self._do_road_raycasts(position)
	return {
		"distance_above_ground": result["distance"],
		"basis_to_road": self.basis_from_normal(result["normal"]),
	}


func get_current_positional_attributes(state: PhysicsDirectBodyState3D) -> Dictionary:
	return self.get_positional_attributes(state.transform.origin)


func get_next_positional_attributes(state: PhysicsDirectBodyState3D, timestep: float) -> Dictionary:
	var next_position = state.transform.origin + timestep * state.linear_velocity
	return self.get_positional_attributes(next_position)


func keep_height_above_ground(state: PhysicsDirectBodyState3D, height_adjust: float) -> void:
	if height_adjust <= 0.0:
		var pos = state.transform.origin
		pos.y = pos.y - height_adjust
		state.transform.origin = pos


func enable_sync(enable: bool) -> void:
	self.synchronizer.public_visibility = enable


func is_police() -> bool:
	return not self.siren_lights.is_empty()


func is_siren_active() -> bool:
	if self.siren_lights:
		return self.siren_lights[0].visible
	return false


func _set_spectated(value: bool) -> void:
	var interior_mask: int = Constants.visual_layer_to_mask([Constants.VisualLayer.PLAYER_INTERIOR])
	var exterior_mask: int = Constants.visual_layer_to_mask([Constants.VisualLayer.PLAYER])
	var minimap_mask: int = Constants.visual_layer_to_mask([Constants.VisualLayer.MINIMAP])
	if not value:
		interior_mask = 0
		exterior_mask = Constants.visual_layer_to_mask([Constants.VisualLayer.OPPONENTS])
	var visual_nodes: Array[MeshInstance3D]
	visual_nodes.assign(self.get_children().filter(func(x): return x is MeshInstance3D and x.layers & minimap_mask == 0))
	if driver:
		visual_nodes.append(driver)
	for child in visual_nodes:
		var extras = child.get_meta("extras", {})
		if extras and extras.get("SPT_interior", false):
			child.layers = interior_mask
		elif child is MeshInstance3D:
			child.layers = exterior_mask


func _process(delta: float) -> void:
	var velocity_local = self.basis.inverse() * self.linear_velocity * delta
	var wheel_turn = (self.current_steering / 128.0) * (PI / 4)
	for child in self.get_children().filter(func(x): return x is CarWheel):
		child.step_rotation(velocity_local.z)
		child.turn = wheel_turn
	if self.interior_wheel:
		self.interior_wheel.rotation = remap(self.current_steering, -128.0, 128.0, deg_to_rad(90), deg_to_rad(-90)) * Vector3.MODEL_FRONT
	if self.steering_skeleton:
		var hands_turn := remap(self.current_steering, -128.0, 128.0, deg_to_rad(90), deg_to_rad(-90))
		self.steering_skeleton.set_bone_pose_rotation(self.steering_bone, self.steering_bone_rest * Quaternion(Vector3.UP, hands_turn))
	if self.rpm_meter:
		self.rpm_meter.value = remap(self.current_rpm, self.performance.engine_min_rpm(), self.performance.engine_redline_rpm, 0.0, 1.0)
	if self.mph_meter:
		self.mph_meter.value = remap(self.linear_velocity.length(), 0, self.performance.max_velocity(), 0.0, 1.0)


func _min_dot(collision_point: Vector3, normal: Vector3, point_a: Vector3, point_b: Vector3) -> bool:
	var dot_a = normal.dot(point_a - collision_point)
	var dot_b = normal.dot(point_b - collision_point)
	return dot_a < dot_b


func _collision(state: PhysicsDirectBodyState3D) -> HandlingModelRE.CollisionOutput:
	var next_position := state.transform.origin + state.linear_velocity * state.step * 2
	var next_rotation := state.angular_velocity * state.step * 2
	var next_basis := Basis.from_euler(next_rotation)
	var rotated := next_basis * state.transform.basis
	var next_transform := Transform3D(rotated, next_position)

	var shape_size: Vector3 = self.collider.shape.size
	shape_size /= 2.0
	var points_to_check: Array[Vector3] = [
		Vector3(shape_size.x, 0.0, shape_size.z),
		Vector3(-shape_size.x, 0.0, shape_size.z),
		Vector3(-shape_size.x, 0.0, -shape_size.z),
		Vector3(shape_size.x, 0.0, -shape_size.z),
		Vector3(shape_size.x, 0.0, 0.0),
		Vector3(-shape_size.x, 0.0, 0.0),
		Vector3(0.0, 0.0, shape_size.z),
		Vector3(0.0, 0.0, -shape_size.z),
	]
	var points_current := points_to_check.map(func(x): return state.transform * x)
	var points_next = points_to_check.map(func(x): return next_transform * x)

	var current_linear_velocity = state.linear_velocity
	var current_angular_velocity = state.angular_velocity
	var current_position = state.transform.origin

	for point in points_next:
		self.wall_prober.target_position = next_transform.inverse() * point
		self.wall_prober.force_raycast_update()

		if self.wall_prober.is_colliding():
			var collision_point = self.wall_prober.get_collision_point()
			var collision_normal = self.wall_prober.get_collision_normal()
			points_current.sort_custom(func(x, y): return _min_dot(collision_point, collision_normal, x, y))
			var min_point = points_current[0]
			self.collision_params.position = current_position
			self.collision_params.angular_velocity = current_angular_velocity
			self.collision_params.linear_velocity = current_linear_velocity
			self.collision_params.friction = self.physics_material_override.friction
			self.collision_params.mass = self.mass
			self.collision_params.inertia_inv = state.inverse_inertia
			self.collision_params.basis = state.transform.basis
			self.handling_model.process_collision(
				self.collision_params,
				min_point,
				collision_point,
				collision_normal,
				1.0,
				self.collision_output
			)
			current_position = self.collision_output.position
			current_linear_velocity = self.collision_output.linear_velocity
			current_angular_velocity = self.collision_output.angular_velocity
	self.collision_output.position = current_position
	self.collision_output.linear_velocity = current_linear_velocity
	self.collision_output.angular_velocity = current_angular_velocity
	return self.collision_output


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	skip_counter = (skip_counter + 1) % 2
	if skip_counter == 0:
		return

	var wheels = [
		{"type": CarTypes.Wheel.FRONT_RIGHT, "road_surface": 1},
		{"type": CarTypes.Wheel.FRONT_LEFT, "road_surface": 1},
		{"type": CarTypes.Wheel.REAR_RIGHT, "road_surface": 1},
		{"type": CarTypes.Wheel.REAR_LEFT, "road_surface": 1},
	]
	var collision_result := self._collision(state)
	state.linear_velocity = collision_result.linear_velocity
	state.angular_velocity = collision_result.angular_velocity
	state.transform.origin = collision_result.position

	var positional_attributes = self.get_current_positional_attributes(state)
	var next_positional_attributes = self.get_next_positional_attributes(state, state.step * 2)

	handling_model_params
	handling_model_params.linear_velocity = state.linear_velocity
	handling_model_params.angular_velocity = state.angular_velocity
	handling_model_params.gravity_vector = state.total_gravity
	handling_model_params.has_contact_with_ground = self.has_contact_with_ground
	handling_model_params.timestep = state.step * 2
	handling_model_params.performance = self.performance
	handling_model_params.gear = self.current_gear
	handling_model_params.next_gear = self.gear
	handling_model_params.rpm = self.current_rpm
	handling_model_params.mass = self.mass
	handling_model_params.basis = state.transform.basis
	handling_model_params.basis_to_road = positional_attributes["basis_to_road"]
	handling_model_params.current_steering = self.current_steering
	handling_model_params.throttle_input = self.throttle
	handling_model_params.throttle = self.current_throttle
	handling_model_params.brake_input = self.brake
	handling_model_params.brake = self.current_brake
	handling_model_params.turn_input = self.steering
	handling_model_params.handbrake = self.handbrake
	handling_model_params.controls_locked = self.controls_locked
	handling_model_params.inertia_inv = state.inverse_inertia
	handling_model_params.road_surface = 0
	handling_model_params.weather = 0
	handling_model_params.lost_grip = true
	handling_model_params.basis_to_road_next = next_positional_attributes["basis_to_road"]
	handling_model_params.distance_above_ground = positional_attributes["distance_above_ground"]
	handling_model_params.wheels = wheels
	handling_model_params.handbrake_accumulator = self.handbrake_accumulator
	handling_model_params.force = 0.0
	handling_model_params.gear_shift_counter = self.gear_shift_counter
	handling_model_params.shifted_down = self.shifted_down
	handling_model_params.g_transfer = self.g_transfer
	handling_model_params.dimensions = self.dimensions()

	handling_model.process(handling_model_params, handling_model_output)

	state.linear_velocity = handling_model_output.linear_velocity
	state.angular_velocity = handling_model_output.angular_velocity
	self.current_steering = handling_model_output.current_steering
	self.current_throttle = handling_model_output.throttle
	self.current_brake = handling_model_output.brake
	self.current_rpm = handling_model_output.rpm
	self.handbrake_accumulator = handling_model_output.handbrake_accumulator
	self.gear_shift_counter = handling_model_output.gear_shift_counter
	self.shifted_down = handling_model_output.shifted_down
	self.current_gear = handling_model_output.gear
	self.g_transfer = handling_model_output.g_transfer
	self.has_contact_with_ground = handling_model_output.has_contact_with_ground

	self.linear_acceleration = (state.linear_velocity - prev_linear_velocity) / (state.step * 2)
	prev_linear_velocity = state.linear_velocity
	prev_angular_velocity = state.angular_velocity
	var height_adjust = self.handling_model.height_above_surface(handling_model_params)
	if self.has_contact_with_ground:
		self.keep_height_above_ground(state, height_adjust)
	self._enable_lights(self.brake_lights, self.current_brake > 0)
	self._enable_lights(self.tail_lights, self.current_brake > 0 || self.lights_on)
	self._enable_lights(self.reverse_lights,self.current_gear == CarTypes.Gear.REVERSE)
	self.gear = self.current_gear
	var tail_light_energy = self.tail_light_energy
	if self.current_brake > 0:
		tail_light_energy = self.brake_light_energy
	for light in self.tail_lights:
		light.light_energy = tail_light_energy
