extends Resource
class_name HandlingModel

class HandlingState:
	var linear_velocity: Vector3
	var angular_velocity: Vector3
	var gear: CarTypes.Gear
	var rpm: int
	var force: float
	var lost_grip: bool
	var handbrake_accumulator: int
	var current_steering: float
	var gear_shift_counter: int
	var shifted_down: bool
	var g_transfer: float
	var throttle: float
	var brake: float
	var has_contact_with_ground: bool
	var steering: float
	var performance: CarPerformance
	var handbrake: bool
	var basis_to_road: Basis
	var basis: Basis
	var basis_to_road_next: Basis
	var gravity_vector: Vector3
	var mass: float
	var inertia_inv: Vector3
	var timestep: float
	var wheels: Array
	var turn_input: float
	var throttle_input: float
	var brake_input: float
	var next_gear: CarTypes.Gear
	var distance_above_ground: float
	var dimensions: Vector3
	var weather: int
	var position: Vector3
	var friction: float
	var road_surface: int
	var slip_angle: float
	var speed_xz: float
	var drivetrain_overload: bool
	var controls_locked: bool
	var traction_suspended: bool
	var wheel_linear_acceleration: Vector3
	var wheel_angular_acceleration: Vector3
	var stop_moving_sideways: bool

class HandlingOutput:
	const F_LINEAR_VELOCITY         = 1 << 0
	const F_ANGULAR_VELOCITY        = 1 << 1
	const F_GEAR                    = 1 << 2
	const F_RPM                     = 1 << 3
	const F_FORCE                   = 1 << 4
	const F_LOST_GRIP               = 1 << 5
	const F_HANDBRAKE_ACCUMULATOR   = 1 << 6
	const F_CURRENT_STEERING        = 1 << 7
	const F_GEAR_SHIFT_COUNTER      = 1 << 8
	const F_SHIFTED_DOWN            = 1 << 9
	const F_G_TRANSFER              = 1 << 10
	const F_THROTTLE                = 1 << 11
	const F_BRAKE                   = 1 << 12
	const F_HAS_CONTACT_WITH_GROUND = 1 << 13
	const F_STEERING                = 1 << 14
	const F_POSITION                = 1 << 15
	const F_LINEAR_ACCELERATION     = 1 << 16
	const F_ANGULAR_ACCELERATION    = 1 << 17
	const F_DRIVETRAIN_OVERLOAD     = 1 << 18
	const F_WHEEL_ACCELERATION      = 1 << 19
	const F_STOP_MOVING_SIDEWAYS    = 1 << 20

	var updated: int = 0

	var linear_velocity: Vector3
	var angular_velocity: Vector3
	var gear: CarTypes.Gear
	var rpm: int
	var force: float
	var lost_grip: bool
	var handbrake_accumulator: int
	var current_steering: float
	var gear_shift_counter: int
	var shifted_down: bool
	var g_transfer: float
	var throttle: float
	var brake: float
	var has_contact_with_ground: bool
	var steering: float
	var position: Vector3
	var linear_acceleration: Vector3
	var angular_acceleration: Vector3
	var drivetrain_overload: bool
	var wheel_linear_acceleration: Vector3
	var wheel_angular_acceleration: Vector3
	var stop_moving_sideways: bool


func extract(params: Dictionary) -> Dictionary:
	return {
		"linear_velocity": params["linear_velocity"],
		"angular_velocity": params["angular_velocity"],
		"gear": params["gear"],
		"rpm": params["rpm"],
		"current_steering": params["current_steering"],
		"lost_grip": params["lost_grip"],
		"handbrake_accumulator": params["handbrake_accumulator"],
		"force": params["force"],
		"gear_shift_counter": params["gear_shift_counter"],
		"shifted_down": params["shifted_down"],
		"g_transfer": params["g_transfer"],
		"throttle": params["throttle"],
		"brake": params["brake"],
		"has_contact_with_ground": params["has_contact_with_ground"],
	}

