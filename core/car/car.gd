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
	get:
		return lights_on
		
@export var color : CarColorSet:
	set(value):
		color = value
		self._set_car_color(value)
	get:
		return color
		
@export var palette: Array[CarColorSet]

@export var car_texture: CarTexture


const RAYCAST_DISTANCE = 10

var current_rpm := 0.0
var current_steering := 0.0
var current_throttle := 0.0
var current_brake := 0.0
var current_gear := CarTypes.Gear.NEUTRAL
var linear_acceleration = Vector3.ZERO
var prev_linear_velocity = Vector3.ZERO
var prev_angular_velocity = Vector3.ZERO
var skip_counter = 0
var handbrake_accumulator = 0
var gear_shift_counter = 0
var shifted_down = false
var g_transfer := 0.0
var has_contact_with_ground := true
var head_lights := []
var tail_lights := []
var brake_lights := []
var directional_lights := []
var reverse_lights := []
var tail_light_energy : float = 0.0
var brake_light_energy : float = 0.0

@onready var collider: CollisionShape3D = $Collider
@onready var interior_camera: Camera3D = $"Interior camera"


func _ready():
	if handling_model == null:
		handling_model = HandlingModelRE.new()
	var nodes = self.get_children().filter(func(x): return x is Light3D)
	self.head_lights = nodes.filter(func(x): return x.name.begins_with("headlight"))
	self.tail_lights = nodes.filter(func(x): return x.name.begins_with("taillight"))
	self.brake_lights = nodes.filter(func(x): return x.name.begins_with("brakelight"))
	self.reverse_lights = nodes.filter(func(x): return x.name.begins_with("reverse"))
	self.directional_lights = nodes.filter(func(x): return x.name.begins_with("directional"))
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

func _enable_lights(lights: Array, visible: bool):
	for light in lights:
		light.visible = visible


func _set_car_color(color: CarColorSet):
	if self.car_texture:
		self.car_texture.color_set = color


func get_interior_camera() -> Camera3D:
	return self.interior_camera

func dimensions() -> Vector3:
	return collider.shape.size


func max_gear() -> CarTypes.Gear:
	return self.performance.max_gear()


func do_raycast_down(position: Vector3) -> Dictionary:
	var ray_to = position + Vector3.DOWN * RAYCAST_DISTANCE
	var mask = Constants.collision_layer_to_mask([Constants.CollisionLayer.TRACK_ROAD])
	var query = PhysicsRayQueryParameters3D.create(position, ray_to, mask)
	return get_world_3d().direct_space_state.intersect_ray(query)


func distance_above_ground(raycast_result: Dictionary) -> float:
	var result = INF
	if raycast_result:
		var ground_pos = raycast_result["position"]
		result = self.global_position.y - ground_pos.y
	return result


func basis_from_normal(normal: Vector3) -> Basis:
	var x = self.basis.z.cross(normal).normalized()
	var z = normal.cross(x)
	return Basis(-x, normal, z)


func basis_to_road(raycast_result: Dictionary) -> Basis:
	var result = self.basis
	if raycast_result:
		var normal = raycast_result["normal"]
		result = basis_from_normal(normal)
	return result


func get_positional_attributes(position: Vector3) -> Dictionary:
	var raycast_result = self.do_raycast_down(position)
	return {
		"distance_above_ground": self.distance_above_ground(raycast_result),
		"basis_to_road": self.basis_to_road(raycast_result),
	}


func get_current_positional_attributes() -> Dictionary:
	return self.get_positional_attributes(self.global_position)


func get_next_positional_attributes(timestep: float) -> Dictionary:
	var next_position = self.global_position + timestep * self.linear_velocity
	return self.get_positional_attributes(next_position)


func check_contact_with_ground(positional_attributes: Dictionary) -> bool:
	return positional_attributes["distance_above_ground"] < 0.6


