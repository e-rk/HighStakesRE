extends Node3D

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


func player_to_minimap_data(spectated_player: Player, node: Node) -> Dictionary:
	var player = node as Player
	return {
		"global_position": player.car.global_position,
		"emphasis": player == spectated_player,
		"color": player.car.color.primary,
	}


func _collect_minimap_data() -> Array[Dictionary]:
	var result: Array[Dictionary]
	var player = get_tree().get_first_node_in_group(&"SpectatedPlayer") as Player
	result.assign(get_tree().get_nodes_in_group(&"Players").map(func(x): return player_to_minimap_data(player, x)))
	return result


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
	var racer = get_tree().get_first_node_in_group(&"SpectatedPlayer")
	if racer:
		var target_basis = self.initial_arm_rotation.rotated(Vector3.UP, angle)
		self.camera_arm.basis = target_basis
		self.main_camera.basis = target_basis
		self.update_camera()
		self.main_camera.reset_physics_interpolation()

func update_camera(immediate: bool = false):
	var player = get_tree().get_first_node_in_group(&"SpectatedPlayer")
	if player:
		self.global_transform = player.car.global_transform
		if self.stiffen_camera or immediate:
			self.force_update_transform()
			self.main_camera.position = self.camera_arm.to_global(self.target.position)
		else:
			self.main_camera.position = self.interpolate_camera(player.car)
		self.main_camera.look_at(player.car.position + Vector3(0, 1, 0))

func _show_next_player():
	var players: Array[Player]
	var player = get_tree().get_first_node_in_group(&"SpectatedPlayer")
	players.assign(get_tree().get_nodes_in_group(&"Players"))
	var index = players.find(player)
	var next = 0
	if index >= 0:
		next = (index + 1) % players.size()
	player.remove_from_group(&"SpectatedPlayer")
	players[next].add_to_group(&"SpectatedPlayer")
	self.update_camera()


func _update_ui(player: Player):
	pass


func _physics_process(delta: float) -> void:
	self.update_camera()


func _process(delta):
	var player = get_tree().get_first_node_in_group(&"SpectatedPlayer") as Player
	var player_data = self._collect_minimap_data()
	if player:
		ui.set_speed(player.car.linear_velocity.length())
		ui.set_rpm(player.car.current_rpm)
		ui.set_gear(player.car.gear)
		ui.set_minimap_center(player.car.global_position)
		ui.set_minimap_rotation(player.car.global_rotation.y)
		ui.set_minimap_players(player_data)
		self._update_ui(player)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("change_camera"):
		var player = get_tree().get_first_node_in_group(&"SpectatedPlayer") as Player
		var interior_camera = player.car.get_interior_camera()
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
	if event.is_action_pressed("show_next_player"):
		self._show_next_player()