func extend(f: Callable) -> Callable:
	return func(state: HandlingState, output: HandlingOutput) -> void:
		output.updated = 0
		f.call(state, output)
		if output.updated & HandlingOutput.F_LINEAR_VELOCITY:
			state.linear_velocity = output.linear_velocity
		if output.updated & HandlingOutput.F_ANGULAR_VELOCITY:
			state.angular_velocity = output.angular_velocity
		if output.updated & HandlingOutput.F_GEAR:
			state.gear = output.gear
		if output.updated & HandlingOutput.F_RPM:
			state.rpm = output.rpm
		if output.updated & HandlingOutput.F_CURRENT_STEERING:
			state.current_steering = output.current_steering
		if output.updated & HandlingOutput.F_LOST_GRIP:
			state.lost_grip = output.lost_grip
		if output.updated & HandlingOutput.F_HANDBRAKE_ACCUMULATOR:
			state.handbrake_accumulator = output.handbrake_accumulator
		if output.updated & HandlingOutput.F_FORCE:
			state.force = output.force
		if output.updated & HandlingOutput.F_GEAR_SHIFT_COUNTER:
			state.gear_shift_counter = output.gear_shift_counter
		if output.updated & HandlingOutput.F_SHIFTED_DOWN:
			state.shifted_down = output.shifted_down
		if output.updated & HandlingOutput.F_G_TRANSFER:
			state.g_transfer = output.g_transfer
		if output.updated & HandlingOutput.F_THROTTLE:
			state.throttle = output.throttle
		if output.updated & HandlingOutput.F_BRAKE:
			state.brake = output.brake
		if output.updated & HandlingOutput.F_HAS_CONTACT_WITH_GROUND:
			state.has_contact_with_ground = output.has_contact_with_ground
		if output.updated & HandlingOutput.F_STEERING:
			state.steering = output.steering
		if output.updated & HandlingOutput.F_POSITION:
			state.position = output.position
		if output.updated & HandlingOutput.F_DRIVETRAIN_OVERLOAD:
			state.drivetrain_overload = output.drivetrain_overload
		if output.updated & HandlingOutput.F_WHEEL_ACCELERATION:
			state.wheel_linear_acceleration = output.wheel_linear_acceleration
			state.wheel_angular_acceleration = output.wheel_angular_acceleration
		if output.updated & HandlingOutput.F_STOP_MOVING_SIDEWAYS:
			state.stop_moving_sideways = output.stop_moving_sideways

func integrate(f: Callable) -> Callable:
	return func(state: HandlingState, output: HandlingOutput) -> void:
		output.updated = 0
		f.call(state, output)
		var linear_velocity := state.linear_velocity
		var angular_velocity := state.angular_velocity
		if output.updated & HandlingOutput.F_LINEAR_ACCELERATION:
			linear_velocity += output.linear_acceleration * state.timestep
		if output.updated & HandlingOutput.F_ANGULAR_ACCELERATION:
			angular_velocity += output.angular_acceleration * state.timestep
		output.linear_velocity = linear_velocity
		output.angular_velocity = angular_velocity
		output.updated |= HandlingOutput.F_LINEAR_VELOCITY | HandlingOutput.F_ANGULAR_VELOCITY

func enable_if(predicate: Callable, f: Callable) -> Callable:
	return func(state: HandlingState, output: HandlingOutput) -> void:
		if predicate.call(state):
			extend(f).call(state, output)

func either(predicate: Callable, true_f: Callable, false_f: Callable) -> Callable:
	return func(params: Dictionary) -> Dictionary:
		if predicate.call(params):
			return true_f.call(params)
		return false_f.call(params)

func neg(predicate: Callable) -> Callable:
	return func(state: HandlingState) -> bool:
		return not predicate.call(state)

func compose(f: Callable, g: Callable) -> Callable:
	return func(state: HandlingState, output: HandlingOutput) -> void:
		extend(g).call(state, output)
		extend(f).call(state, output)

func make_pipeline(composer: Callable, func_array: Array) -> Callable:
	var last_idx = func_array.size() - 1
	var i = last_idx - 1
	var f = func_array[last_idx]
	while i >= 0:
		var g = func_array[i]
		f = composer.call(f, g)
		i -= 1
	return f

func make_model_pipeline(func_array: Array[Callable]) -> Callable:
	return func(state: HandlingState, output: HandlingOutput):
		return run_pipeline(state, output, func_array)

func run_pipeline(state: HandlingState, output: HandlingOutput, func_array: Array[Callable]):
	var updated_mask := 0
	for f in func_array:
		extend(f).call(state, output)
		updated_mask |= output.updated

func process(state: HandlingState, output: HandlingOutput) -> void:
	output.linear_velocity = state.linear_velocity
	output.angular_velocity = state.angular_velocity
	output.gear = state.gear
	output.rpm = state.rpm
	output.current_steering = state.current_steering
	output.lost_grip = state.lost_grip
	output.handbrake_accumulator = state.handbrake_accumulator
	output.force = state.force
	output.gear_shift_counter = state.gear_shift_counter
	output.shifted_down = state.shifted_down
	output.g_transfer = state.g_transfer
	output.throttle = state.throttle
	output.brake = state.brake
	output.has_contact_with_ground = state.has_contact_with_ground
	output.updated = (HandlingOutput.F_LINEAR_VELOCITY | HandlingOutput.F_ANGULAR_VELOCITY |
		HandlingOutput.F_GEAR | HandlingOutput.F_RPM | HandlingOutput.F_CURRENT_STEERING |
		HandlingOutput.F_LOST_GRIP | HandlingOutput.F_HANDBRAKE_ACCUMULATOR |
		HandlingOutput.F_FORCE | HandlingOutput.F_GEAR_SHIFT_COUNTER |
		HandlingOutput.F_SHIFTED_DOWN | HandlingOutput.F_G_TRANSFER |
		HandlingOutput.F_THROTTLE | HandlingOutput.F_BRAKE |
		HandlingOutput.F_HAS_CONTACT_WITH_GROUND)
