extends Node3D

@export var racer: Racer = null:
	set(value):
		racer = value
	get:
		return racer

@export var race_laps: int = 2

@onready var ui: PlayerUI = $PlayerUI
@onready var camera_arm: SpringArm3D = $CameraArm
@onready var reflection: ReflectionProbe = $ReflectionProbe
@onready var main_camera: Camera3D = $MainCamera
@onready var target: Marker3D = $CameraArm/CameraTarget

enum CameraMode {
	HELI,
	INTERIOR,
}

var factor = 0.25
var previous_global_offset = Vector3.ZERO
var camera_mode: CameraMode = CameraMode.HELI
var initial_arm_rotation = Basis.IDENTITY
var stiffen_camera = false

func _ready() -> void:
	self.set_target_position(Vector3(0.0, 1.8, -5.2))
	self.initial_arm_rotation = self.camera_arm.basis


func set_waypoints(waypoints: Array):
	ui.set_minimap_waypoints(waypoints)


func set_target_position(position: Vector3):
	self.camera_arm.look_at(self.to_global(position), Vector3.RIGHT, true)
	self.camera_arm.spring_length = position.length()


func player_to_minimap_data(spectated_racer: Racer, node: Node) -> Dictionary:
	var racer = node as Racer
	return {
		"global_position": racer.player.car.global_position,
		"emphasis": racer == spectated_racer,
		"color": racer.player.car.color.primary,
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
	var offset = (self.camera_arm.basis * self.target.position) * accel_factor
	offset.y += dimensions.y * 0.25
	offset.z = offset.z - z_offset - dimensions.z * 0.25
	var global_target = car.basis * offset
	var global_offset = self.previous_global_offset.lerp(global_target, interpolation_factor)
	self.previous_global_offset = global_offset
	var next_position = car.position + global_offset
	return next_position


func rotate_camera(angle: float):
	var racer = get_tree().get_first_node_in_group(&"SpectatedRacer")
	if racer:
		var target_basis = self.initial_arm_rotation.rotated(Vector3.UP, angle)
		self.camera_arm.basis = target_basis
		self.main_camera.basis = target_basis
		self.update_camera()
		self.main_camera.reset_physics_interpolation()

func update_camera():
	var racer = get_tree().get_first_node_in_group(&"SpectatedRacer")
	if racer:
		if self.stiffen_camera:
			self.main_camera.position = self.camera_arm.to_global(self.target.position)
		else:
			self.main_camera.position = self.interpolate_camera(racer.player.car)
		self.main_camera.look_at(racer.player.car.position + Vector3(0, 1, 0))


func _physics_process(delta):
	var racer = get_tree().get_first_node_in_group(&"SpectatedRacer") as Racer
	var player_data = get_tree().get_nodes_in_group(&"Racers").map(func(x): return player_to_minimap_data(racer, x))
	update_camera()
	if racer:
		self.global_transform = racer.player.car.global_transform
		ui.set_speed(racer.player.car.linear_velocity.length())
		ui.set_rpm(racer.player.car.current_rpm)
		ui.set_gear(racer.player.car.gear)
		ui.set_minimap_center(racer.player.car.global_position)
		ui.set_minimap_rotation(racer.player.car.global_rotation.y)
		ui.set_minimap_players(player_data)
		ui.set_laps(racer.laps, self.race_laps)
		ui.set_current_lap_time(racer.current_lap_time())
		ui.set_last_lap_time(racer.get_best_lap_time())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("change_camera"):
		var racer = get_tree().get_first_node_in_group(&"SpectatedRacer")
		var interior_camera = racer.player.car.get_interior_camera()
		match camera_mode:
			CameraMode.HELI when interior_camera:
				interior_camera.make_current()
				camera_mode = CameraMode.INTERIOR
			CameraMode.INTERIOR:
				main_camera.make_current()
				camera_mode = CameraMode.HELI
	if event.is_action_pressed("look_back"):
		self.stiffen_camera = true;
		self.rotate_camera(PI)
	elif event.is_action_pressed("look_right"):
		self.stiffen_camera = true;
		self.rotate_camera(-PI/2)
	elif event.is_action_pressed("look_left"):
		self.stiffen_camera = true;
		self.rotate_camera(PI/2)
	else:
		var actions = ["look_back", "look_right", "look_left"]
		for action in actions:
			if event.is_action_released(action):
				self.stiffen_camera = false
				self.rotate_camera(0)
				break
