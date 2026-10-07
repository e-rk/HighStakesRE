extends StateMachine
class_name SteeringAlgo

@export_range(0, 120, 1, "or_greater") var optimize_iterations := 120
@export_range(0.0, 100.0, 0.1) var obstacle_scale := 40.0
@export_range(0.0, 2.0, 0.001) var distance_scale := 0.01
@export_range(0.0, 20.0, 0.01) var curvature_scale := 8.0
@export_range(0.0, 10.0, 0.01) var wall_scale := 0.3
@export_range(0.0, 5.0, 0.01) var obstacle_separation := 1.0
@export_range(0.0, 5.0, 0.01) var wall_separation := 3.0
@export_range(0.0, 1.0, 0.001) var beta := 0.85

@export_range(0.0, 50.0, 0.1) var Kp := 9.0
@export_range(0.0, 50.0, 0.01) var Ki := 0.0
@export_range(0.0, 50.0, 0.01) var Kd := 1.4
@export var debug_draw := false

@onready var follow_path: SteeringAlgoFollowPath = $SteeringAlgoFollowPath
@onready var reverse: SteeringAlgoReverse = $SteeringAlgoReverse

var optimizer_context: OptimizerServer.OptimizerContext = OptimizerServer.OptimizerContext.new()
var optimizer_params: OptimizerServer.OptimizerParams = OptimizerServer.OptimizerParams.new()
var optimize_done: Semaphore = Semaphore.new()
var optimize_mtx: Mutex = Mutex.new()

var curvature: PackedFloat32Array
var offsets: PackedFloat32Array

var waypoints: NavPath

var task_id: int = -1
var pending_output: AIOutput = AIOutput.new()


class AIInput:
	var car_transform:      Transform3D
	var car_velocity:       Vector3
	var car_gear:           int
	var car_performance:    CarPerformance
	var car_handling_model: HandlingModelRE
	var car_g_transfer:     float
	var nav_waypoints:      NavPath
	var delta:              float
	var pid_prev_error:          float
	var pid_integral:            float
	var car_idx : float


class AIOutput:
	var steering:               float = 0.0
	var throttle:               float = 0.0
	var brake:                  float = 0.0
	var gear:                   CarTypes.Gear = CarTypes.Gear.GEAR_1
	var pid_prev_error:         float = 0.0
	var pid_integral:           float = 0.0


func _ready():
	OptimizerServer.register(optimizer_context)
	optimize_done.post()


func _exit_tree() -> void:
	OptimizerServer.unregister(optimizer_context)


func _get_torque_for_gear(performance: Resource,
						  handling_model: Resource,
						  gear: int,
						  speed: float) -> float:
	var rpm := maxi(performance.engine_min_rpm(), performance.gear_velocity_to_rpm(gear) * speed)
	if rpm > 0.95 * performance.engine_redline_rpm:
		return 0.0
	var state := HandlingModelRE.TractionState.new()
	state.performance = performance
	state.gear = gear
	return handling_model.traction_powertrain(state, rpm)


func best_gear_for_torque(performance: CarPerformance,
						  handling_model: Resource,
						  current_gear: int,
						  speed: float) -> int:
	const HYSTERESIS := 0.07
	var candidates := CarTypes.Gear.values().filter(
			func(x): return x <= performance.max_gear() && x >= CarTypes.Gear.GEAR_1)
	var current_torque := _get_torque_for_gear(performance, handling_model, current_gear, speed)
	var best_gear      := current_gear
	var best_torque    := current_torque
	for g in candidates:
		var t := _get_torque_for_gear(performance, handling_model, g, speed)
		if t > current_torque * (1.0 + HYSTERESIS) and t > best_torque:
			best_gear   = g
			best_torque = t
	return best_gear


func _get_angle_error(target_local: Vector3, reversing: bool) -> float:
	if reversing:
		return (-Vector3.MODEL_FRONT).signed_angle_to(target_local, Vector3.MODEL_TOP)
	return Vector3.MODEL_FRONT.signed_angle_to(target_local, Vector3.MODEL_TOP)