func keep_height_above_ground(positional_attributes: Dictionary):
	if check_contact_with_ground(positional_attributes):
		var collision = self.do_raycast_down(self.global_position)
		var pos = self.global_position
		pos.y = collision["position"].y + 0.5  # 0.6
		self.global_position = pos


func _process(delta: float):
	var velocity_local = self.basis.inverse() * self.linear_velocity * delta
	var wheel_turn = (self.current_steering / 128.0) * (PI / 4)
	for child in self.get_children().filter(func(x): return x is CarWheel):
		child.step_rotation(velocity_local.z)
		child.turn = wheel_turn


func _integrate_forces(state: PhysicsDirectBodyState3D):
	skip_counter = (skip_counter + 1) % 2
	if skip_counter == 0:
		return

	var wheels = [
		{"type": CarTypes.Wheel.FRONT_RIGHT, "road_surface": 1},
		{"type": CarTypes.Wheel.FRONT_LEFT, "road_surface": 1},
		{"type": CarTypes.Wheel.REAR_RIGHT, "road_surface": 1},
		{"type": CarTypes.Wheel.REAR_LEFT, "road_surface": 1},
	]

	var positional_attributes = self.get_current_positional_attributes()
	var next_positional_attributes = self.get_next_positional_attributes(state.step * 2)
	var model_params = {
		"linear_velocity": state.linear_velocity,
		"angular_velocity": state.angular_velocity,
		"gravity_vector": state.total_gravity,
		"has_contact_with_ground": self.has_contact_with_ground,
		"timestep": state.step * 2,
		"performance": self.performance,
		"gear": self.current_gear,
		"next_gear": self.gear,
		"rpm": self.current_rpm,
		"mass": self.mass,
		"basis": self.basis,
		"basis_to_road": positional_attributes["basis_to_road"],
		"current_steering": self.current_steering,
		"throttle_input": self.throttle,
		"throttle": self.current_throttle,
		"brake_input": self.brake,
		"brake": self.current_brake,
		"turn_input": self.steering,
		"handbrake": self.handbrake,
		"inertia_inv": state.inverse_inertia,
		"road_surface": 0,
		"weather": 0,
		"lost_grip": true,
		"basis_to_road_next": next_positional_attributes["basis_to_road"],
		"distance_above_ground": positional_attributes["distance_above_ground"],
		"wheels": wheels,
		"handbrake_accumulator": self.handbrake_accumulator,
		"force": 0.0,
		"gear_shift_counter": self.gear_shift_counter,
		"shifted_down": self.shifted_down,
		"g_transfer": self.g_transfer,
		"unknown_bool": false,
	}
	var result = handling_model.process(model_params)
	state.linear_velocity = result["linear_velocity"]
	state.angular_velocity = result["angular_velocity"]
	self.current_steering = result["current_steering"]
	self.current_throttle = result["throttle"]
	self.current_brake = result["brake"]
	self.current_rpm = result["rpm"]
	self.handbrake_accumulator = result["handbrake_accumulator"]
	self.gear_shift_counter = result["gear_shift_counter"]
	self.shifted_down = result["shifted_down"]
	self.current_gear = result["gear"]
	self.g_transfer = result["g_transfer"]
	self.has_contact_with_ground = result["has_contact_with_ground"]
	self.linear_acceleration = (state.linear_velocity - prev_linear_velocity) / (state.step * 2)
	prev_linear_velocity = state.linear_velocity
	prev_angular_velocity = state.angular_velocity
	self.keep_height_above_ground(positional_attributes)

	self._enable_lights(self.brake_lights, self.current_brake > 0)
	self._enable_lights(self.tail_lights, self.current_brake > 0 || self.lights_on)
	self._enable_lights(self.reverse_lights,self.current_gear == CarTypes.Gear.REVERSE)
	var tail_light_energy = self.tail_light_energy
	if self.current_brake > 0:
		tail_light_energy = self.brake_light_energy
	for light in self.tail_lights:
		light.light_energy = tail_light_energy
