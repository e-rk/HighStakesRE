extends Node3D

@export var racer: Racer = null:
	set(value):
		racer = value
	get:
		return racer

@export var race_laps: int = 2

@onready var ui: PlayerUI = $PlayerUI
@onready var reflection: ReflectionProbe = $ReflectionProbe
@onready var main_camera: Camera3D = $MainCamera

var offset = Vector3(0.0, 1.8, -5.2)
var factor = 0.25
var previous_global_offset = Vector3.ZERO

func set_waypoints(waypoints: Array):
	ui.set_minimap_waypoints(waypoints)


func player_to_minimap_data(node: Node) -> Dictionary:
	var racer = node as Racer
	return {
		"global_position": racer.car.global_position,
		"emphasis": false,
		"color": Color.BLUE,
	}


func _acceleration_factor(forward_acceleration: float, camera_factor) -> Vector3:
	var clamped = clampf(forward_acceleration, -3.0, 3.0)
	var factor = 1.0 - (1.0 - (clamped + 3.0) * 0.16666667) * camera_factor
	return Vector3(factor, factor ** 2, factor)


func _interpolation_factor() -> float:
	return self.factor * 0.27027026


func interpolate_camera(car: Car) -> Vector3:
	var local_linear_velocity = car.basis.inverse() * car.linear_velocity
	var dimensions = car.dimensions()
	var z_offset = sqrt(local_linear_velocity.z ** 2 + local_linear_velocity.x ** 2) * 0.05
	z_offset = minf(z_offset, 6.0)
	var local_linear_accel = car.basis.inverse() * car.linear_acceleration
	var accel_factor = self._acceleration_factor(local_linear_accel.z, 0.20)
	var interpolation_factor = self._interpolation_factor()
	var offset = self.offset * accel_factor
	offset.y += dimensions.y * 0.25
	offset.z = offset.z - z_offset - dimensions.z * 0.25
	var global_target = car.basis * offset
	var global_offset = self.previous_global_offset.lerp(global_target, interpolation_factor)
	self.previous_global_offset = global_offset
	var next_position = car.position + global_offset
	return next_position


func _physics_process(delta):
	var racer = get_tree().get_first_node_in_group(&"SpectatedRacer")
	var player_data = get_tree().get_nodes_in_group(&"Racers").map(player_to_minimap_data)
	if racer:
		main_camera.position = self.interpolate_camera(racer.car)
		main_camera.look_at(racer.car.position + Vector3(0, 1, 0))
		self.global_transform = racer.car.global_transform
		ui.set_speed(racer.car.linear_velocity.length())
		ui.set_rpm(racer.car.current_rpm)
		ui.set_gear(racer.car.gear)
		ui.set_minimap_center(racer.car.global_position)
		ui.set_minimap_rotation(racer.car.global_rotation.y)
		ui.set_minimap_players(player_data)
		ui.set_laps(racer.laps, self.race_laps)
		ui.set_current_lap_time(racer.current_lap_time)
		ui.set_last_lap_time(racer.last_lap_time)