func calculate_steering_input(error: float,
							  delta: float,
							  prev_error: float,
							  integral: float) -> Array[float]:
	var new_integral := clampf(integral + error * delta, -1.0, 1.0)
	var result       := Kp * error + Kd * (error - prev_error) / delta + Ki * new_integral
	return [result, error, new_integral]


func _grip_params(performance: Resource, linear_velocity: Vector3, g_transfer: float) -> HandlingModelRE.HandlingState:
	var data = HandlingModelRE.HandlingState.new()
	data.performance         = performance
	data.basis_to_road       = Basis.IDENTITY
	data.basis               = Basis.IDENTITY
	data.linear_velocity     = linear_velocity
	data.gravity_vector      = Vector3(0.0, -9.8, 0.0)
	data.g_transfer          = g_transfer
	data.brake               = 0.0
	data.weather             = CarTypes.Weather.DRY
	data.drivetrain_overload = false
	return data


func _front_wheel_dict() -> HandlingModelRE.WheelData:
	var data = HandlingModelRE.WheelData.new()
	data.type = CarTypes.Wheel.FRONT_LEFT
	data.road_surface = 0
	return data


func _rear_wheel_dict() -> HandlingModelRE.WheelData:
	var data = HandlingModelRE.WheelData.new()
	data.type = CarTypes.Wheel.REAR_LEFT
	data.road_surface = 0
	return data


func compute_max_lateral_accel(performance: CarPerformance, handling_model: HandlingModelRE, linear_velocity: Vector3, g_transfer: float) -> float:
	var p := _grip_params(performance, linear_velocity, g_transfer)
	var grip_front: float = handling_model.model_wheel_grip(p, _front_wheel_dict())
	var grip_rear: float = handling_model.model_wheel_grip(p, _rear_wheel_dict())
	var tf: float = handling_model.tire_factor(p)
	grip_front = grip_front * (1.0 - tf)
	grip_rear = grip_rear  * (1.0 - tf)
	const SIN_HALF := 0.707
	var min_steer: float = performance.minimum_steering_acceleration
	var f_front := minf(SIN_HALF * grip_front * 4.0, min_steer * 2.0)
	var f_rear := minf(SIN_HALF * grip_rear * 4.0, min_steer * 2.0)
	return 0.5 * (2.0 * f_front + 2.0 * f_rear)


func get_max_cornering_speed(performance: CarPerformance,
							 handling_model: HandlingModelRE,
							 g_transfer: float,
							 linear_velocity: Vector3,
							 curve_radius: float) -> float:
	if curve_radius >= 200.0:
		return INF
	var accel := compute_max_lateral_accel(performance, handling_model, linear_velocity, g_transfer)
	return sqrt(accel * curve_radius)


func get_lookahead_speed_limit(performance: CarPerformance,
							   handling_model: HandlingModelRE,
							   speed_hint: float,
							   car_idx: float,
							   g_transfer: float,
							   linear_velocity: Vector3) -> float:
	var r := INF
	var curvatures: Array[float] = []
	var current_idx := floori(car_idx) % self.waypoints.points.size();
	var dist_accum := 0.0
	var lookahead_distance := 1 * speed_hint
	optimize_mtx.lock()
	if self.curvature.size() > 0:
		while dist_accum <= lookahead_distance:
			dist_accum += self.waypoints.point_data[current_idx].distance_to_next
			curvatures.append(self.curvature[current_idx])
			current_idx = (current_idx + 1) % self.waypoints.points.size();
		r = 1.0 / curvatures.max()
	optimize_mtx.unlock()
	return get_max_cornering_speed(performance, handling_model, g_transfer, linear_velocity, r)


func _optimizer_callback(cb_offsets: PackedFloat32Array, cb_curvature: PackedFloat32Array):
	optimize_mtx.lock()
	self.curvature = cb_curvature
	self.offsets = cb_offsets
	optimize_mtx.unlock()
	self.optimize_done.post()


func _collect_obstacles(player: Player) -> Array[OptimizerServer.ObstacleData]:
	var obstacles: Array[OptimizerServer.ObstacleData]
	var players: Array[Player]
	players.assign(get_tree().get_nodes_in_group(&"Players"))
	var self_linear_velocity := player.car.linear_velocity as Vector3
	var self_tangent := self.waypoints.tangent_vector_at_offset(player.current_node_idx, PackedFloat32Array())
	var self_tangent_velocity := self_tangent.dot(self_linear_velocity)
	for other_player in players:
		if other_player == player:
			continue
		var linear_velocity := other_player.car.linear_velocity
		var tangent := self.waypoints.tangent_vector_at_offset(other_player.current_node_idx, PackedFloat32Array())
		var tangent_velocity := tangent.dot(linear_velocity)
		if tangent_velocity > (self_tangent_velocity):
			continue
		var obstacle = OptimizerServer.ObstacleData.new()
		obstacle.offset = other_player.player_avoidance_data.offset
		obstacle.position = other_player.player_avoidance_data.position
		obstacle.dimensions = other_player.car.dimensions()
		obstacle.lateral_x = waypoints.calculate_lateral_offset(obstacle.offset, obstacle.position)
		obstacles.append(obstacle)
	return obstacles


func _collect_data_and_submit_optimization(player: Player):
	optimizer_params.distance_scale = self.distance_scale
	optimizer_params.curvature_scale = self.curvature_scale
	optimizer_params.obstacle_scale = self.obstacle_scale
	optimizer_params.wall_scale = self.wall_scale
	optimizer_params.obstacle_separation = self.obstacle_separation
	optimizer_params.wall_separation = self.wall_separation
	optimizer_params.optimize_iterations = self.optimize_iterations
	optimizer_params.radius = player.car.dimensions().length()
	optimizer_params.beta = self.beta
	optimizer_params.obstacles = self._collect_obstacles(player)
	optimizer_params.context = optimizer_context
	optimizer_params.callback = self._optimizer_callback
	OptimizerServer.submit_work(optimizer_params)


func process(player: Player, delta: float):
	if self.optimize_done.try_wait():
		self._collect_data_and_submit_optimization(player)
	var output := self._get_pending_output()
	if output:
		self._apply_output(player.car, output)
		var input := _snapshot_input(player, output, delta)
		var fn: Callable = current_state.compute
		self.task_id = WorkerThreadPool.add_task(func(): _worker_task(fn, input), false, "AIComputeTask")


func _worker_task(fn: Callable, input: AIInput) -> void:
	var output: AIOutput = fn.call(input)
	pending_output = output


func _get_pending_output() -> AIOutput:
	if self.task_id != -1:
		if not WorkerThreadPool.is_task_completed(self.task_id): return null
		WorkerThreadPool.wait_for_task_completion(self.task_id)
	self.task_id = -1
	var ret := self.pending_output
	self.pending_output = null
	return ret


func _apply_output(car: Car, output: AIOutput) -> void:
	car.steering = output.steering
	car.throttle = output.throttle
	car.brake    = output.brake
	if output.gear != car.gear and car.gear_shift_counter <= 0:
		car.gear = output.gear


func _snapshot_input(player: Player, previous_output: AIOutput, delta: float) -> AIInput:
	var input               := AIInput.new()
	input.car_transform      = player.car.global_transform
	input.car_velocity       = player.car.linear_velocity
	input.car_gear           = player.car.gear
	input.car_performance    = player.car.performance
	input.car_handling_model = player.car.handling_model
	input.car_g_transfer     = player.car.g_transfer
	input.nav_waypoints      = waypoints
	input.delta              = delta
	input.pid_prev_error     = previous_output.pid_prev_error
	input.pid_integral       = previous_output.pid_integral
	input.car_idx            = player.current_node_idx
	return input


func reset():
	self.set_state(get_node(self.initial_state))
