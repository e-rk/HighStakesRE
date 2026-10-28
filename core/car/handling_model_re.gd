extends HandlingModel
class_name HandlingModelRE


class TractionState:
	var performance: CarPerformance
	var rpm: int
	var lost_grip: bool
	var throttle: float
	var brake: float
	var speed_xz: float
	var linear_velocity: Vector3
	var shifted_down: bool
	var gear: CarTypes.Gear
	var has_contact_with_ground: bool
	var gear_shift_counter: int
	var handbrake_accumulator: int
	var rpm_above_redline: bool
	var target_rpm: int
	var drag: float
	var force: float
	var slip_angle: float
	var weather: int
	var drivetrain_overload: bool
	var engine_damage: float
	var automatic_gearbox: bool
	var engine_wear: float


class TractionOutput:
	const F_RPM                 = 1 << 0
	const F_HANDBRAKE_ACCUMULATOR = 1 << 1
	const F_GEAR                = 1 << 2
	const F_RPM_ABOVE_REDLINE   = 1 << 3
	const F_TARGET_RPM          = 1 << 4
	const F_FORCE               = 1 << 5
	const F_LOST_GRIP           = 1 << 6
	const F_DRIVETRAIN_OVERLOAD = 1 << 7
	const F_ENGINE_WEAR         = 1 << 8

	var updated: int = 0

	var rpm: int
	var handbrake_accumulator: int
	var gear: CarTypes.Gear
	var rpm_above_redline: bool
	var target_rpm: int
	var force: float
	var lost_grip: bool
	var drivetrain_overload: bool
	var engine_damage: float


class WheelData:
	var type: CarTypes.Wheel
	var road_surface: int
	var grip: float
	var traction: float
	var downforce: float
	var handbrake_accumulator: int


const SURFACE_FACTORS: Array[float] = [
	1.0, 1.0, 0.75, 0.8, 0.98, 0.8, 0.75, 0.95,
	0.75, 0.75, 0.98, 0.95, 0.95, 0.8, 1.0, 0.75,
	0.98, 0.98, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8,
	1.0, 0.87, 0.75, 1.0, 0.87, 0.75, 0.75, 0.6525,
]

const SURFACE_FRICTION: Array[float] = [
	1.0, 0.98, 0.93, 0.9, 0.98, 0.9, 0.51, 0.95,
	0.95, 0.87, 0.98, 0.98, 0.95, 0.9, 1.0, 0.87,
	0.98, 0.98, 0.98, 0.98, 0.98, 0.98, 0.98, 0.98,
	1.0, 0.87, 0.75, 1.0, 0.87, 0.75, 1.0, 0.87,
]


static func round_half_even(value: float) -> int:
	var result := roundf(value)
	if absf(value - result) == 0.5 and fmod(result, 2.0) != 0.0:
		result -= signf(value)
	return int(result)


class CollisionParams:
	var basis: Basis
	var position: Vector3
	var linear_velocity: Vector3
	var angular_velocity: Vector3
	var inertia_inv: Vector3
	var mass: float
	var friction: float


class CollisionOutput:
	var position: Vector3
	var linear_velocity: Vector3
	var angular_velocity: Vector3
	var collided: bool


func torque_for_rpm(performance: CarPerformance, rpm: int) -> float:
	var torque_curve := performance.torque_curve
	var torque_div := clampf(rpm / 500.0, 0.0, 20.0)
	var torque_idx := mini(floori(torque_div), 19)
	var torque_next := torque_idx + 1
	var torque_1 := torque_curve[torque_idx]
	var torque_2 := torque_curve[torque_next]
	var factor := torque_div - torque_idx
	return lerp(torque_1, torque_2, factor)


func gear_effective_ratio(performance: CarPerformance, gear: CarTypes.Gear) -> float:
	var velocity_to_rpm := performance.gear_velocity_to_rpm(gear)
	var gear_efficiency := performance.gear_efficiency(gear)
	var mass := performance.mass
	return velocity_to_rpm * gear_efficiency / (10 * mass)


func traction_powertrain(state: TractionState, rpm: int) -> float:
	const ENGINE_DAMAGE_INFLUENCE := 0.25
	var gear := state.gear
	var torque := torque_for_rpm(state.performance, rpm)
	torque *= 1.0 - state.engine_damage * ENGINE_DAMAGE_INFLUENCE
	var gear_ratio := self.gear_effective_ratio(state.performance, gear)
	var torque_output := torque * gear_ratio
	if gear == CarTypes.Gear.GEAR_1:
		torque_output = minf(torque_output, 10)
	elif gear == CarTypes.Gear.REVERSE:
		torque_output = maxf(torque_output, -6)
	else:
		torque_output = minf(torque_output, 8)
	return torque_output


func longitudal_drag_coefficient(params: HandlingState) -> float:
	const COEFF1 = 3.0 / 2.0
	const COEFF2 = 0.98
	const COEFF3 = 0.36757159
	var performance: CarPerformance = params.performance
	var max_gear := performance.max_gear()
	var max_velocity := performance.max_velocity()
	var velocity_to_rpm := performance.gear_velocity_to_rpm(max_gear)
	var rpm_for_max_speed := velocity_to_rpm * max_velocity
	var rpm_idx := round_half_even(rpm_for_max_speed) / 500
	var torque_curve := performance.torque_curve
	var torque_for_max_speed := torque_curve[rpm_idx]
	var mass := performance.mass
	var result := torque_for_max_speed * velocity_to_rpm / (10 * mass)
	result = COEFF1 * result * COEFF2 / (max_velocity ** 3 * COEFF3)
	return result


func drag(params: HandlingState) -> float:
	const BODY_DAMAGE_DRAG := 0.5
	const DRAG_INIT = 0.2450477
	var basis: Basis = params.basis_to_road
	var linear_velocity: Vector3 = params.linear_velocity
	var performance: CarPerformance = params.performance
	var velocity_local := basis.transposed() * linear_velocity
	var coefficient := self.longitudal_drag_coefficient(params)
	coefficient *= params.body_damage * BODY_DAMAGE_DRAG + 1.0
	var result := DRAG_INIT * coefficient
	var velocity_max_diff := absf(velocity_local.z) - performance.max_velocity()
	result = result * velocity_local.z ** 3
	if velocity_max_diff > 0:
		result += (velocity_max_diff ** 2) * 0.01
	return result

func gear_rpm_to_velocity(performance: CarPerformance, gear: CarTypes.Gear) -> float:
	return 1.0 / performance.gear_velocity_to_rpm(gear)

func get_lost_grip(state: HandlingState) -> bool:
	return state.handbrake || state.lost_grip

func prepare_traction_model_ctx(state: HandlingState) -> TractionState:
	var basis := state.basis_to_road
	var linear_velocity := state.linear_velocity
	var velocity_local := basis.transposed() * linear_velocity
	var ts := TractionState.new()
	ts.performance = state.performance
	ts.rpm = state.rpm
	ts.lost_grip = state.handbrake
	ts.throttle = state.throttle
	ts.brake = state.brake
	ts.speed_xz = state.speed_xz
	ts.linear_velocity = velocity_local
	ts.shifted_down = state.shifted_down
	ts.gear = state.gear
	ts.has_contact_with_ground = state.has_contact_with_ground
	ts.gear_shift_counter = state.gear_shift_counter
	ts.handbrake_accumulator = state.handbrake_accumulator
	ts.rpm_above_redline = false
	ts.target_rpm = 0
	ts.drag = self.drag(state)
	ts.force = 0.0
	ts.slip_angle = state.slip_angle
	ts.weather = state.weather
	ts.drivetrain_overload = false
	ts.engine_damage = state.engine_damage
	ts.automatic_gearbox = state.automatic_gearbox
	return ts

func traction_model_extend(f: Callable) -> Callable:
	return func(state: TractionState, output: TractionOutput) -> void:
		output.updated = 0
		f.call(state, output)
		if output.updated & TractionOutput.F_RPM:
			state.rpm = output.rpm
		if output.updated & TractionOutput.F_HANDBRAKE_ACCUMULATOR:
			state.handbrake_accumulator = output.handbrake_accumulator
		if output.updated & TractionOutput.F_GEAR:
			state.gear = output.gear
		if output.updated & TractionOutput.F_RPM_ABOVE_REDLINE:
			state.rpm_above_redline = output.rpm_above_redline
		if output.updated & TractionOutput.F_TARGET_RPM:
			state.target_rpm = output.target_rpm
		if output.updated & TractionOutput.F_FORCE:
			state.force = output.force
		if output.updated & TractionOutput.F_LOST_GRIP:
			state.lost_grip = output.lost_grip
		if output.updated & TractionOutput.F_DRIVETRAIN_OVERLOAD:
			state.drivetrain_overload = output.drivetrain_overload
		if output.updated & TractionOutput.F_ENGINE_WEAR:
			state.engine_damage = output.engine_damage

func make_traction_model_pipeline(func_array: Array) -> Callable:
	return func(state: TractionState, output: TractionOutput) -> void:
		for f in func_array:
			traction_model_extend(f).call(state, output)

func traction_either(predicate: Callable, true_f: Callable, false_f: Callable) -> Callable:
	return func(state: TractionState, output: TractionOutput) -> void:
		if predicate.call(state):
			true_f.call(state, output)
		else:
			false_f.call(state, output)
		output.updated = 0

func traction_model_branch(state: TractionState) -> bool:
	var gear := state.gear
	var gear_shift_counter := state.gear_shift_counter
	var has_contact_with_ground := state.has_contact_with_ground
	return gear != CarTypes.Gear.NEUTRAL and has_contact_with_ground and not gear_shift_counter

func traction_model(state: HandlingState, output: HandlingOutput) -> void:
	var ts := self.prepare_traction_model_ctx(state)
	var to := TractionOutput.new()
	var true_branch: Callable = self.make_traction_model_pipeline([
		traction_model_limit_gear_when_low_velocity,
		traction_model_force,
		traction_model_low_engine_rpm
	])
	var false_branch: Callable = self.make_traction_model_pipeline([
		traction_model_airborne_target_rpm,
		traction_model_rpm_adjust,
	])
	var pipeline: Callable = make_traction_model_pipeline([
		traction_model_rpm_above_redline,
		traction_model_target_rpm,
		traction_either(traction_model_branch, true_branch, false_branch),
		traction_model_postprocess,
	])
	pipeline.call(ts, to)
	output.updated = (HandlingOutput.F_RPM | HandlingOutput.F_FORCE | HandlingOutput.F_LOST_GRIP
		| HandlingOutput.F_HANDBRAKE_ACCUMULATOR | HandlingOutput.F_GEAR
		| HandlingOutput.F_DRIVETRAIN_OVERLOAD | HandlingOutput.F_ENGINE_WEAR)
	output.rpm = ts.rpm
	output.force = ts.force
	output.lost_grip = ts.lost_grip
	output.handbrake_accumulator = ts.handbrake_accumulator
	output.gear = ts.gear
	output.drivetrain_overload = ts.drivetrain_overload
	output.engine_damage = ts.engine_damage

func traction_model_rpm_above_redline(state: TractionState, output: TractionOutput) -> void:
	var performance := state.performance
	var rpm := state.rpm
	var lost_grip := state.lost_grip
	var engine_redline_rpm := performance.engine_redline_rpm
	var above_redline := false
	if engine_redline_rpm < rpm:
		above_redline = true
	if (4 * engine_redline_rpm / 3) < rpm:
		lost_grip = true
	rpm = mini(rpm, engine_redline_rpm)
	output.updated = TractionOutput.F_RPM | TractionOutput.F_LOST_GRIP | TractionOutput.F_RPM_ABOVE_REDLINE
	output.rpm = rpm
	output.lost_grip = lost_grip
	output.rpm_above_redline = above_redline

func traction_model_target_rpm(state: TractionState, output: TractionOutput) -> void:
	var performance := state.performance
	var throttle := state.throttle
	var engine_redline_rpm := performance.engine_redline_rpm
	var engine_min_rpm := performance.engine_min_rpm()
	var target_rpm := floori(clamp(engine_redline_rpm * throttle, engine_min_rpm, engine_redline_rpm))
	output.updated = TractionOutput.F_TARGET_RPM
	output.target_rpm = target_rpm

func traction_model_limit_gear_when_low_velocity(state: TractionState, output: TractionOutput) -> void:
	var performance := state.performance
	var gear := state.gear
	var velocity_local := state.linear_velocity
	var engine_redline_rpm := performance.engine_redline_rpm
	var rpm_to_velocity_ratio := self.gear_rpm_to_velocity(state.performance, CarTypes.Gear.GEAR_1)
	var max_velocity_at_lowest_gear := engine_redline_rpm * rpm_to_velocity_ratio
	if velocity_local.z < max_velocity_at_lowest_gear and CarTypes.Gear.GEAR_3 < gear:
		gear = CarTypes.Gear.GEAR_3
	output.updated = TractionOutput.F_GEAR
	output.gear = gear

func rpm_from_velocity(state: TractionState) -> float:
	var performance := state.performance
	var gear := state.gear
	var velocity_local := state.linear_velocity
	var velocity_to_rpm := performance.gear_velocity_to_rpm(gear) * Vector3.ONE
	return (velocity_local * velocity_to_rpm).z

func rpm_from_velocity_rounded(state: TractionState) -> int:
	return round_half_even(self.rpm_from_velocity(state))

func traction_model_force(state: TractionState, output: TractionOutput) -> void:
	const ENGINE_WEAR_SPIN := 0.03
	const ENGINE_WEAR_OVER_REV := 0.01
	var performance := state.performance
	var rpm := state.rpm
	var target_rpm := state.target_rpm
	var gear_shift_counter := state.gear_shift_counter
	var gear := state.gear
	var speed_xz := state.speed_xz
	var throttle := state.throttle
	var velocity_local := state.linear_velocity
	var above_redline := state.rpm_above_redline
	var handbrake_accumulator := state.handbrake_accumulator
	var lost_grip := state.lost_grip
	var slip_angle := state.slip_angle
	var drag_factor := state.drag
	var engine_redline_rpm := performance.engine_redline_rpm
	var engine_min_rpm := performance.engine_min_rpm()

	rpm = mini(engine_redline_rpm, rpm)
	var force := self.traction_powertrain(state, rpm)

	var current_rpm_from_velocity := absi(self.rpm_from_velocity_rounded(state))
	var rpm_target_wheels_diff := target_rpm - current_rpm_from_velocity
	if abs(rpm_target_wheels_diff) < 500 and target_rpm < (engine_redline_rpm - 300):
		rpm_target_wheels_diff = 0
	var rpm_diff := rpm - current_rpm_from_velocity
	var rpm_diff_to_big := (engine_redline_rpm / 6) < rpm_diff and gear_shift_counter == 0 and gear < CarTypes.Gear.GEAR_4
	var going_in_reverse_dir := CarTypes.Gear.NEUTRAL < gear and speed_xz < -0.3 and (8 / 255.0) < throttle \
							 or CarTypes.Gear.REVERSE == gear and speed_xz > 0.3 and (8 / 255.0) < throttle
	var drivetrain_overload := false
	var engine_wear := 0.0
	if rpm_diff_to_big or going_in_reverse_dir:
		drivetrain_overload = true
		if going_in_reverse_dir:
			engine_wear = self.engine_wear(state, rpm, ENGINE_WEAR_SPIN)
		var rpm_adjust := 125
		const adjust_by_gear = [50, 50, 10, 15, 20, 22, 50, 50]
		if target_rpm >= 2000:
			rpm_adjust = adjust_by_gear[gear]
		rpm -= min(rpm_adjust, rpm_diff)
	elif rpm_target_wheels_diff < 0:
		force = -force * performance.gas_off_factor
		if gear < CarTypes.Gear.NEUTRAL or 0 <= velocity_local.z:
			if gear == CarTypes.Gear.REVERSE and 0 < velocity_local.z:
				force = -abs(force)
		else:
			force = abs(force)
		var rpm_adjust := floori(self.gear_rpm_to_velocity(state.performance, gear) * 8 * 10240.0)
		rpm += min(rpm_adjust, -rpm_diff)
		if not above_redline:
			rpm = max(target_rpm, rpm, engine_min_rpm)
		else:
			rpm = engine_redline_rpm
		var velocity_redline := engine_redline_rpm * self.gear_rpm_to_velocity(state.performance, gear) * 1.15
		if (abs(velocity_local.z) <= velocity_redline) or gear < CarTypes.Gear.GEAR_1:
			if not lost_grip:
				handbrake_accumulator = 0
		else:
			drivetrain_overload = true
			if not state.automatic_gearbox:
				engine_wear = self.engine_wear(state, rpm, ENGINE_WEAR_OVER_REV)
			velocity_redline = engine_redline_rpm * self.gear_rpm_to_velocity(state.performance, gear)
			force = (velocity_redline / abs(velocity_local.z)) * force
			lost_grip = true
			handbrake_accumulator = self.increment_handbrake_accumulator(state.handbrake_accumulator, state.weather)
	elif rpm_target_wheels_diff == 0:
		rpm = max(current_rpm_from_velocity, engine_min_rpm)
		force = drag_factor
	else:
		if rpm_diff <= 200:
			if rpm_diff < -300:
				rpm += 40
			else:
				rpm = max(current_rpm_from_velocity, engine_min_rpm)
		else:
			rpm -= 40
		rpm = max(min(target_rpm, rpm), engine_min_rpm)
		var slip_factor := absf(slip_angle) * 0.6 + 1.0
		slip_factor = min(slip_factor, 1.5)
		force = force * throttle * slip_factor
	output.updated = (TractionOutput.F_FORCE | TractionOutput.F_HANDBRAKE_ACCUMULATOR
		| TractionOutput.F_RPM | TractionOutput.F_LOST_GRIP | TractionOutput.F_DRIVETRAIN_OVERLOAD
		| TractionOutput.F_ENGINE_WEAR)
	output.force = force
	output.handbrake_accumulator = handbrake_accumulator
	output.rpm = rpm
	output.lost_grip = lost_grip
	output.drivetrain_overload = drivetrain_overload
	output.engine_damage = state.engine_damage + engine_wear

func engine_wear(state: TractionState, rpm: int, rate: float) -> float:
	const ENGINE_WEAR_RPM_PERCENT := 95
	const ENGINE_WEAR_SCALE := 0.03125
	var limit := state.performance.engine_redline_rpm * ENGINE_WEAR_RPM_PERCENT / 100
	if state.gear == CarTypes.Gear.NEUTRAL or rpm <= limit:
		return 0.0
	return rate * (float(rpm) / limit) * ENGINE_WEAR_SCALE

func traction_model_low_engine_rpm(state: TractionState, output: TractionOutput) -> void:
	var performance := state.performance
	var rpm := state.rpm
	var force := state.force
	var drivetrain_overload := state.drivetrain_overload
	var engine_min_rpm := performance.engine_min_rpm()
	if rpm < engine_min_rpm:
		force = self.traction_powertrain(state, engine_min_rpm)
		rpm = engine_min_rpm
		drivetrain_overload = false
	output.updated = TractionOutput.F_RPM | TractionOutput.F_FORCE | TractionOutput.F_DRIVETRAIN_OVERLOAD
	output.rpm = rpm
	output.force = force
	output.drivetrain_overload = drivetrain_overload

func traction_model_airborne_target_rpm(state: TractionState, output: TractionOutput) -> void:
	var performance := state.performance
	var has_contact_with_ground := state.has_contact_with_ground
	var target_rpm := state.target_rpm
	if not has_contact_with_ground:
		target_rpm += performance.shift_blip_in_rpm[CarTypes.Gear.GEAR_1]
	output.updated = TractionOutput.F_TARGET_RPM
	output.target_rpm = target_rpm

func traction_model_rpm_adjust(state: TractionState, output: TractionOutput) -> void:
	var performance := state.performance
	var rpm := state.rpm
	var target_rpm := state.target_rpm
	var gear_shift_counter := state.gear_shift_counter
	var throttle := state.throttle
	var brake := state.brake
	var above_redline := state.rpm_above_redline
	var shifted_down := state.shifted_down
	var gear := state.gear
	var engine_redline_rpm := performance.engine_redline_rpm
	var engine_min_rpm := performance.engine_min_rpm()
	if rpm < target_rpm and gear_shift_counter == 0:
		rpm += 250
		target_rpm = min(rpm, target_rpm)
		target_rpm = max(target_rpm, engine_min_rpm)
		rpm = target_rpm
	else:
		if gear_shift_counter == 0:
			if not (rpm < target_rpm):
				rpm -= 150
				rpm = max(target_rpm, rpm, engine_min_rpm)
		elif not shifted_down:
			var rpm_adjust := -50
			# Missing spoiler type
			if performance.gear_shift_delay < 5:
				rpm_adjust = -75
			if above_redline:
				rpm_adjust *= 2
			rpm -= rpm_adjust
			rpm = max(rpm, engine_min_rpm)
		else:
			if 0 < throttle:
				var rpm_adjust = performance.brake_blip_in_rpm[gear]
				if brake < (65.0 / 255.0):
					rpm_adjust = performance.shift_blip_in_rpm[gear]
				rpm += rpm_adjust
			rpm = clamp(rpm, engine_min_rpm, engine_redline_rpm)
	output.updated = TractionOutput.F_RPM
	output.rpm = rpm

func traction_model_postprocess(state: TractionState, output: TractionOutput) -> void:
	var has_contact_with_ground := state.has_contact_with_ground
	var velocity_local := state.linear_velocity
	var drag_factor := state.drag
	var force := state.force
	if has_contact_with_ground:
		if 0.0 < velocity_local.z:
			force = force - drag_factor
		else:
			force = drag_factor * 2.0 + force
	elif 0.0 <= velocity_local.z:
		force = -drag_factor * 0.5
	else:
		force = drag_factor
	output.updated = TractionOutput.F_FORCE
	output.force = force

func calculate_speed_xz(state: HandlingState) -> float:
	var basis := state.basis_to_road
	var linear_velocity := state.linear_velocity
	var velocity_xz := basis.transposed() * linear_velocity
	velocity_xz.y = 0
	var speed_xz := velocity_xz.length()
	return speed_xz if velocity_xz.z > 0 else -speed_xz


func angular_velocity_factor(state: HandlingState) -> float:
	const SOME_FACTOR = 0.0125
	const SOME_OFFSET = -0.25
	const UPPER_LIMIT = 1
	const LOWER_LIMIT = 0.1
	var result := 0.0
	if state.has_contact_with_ground:
		var angular_velocity := state.angular_velocity
		var inertia_inv := state.inertia_inv
		var mass := state.mass
		var gear := state.gear
		var speed_xz := absf(state.speed_xz)
		var velocity_factor := speed_xz * SOME_FACTOR + SOME_OFFSET
		velocity_factor = clampf(velocity_factor, LOWER_LIMIT, UPPER_LIMIT)
		var ang_vel := absf(angular_velocity.y)
		result = -velocity_factor * ang_vel * 32 * mass * inertia_inv.y
		if gear == CarTypes.Gear.REVERSE:
			result /= 2
	return -result


func wheel_planar_vector(state: HandlingState, wheel_data: WheelData) -> Vector3:
	var basis: Basis = state.basis_to_road
	var linear_velocity: Vector3 = state.linear_velocity
	var velocity_local := basis.transposed() * linear_velocity
	var planar_vector := -0.5 * velocity_local * 32
	var angular_velocity_fact := self.angular_velocity_factor(state)
	match wheel_data.type:
		CarTypes.Wheel.FRONT_RIGHT, CarTypes.Wheel.FRONT_LEFT:
			planar_vector.x += angular_velocity_fact
		CarTypes.Wheel.REAR_RIGHT, CarTypes.Wheel.REAR_LEFT:
			planar_vector.x -= angular_velocity_fact
	planar_vector.y = 0
	return planar_vector


func vehicle_slip_angle_tg(state: HandlingState) -> float:
	const VELOCITY_LONGITUDAL_THRESHOLD = 5.0
	var basis := state.basis_to_road
	var linear_velocity := state.linear_velocity
	var velocity_local := basis.transposed() * linear_velocity
	var result := 0.0
	if VELOCITY_LONGITUDAL_THRESHOLD < abs(velocity_local.z):
		result = velocity_local.x / velocity_local.z
	return result


func vehicle_slip_angle(state: HandlingState) -> float:
	return state.slip_angle


func slip_angle_factor(state: HandlingState) -> float:
	const MEDIUM_VELOCITY_THRESHOLD = 13.4
	const HIGH_VELOCITY_THRESHOLD = 26.7
	const MEDIUM_VELOCITY_SLIP_ANGLE_THRESHOLD = 0.15
	const HIGH_VELOCITY_SLIP_ANGLE_THRESHOLD = 0.05
	var steering := state.current_steering
	var basis := state.basis_to_road
	var linear_velocity := state.linear_velocity
	var velocity_local := basis.transposed() * linear_velocity
	var slip_angle := self.vehicle_slip_angle(state)
	var is_same_dir := (slip_angle * steering) >= 0
	var result := 1.0
	if state.handbrake == false and is_same_dir:
		if HIGH_VELOCITY_THRESHOLD < velocity_local.z:
			if HIGH_VELOCITY_SLIP_ANGLE_THRESHOLD < abs(slip_angle):
				result = 2 * abs(slip_angle)
		elif MEDIUM_VELOCITY_THRESHOLD < velocity_local.z:
			if MEDIUM_VELOCITY_SLIP_ANGLE_THRESHOLD < abs(slip_angle):
				result = 2 * abs(slip_angle)
		result = min(1.0, result)
	elif state.handbrake == true and !is_same_dir:
		result = 0.85 - abs(velocity_local.z) * 0.0056
		result = max(result, 0.55)
	return result


func steering_angle(state: HandlingState, output: HandlingOutput) -> void:
	if !state.has_contact_with_ground:
		output.updated = HandlingOutput.F_STEERING
		output.steering = 0.0
		return
	var result := 0.0
	var steering := state.current_steering
	var basis := state.basis_to_road
	var linear_velocity := state.linear_velocity
	var performance := state.performance
	var velocity_local := basis.transposed() * linear_velocity
	var slip_angle_fact := self.slip_angle_factor(state)
	var steering_accel := performance.minimum_steering_acceleration
	steering *= self.steering_damage_factor(state)
	steering *= slip_angle_fact
	if 40.0 < abs(velocity_local.z):
		var velocity_factor := 0.015 * absf(velocity_local.z)
		velocity_factor = clamp(velocity_factor, 1, 1.5)
		steering = steering / velocity_factor
	result = steering_accel * 1.5 * 0.00277777777 * steering * 0.0078125
	result = clamp(result, -1.0, 1.0)
	output.updated = HandlingOutput.F_STEERING
	output.steering = result


func steering_damage_factor(state: HandlingState) -> float:
	const STEERING_DAMAGE_INFLUENCE := 0.5 * 0.25
	var damage := state.steering_damage
	if 0.0 < state.current_steering:
		return 1.0 - (damage[1] + damage[3]) * STEERING_DAMAGE_INFLUENCE
	if state.current_steering < 0.0:
		return 1.0 - (damage[0] + damage[2]) * STEERING_DAMAGE_INFLUENCE
	return 1.0


func suspension_damage_factor(state: HandlingState, wheel_data: WheelData) -> float:
	const SUSPENSION_DAMAGE_INFLUENCE := 0.25
	return 1.0 - state.suspension_damage[wheel_data.type] * SUSPENSION_DAMAGE_INFLUENCE


func turning_circle(
	state: HandlingState, local_angular_velocity: Vector3, velocity_local: Vector3
) -> Dictionary:
	var performance := state.performance
	var steering := state.current_steering
	var throttle := state.throttle
	var brake := state.brake
	var gear := state.gear
	var slip_angle := self.vehicle_slip_angle(state)
	var turning_radius := performance.turning_circle_radius
	var result_angular_velocity := local_angular_velocity
	var result_linear_velocity := state.linear_velocity
	if throttle < 0.5 or brake < 0.75 or abs(steering) <= 64 or 5 < abs(velocity_local.z):
		if abs(steering) < 4 and gear == CarTypes.Gear.REVERSE:
			result_angular_velocity.y *= 0.95
	else:
		result_angular_velocity.y = 0
	if absf(velocity_local.z) <= absf(velocity_local.x):
		if absf(velocity_local.z) < absf(velocity_local.x) and velocity_local.length() < 2.0:
			var factor := absf(result_angular_velocity.y) * TAU * turning_radius * 0.5
			if factor <= abs(velocity_local.z) or factor <= abs(velocity_local.x):
				if 0.2 <= abs(slip_angle):
					factor = 0.95 * result_angular_velocity.y
				else:
					factor = 0.90 * result_angular_velocity.y
			else:
				var f := absf(velocity_local.z) / factor
				f = minf(f, 0.98)
				factor = result_angular_velocity.y * f
			result_angular_velocity.y = factor
			var velocity_factor := 0.8
			if absf(velocity_local.z) < 5.0:
				velocity_factor = 0.7
			result_linear_velocity *= velocity_factor
	else:
		var factor := absf(result_angular_velocity.y) * TAU * turning_radius * 0.5
		if factor <= absf(velocity_local.z) or factor <= absf(velocity_local.x):
			if abs(slip_angle) < 0.2:
				result_angular_velocity.y *= 0.95
			else:
				result_angular_velocity.y *= 0.99
		else:
			var f := absf(velocity_local.z) / factor
			f = minf(f, 0.98)
			factor = result_angular_velocity.y * f
			result_angular_velocity.y = factor
	return {
		"angular_velocity": result_angular_velocity,
		"linear_velocity": result_linear_velocity,
	}


func tire_factor(state: HandlingState) -> float:
	var tire_tuning := 1.0
	var weather := state.weather
	var result: float
	if weather == 0:
		result = 28.0 - (tire_tuning - 0.8) * 40
		result = 1 / max(16.0, result)
	elif weather == 1:
		result = 16.0 - (tire_tuning - 0.8) * 32
		result = 3.0 / max(6.0, result)
	elif weather == 2:
		result = 12.0 - (tire_tuning - 0.8) * 24
		result = 3.0 / max(4.0, result)
	return result


func steering_acceleration(
	state: HandlingState, wheel_data: WheelData, planar_vector: Vector3
) -> float:
	var grip := wheel_data.grip
	var angle := atan2(planar_vector.x, abs(planar_vector.z))
	var grip_loss := grip - grip * tire_factor(state)
	var value := 0.0
	if is_gear_reverse(state):
		value = sin(angle / 2) * grip_loss * 2.0
	else:
		value = sin(angle / 2) * grip_loss * 4.0
	return value


func vector_rotate_y(v: Vector3, angle: float) -> Vector3:
	return v.rotated(Vector3.UP, angle * TAU)


func turned_steering_acceleration(state: HandlingState, wheel_data: WheelData, planar_vector: Vector3) -> float:
	return steering_acceleration(state, wheel_data, planar_vector)


func g_transfer_damp(state: HandlingState) -> float:
	var factor := state.g_transfer
	var weather := state.weather
	var wet := weather == CarTypes.Weather.RAIN or weather == CarTypes.Weather.SNOW
	if factor < 0.0:
		factor *= 0.75
		if wet:
			factor *= 1.1
	elif factor > 0.0:
		if state.drivetrain_overload:
			factor *= 0.5
		if wet:
			factor *= 0.9
	return factor


func wheel_downforce_factor(state: HandlingState, wheel_data: WheelData) -> float:
	const DOWNFORCE_THRESHOLD_SPEED = 10.0
	const BODY_DAMAGE_WHEEL_DOWNFORCE := 0.5
	var basis := state.basis_to_road
	var linear_velocity := state.linear_velocity
	var velocity_local := basis.transposed() * linear_velocity
	var performance := state.performance
	var brake := state.brake
	var downforce := (1.0 - state.body_damage * BODY_DAMAGE_WHEEL_DOWNFORCE) * performance.downforce_mult()
	if abs(velocity_local.z) <= DOWNFORCE_THRESHOLD_SPEED:
		return downforce + 1.0
	downforce = velocity_local.z * downforce
	var rear_factor := 1.5
	if 0.15 < brake and performance.has_spoiler():
		rear_factor = 1.75
	match wheel_data.type:
		CarTypes.Wheel.FRONT_RIGHT, CarTypes.Wheel.FRONT_LEFT:
			downforce += 1.0
		CarTypes.Wheel.REAR_RIGHT, CarTypes.Wheel.REAR_LEFT:
			downforce = downforce * rear_factor + 1.0
	return downforce


func longitudal_acceleration(
	state: HandlingState, wheel_data: WheelData, wheel_vector: Vector3
) -> Array:
	var performance := state.performance
	var traction := wheel_data.traction
	var throttle := state.throttle
	var lateral_grip_mult := performance.lateral_grip_multiplier()
	var traction_loss := false
	if 0.0 <= traction or 0.0 <= wheel_vector.z:
		if (
			0.0 < traction
			and 0.0 < wheel_vector.z
			and (throttle <= 0.25 or state.gear == CarTypes.Gear.REVERSE or state.gear == CarTypes.Gear.NEUTRAL)
		):
			traction = min(traction, wheel_vector.z)
			traction_loss = true
	elif throttle <= 0.25 or not is_gear_reverse(state):
		traction = max(traction, wheel_vector.z)
		traction_loss = true
	traction = traction * lateral_grip_mult
	return [traction, traction_loss]


func orientation_to_ground(basis_to_road: Basis, basis: Basis) -> Vector3:
	var normal := basis_to_road.y
	var x := basis.x.dot(normal)
	var y := basis.y.dot(normal)
	var z := basis.z.dot(normal)
	return Vector3(x, y, z)


func road_normal_y(state: HandlingState) -> float:
	return state.basis_to_road.y.y


func wheel_slope_vector(state: HandlingState, vector: Vector3) -> Vector3:
	return vector * self.road_normal_y(state)


func wheel_forces_to_linear_acceleration(state: HandlingState, forces: Array) -> Vector3:
	var sloped: Array = forces.map(func(x): return wheel_slope_vector(state, x))
	var result: Vector3 = 0.5 * sloped.reduce(func(a, x): return a + x)
	return result


func wheel_forces_to_angular_acceleration(state: HandlingState, forces: Array) -> Vector3:
	var mass := state.mass
	var inertia_inv := state.inertia_inv
	var timestep := state.timestep
	var sloped: Array = forces.map(func(x): return wheel_slope_vector(state, x))
	var ang_accel_y: float = (
		((sloped[0].x + sloped[1].x) - (sloped[2].x + sloped[3].x))
		* 0.5
		* 4
		* mass
		* inertia_inv.y
		* timestep
	)
	return Vector3(0, ang_accel_y, 0)


func weather_factor(weather: int) -> float:
	const FACTORS = [1.0, 0.9, 0.8]
	return FACTORS[weather]


func wheel_surface_grip_factor(state: HandlingState, wheel_data: WheelData) -> float:
	var road_surface := wheel_data.road_surface
	var slope := clampf(self.road_normal_y(state), 0.75, 1.0)
	var wheel_road_factor := (SURFACE_FACTORS[road_surface] + 1.0) * 0.5
	var wheel_weather_factor := self.weather_factor(state.weather)
	var effective_weather_factor := slope * wheel_road_factor * wheel_weather_factor * 0.25
	return (effective_weather_factor + slope) * wheel_road_factor


func wheel_base_road_grip(state: HandlingState, surface_grip: float) -> float:
	var basis := state.basis_to_road
	var performance := state.performance
	var gravity := basis.transposed() * state.gravity_vector
	var lateral_grip_mult := performance.lateral_grip_multiplier()
	return -gravity.y * lateral_grip_mult * surface_grip


func wheel_bias_grip(state: HandlingState, wheel_data: WheelData, grip: float) -> float:
	var performance := state.performance
	var front_grip_bias := performance.front_grip_bias
	var rear_grip_bias := 1.0 - front_grip_bias
	var result := 0.0
	match wheel_data.type:
		CarTypes.Wheel.FRONT_RIGHT, CarTypes.Wheel.FRONT_LEFT:
			result = grip * front_grip_bias
		CarTypes.Wheel.REAR_RIGHT, CarTypes.Wheel.REAR_LEFT:
			result = grip * rear_grip_bias
	return result


func wheel_downforce_grip(state: HandlingState, wheel_data: WheelData, base_grip: float, grip: float) -> float:
	var downforce := self.wheel_downforce_factor(state, wheel_data)
	var g_transfer := self.g_transfer_damp(state)
	var result := 0.0
	match wheel_data.type:
		CarTypes.Wheel.FRONT_RIGHT, CarTypes.Wheel.FRONT_LEFT:
			result = (grip - g_transfer) * downforce
		CarTypes.Wheel.REAR_RIGHT, CarTypes.Wheel.REAR_LEFT:
			result = (base_grip - grip + g_transfer) * downforce
	return result


func model_wheel_grip(state: HandlingState, wheel_data: WheelData) -> float:
	var surface_grip := self.wheel_surface_grip_factor(state, wheel_data)
	var base_grip := self.wheel_base_road_grip(state, surface_grip)
	base_grip *= self.suspension_damage_factor(state, wheel_data)
	var biased_grip := self.wheel_bias_grip(state, wheel_data, base_grip)
	var downforce_grip := self.wheel_downforce_grip(state, wheel_data, base_grip, biased_grip)
	return downforce_grip


func wheel_traction(state: HandlingState, wheel_data: WheelData) -> float:
	var traction := state.force
	var performance := state.performance
	var front_drive_ratio := performance.front_drive_ratio
	var rear_drive_ratio := 1.0 - front_drive_ratio
	match wheel_data.type:
		CarTypes.Wheel.FRONT_RIGHT, CarTypes.Wheel.FRONT_LEFT:
			traction *= front_drive_ratio
		CarTypes.Wheel.REAR_RIGHT, CarTypes.Wheel.REAR_LEFT:
			traction *= rear_drive_ratio
	var brake := self.brake_force(state, wheel_data)
	return self.suspension_damage_factor(state, wheel_data) * (traction - brake)


func calculate_wheel_data(state: HandlingState, wheel: Dictionary) -> WheelData:
	var wd := WheelData.new()
	wd.type = wheel["type"]
	wd.road_surface = wheel["road_surface"]
	wd.grip = self.model_wheel_grip(state, wd)
	wd.traction = self.wheel_traction(state, wd)
	wd.downforce = self.wheel_downforce_factor(state, wd)
	return wd


func road_factor(state: HandlingState) -> float:
	return SURFACE_FACTORS[state.road_surface]


func wheel_loss_of_grip(state: HandlingState, wheel_data: WheelData, forces: Vector3) -> Vector3:
	var gear := state.gear
	var throttle := state.throttle
	var performance := state.performance
	var rpm := state.rpm
	var engine_redline_rpm := performance.engine_redline_rpm
	var force_magnitude := forces.length()
	var lateral_grip := wheel_data.grip
	var tire_grip_factor := self.tire_factor(state)
	var grip_loss := lateral_grip - lateral_grip * tire_grip_factor
	var is_front := false
	var result := forces
	if grip_loss < force_magnitude:
		var diff := force_magnitude - grip_loss
		var val := minf(diff, grip_loss) * tire_grip_factor
		match state.weather:
			CarTypes.Weather.RAIN:
				val *= 1.5
			CarTypes.Weather.SNOW:
				val *= 2.0
		var factor := (grip_loss - val) / force_magnitude
		if force_magnitude <= (grip_loss - val):
			factor = 1.0
		match wheel_data.type:
			CarTypes.Wheel.FRONT_RIGHT, CarTypes.Wheel.FRONT_LEFT:
				is_front = true
		if (
			not is_front
			and gear == CarTypes.Gear.GEAR_1
			and 0.85 <= throttle
			and engine_redline_rpm * 0.85 <= rpm
			and 0.95 <= road_factor(state)
		):
			result.z = 0.5 * factor * forces.z
			result.x = factor * forces.x
	return result


func increment_handbrake_accumulator(current: int, weather: int) -> int:
	var increment: int
	match weather:
		CarTypes.Weather.DRY:
			increment = 1
		CarTypes.Weather.RAIN:
			increment = 3
		CarTypes.Weather.SNOW:
			increment = 4
	var next: int = current + increment
	return min(next, 384)


func step_handbrake_accumulator(state: HandlingState, current: int) -> int:
	if not self.get_lost_grip(state):
		return 0
	return increment_handbrake_accumulator(current, state.weather)


func handbrake_scaling_function(value: float) -> float:
	const fldl2e = 1.442695040888963
	var x := fldl2e * (value - 0.5) * -12.56636
	var fprem := fmod(x, 1)
	var f2xm1 := 2 ** fprem - 1
	var fscale := (f2xm1 + 1) * (2 ** (floorf(absf(x)) * signf(x)))
	var result := 1 - 0.8 / (1 + fscale)
	return result


func handbrake_loss_of_grip(state: HandlingState, wheel_data: WheelData, wheel_vector: Vector3, traction: float) -> Vector3:
	var grip := wheel_data.grip
	var downforce := wheel_data.downforce
	var xz_speed := (wheel_vector * Vector3(1, 0, 1)).length()
	var handbrake_accumulator := wheel_data.handbrake_accumulator
	var grip_times_downforce := grip * downforce
	var grip_loss := grip_times_downforce - grip_times_downforce * tire_factor(state)
	var factor := 0.75
	if grip_loss < xz_speed:
		factor = abs(grip_loss / xz_speed)
	var handbrake_factor := 1.0
	if 0 < handbrake_accumulator:
		handbrake_factor = self.handbrake_scaling_function(handbrake_accumulator / 384.0) * 0.75
	var lateral_force := handbrake_factor * wheel_vector.x * factor
	var longitudal_force := traction * factor
	if is_gear_neutral(state):
		lateral_force *= 0.05
		longitudal_force *= 0.05
	return Vector3(lateral_force, 0, longitudal_force)


func wheel_force(state: HandlingState, wheel_data: WheelData) -> Vector3:
	var basis := state.basis_to_road
	var traction := wheel_data.traction
	var performance := state.performance
	var current_steering := state.current_steering
	var throttle := state.throttle
	var handbrake := self.get_lost_grip(state)
	var grip := wheel_data.grip
	var linear_velocity := state.linear_velocity
	var speed_xz := Vector2(linear_velocity.x, linear_velocity.z).length()
	var velocity_local := basis.transposed() * linear_velocity
	var whl_planar_vector := self.wheel_planar_vector(state, wheel_data)
	var is_front := false
	var forces := Vector3.ZERO
	var steering: float
	match wheel_data.type:
		CarTypes.Wheel.FRONT_RIGHT, CarTypes.Wheel.FRONT_LEFT:
			is_front = true
			steering = state.steering
		CarTypes.Wheel.REAR_RIGHT, CarTypes.Wheel.REAR_LEFT:
			steering = 0.0
	whl_planar_vector = vector_rotate_y(whl_planar_vector, -steering)
	var long_accel := self.longitudal_acceleration(state, wheel_data, whl_planar_vector)
	traction = long_accel[0]
	var traction_loss: bool = long_accel[1]
	if ((not handbrake or is_front) and (not handbrake or not is_front or not traction_loss or abs(traction) <= grip)) or (speed_xz < 2.2351501):
		if traction_loss and grip < abs(traction) and not handbrake and performance.has_abs:
			traction = clamp(traction, -grip, grip)
		var value := self.turned_steering_acceleration(state, wheel_data, whl_planar_vector)
		var steering_accel := performance.minimum_steering_acceleration * 2.0
		steering_accel = min(abs(value), steering_accel)
		if (
			abs(velocity_local.z) < 13.4
			&& ((throttle < 0.02 && 127 <= abs(current_steering)) or throttle < 0.015)
		):
			steering_accel *= 0.25
		var understeer_gradient := performance.understeer_gradient
		var understeer := signf(whl_planar_vector.x) * minf(steering_accel, absf(whl_planar_vector.x))
		match wheel_data.type:
			CarTypes.Wheel.FRONT_RIGHT, CarTypes.Wheel.FRONT_LEFT:
				if handbrake and abs(velocity_local.z) < 0.5:
					understeer = 0.0
				understeer = understeer * 0.8 * understeer_gradient
				pass
			CarTypes.Wheel.REAR_RIGHT, CarTypes.Wheel.REAR_LEFT:
				understeer = (understeer * 1.4) / understeer_gradient
				pass
		var f := Vector3(understeer, 0, traction)
		f = wheel_loss_of_grip(state, wheel_data, f)
		forces = vector_rotate_y(f, -steering)
	else:
		forces = self.handbrake_loss_of_grip(state, wheel_data, whl_planar_vector, traction)
	return forces


func wheel_longitudal_acceleration(state: HandlingState, acceleration: Vector3) -> Vector3:
	var performance := state.performance
	acceleration.z /= performance.lateral_grip_multiplier()
	return acceleration


func calculate_g_transfer(state: HandlingState, linear_acceleration: Vector3) -> float:
	var performance := state.performance
	var basis := state.basis_to_road
	var gravity := basis.transposed() * state.gravity_vector
	var g_transfer := linear_acceleration.z * performance.g_transfer_factor - gravity.z * 0.1
	return g_transfer


func wheel_forces_cm(state: HandlingState, output: HandlingOutput) -> void:
	var basis := state.basis_to_road
	var accumulator := state.handbrake_accumulator
	var vectors: Array[Vector3] = []
	for w in state.wheels:
		var wheel_data := self.calculate_wheel_data(state, w)
		accumulator = self.step_handbrake_accumulator(state, accumulator)
		wheel_data.handbrake_accumulator = accumulator
		vectors.append(self.wheel_force(state, wheel_data))
	var linear_acceleration := wheel_forces_to_linear_acceleration(state, vectors)
	linear_acceleration = wheel_longitudal_acceleration(state, linear_acceleration)
	var angular_acceleration := self.wheel_forces_to_angular_acceleration(state, vectors)
	output.updated = (HandlingOutput.F_WHEEL_ACCELERATION | HandlingOutput.F_G_TRANSFER
		| HandlingOutput.F_HANDBRAKE_ACCUMULATOR | HandlingOutput.F_STOP_MOVING_SIDEWAYS)
	output.wheel_linear_acceleration = basis * linear_acceleration
	output.wheel_angular_acceleration = basis * angular_acceleration
	output.g_transfer = calculate_g_transfer(state, linear_acceleration)
	output.handbrake_accumulator = accumulator
	output.stop_moving_sideways = self.is_moving_sideways_locked(state)


func apply_wheel_linear_acceleration_cm(state: HandlingState, output: HandlingOutput) -> void:
	output.updated = HandlingOutput.F_LINEAR_ACCELERATION
	output.linear_acceleration = state.wheel_linear_acceleration


func apply_wheel_angular_acceleration_cm(state: HandlingState, output: HandlingOutput) -> void:
	output.updated = HandlingOutput.F_ANGULAR_ACCELERATION
	output.angular_acceleration = state.wheel_angular_acceleration


func has_traction(state: HandlingState) -> bool:
	if not state.has_contact_with_ground or state.traction_suspended or self.road_normal_y(state) < 0.5:
		return false
	return 0.0 < self.wheel_base_road_grip(state, 1.0)


func turning_circle_cm(state: HandlingState, output: HandlingOutput) -> void:
	var basis := state.basis_to_road
	var angular_velocity := state.angular_velocity
	var linear_velocity := state.linear_velocity
	var local_angular_velocity := basis.transposed() * angular_velocity
	var local_linear_velocity := basis.transposed() * linear_velocity
	var result := self.turning_circle(state, local_angular_velocity, local_linear_velocity)
	var result_angular: Vector3 = result["angular_velocity"]
	var result_linear: Vector3 = result["linear_velocity"]
	var angular_acceleration := (result_angular.y - local_angular_velocity.y) * 32
	var linear_acceleration := (result_linear - linear_velocity) * 32
	output.updated = HandlingOutput.F_ANGULAR_ACCELERATION | HandlingOutput.F_LINEAR_ACCELERATION
	output.angular_acceleration = basis * Vector3(0, angular_acceleration, 0)
	output.linear_acceleration = linear_acceleration


func airborne_drag_cm(state: HandlingState, output: HandlingOutput) -> void:
	const COEFFICIENTS = Vector3(0.004, 0.006, 0.002)
	var basis := state.basis
	var basis_inv := basis.transposed()
	var basis_right := basis_inv.x.abs()
	var basis_forward := basis_inv.z.abs()
	var velocity := state.linear_velocity
	var c := Vector3(COEFFICIENTS.dot(basis_right), 0, COEFFICIENTS.dot(basis_forward))
	var downforce := -velocity.abs() * velocity * c
	output.updated = HandlingOutput.F_LINEAR_ACCELERATION
	output.linear_acceleration = downforce


func neutral_gear_deceleration_cm(state: HandlingState, output: HandlingOutput) -> void:
	var basis := state.basis_to_road
	var steering := state.current_steering
	var linear_velocity := state.linear_velocity
	var angular_velocity := state.angular_velocity
	var velocity_local := basis.transposed() * linear_velocity
	var gravity := basis.transposed() * state.gravity_vector
	var factor := 0.998
	if absf(velocity_local.z) < 20.0 or 32.0 < absf(steering):
		factor = 0.99
	if not is_gear_neutral(state) or absf(gravity.z) >= 0.5:
		factor = 1.0
	factor = (factor - 1)
	output.updated = HandlingOutput.F_LINEAR_ACCELERATION | HandlingOutput.F_ANGULAR_ACCELERATION
	output.linear_acceleration = factor * linear_velocity * 32
	output.angular_acceleration = factor * angular_velocity * 32


func damp_lateral_velocity_cm(state: HandlingState, output: HandlingOutput) -> void:
	const LOW_VELOCITY_DAMP = 0.9
	const LOW_VELOCITY_THRESHOLD = 1.0
	const MEDIUM_VELOCITY_DAMP = 0.99
	const HIGH_VELOCITY_THRESHOLD = 2.0
	const _HIGH_VELOCITY_DAMP = 0.99
	var basis := state.basis_to_road
	var linear_velocity := state.linear_velocity
	var velocity_local := basis.transposed() * linear_velocity
	var lateral_velocity := absf(velocity_local.x)
	var alpha := (lateral_velocity - 1) * 0.09 + 0.9
	var beta := clampf(alpha, LOW_VELOCITY_DAMP, MEDIUM_VELOCITY_DAMP)
	var d: float
	if lateral_velocity < LOW_VELOCITY_THRESHOLD:
		d = LOW_VELOCITY_DAMP
	elif lateral_velocity > HIGH_VELOCITY_THRESHOLD:
		d = MEDIUM_VELOCITY_DAMP
	else:
		d = beta
	var accel_x := (d - 1) * velocity_local.x * 32
	output.updated = HandlingOutput.F_LINEAR_ACCELERATION
	output.linear_acceleration = basis * Vector3(accel_x, 0, 0)


func damp_longitudinal_velocity_cm(state: HandlingState, output: HandlingOutput) -> void:
	var basis := state.basis_to_road
	var velocity_local := basis.transposed() * state.linear_velocity
	var speed := absf(velocity_local.z)
	var factor := 1.0
	if self.get_lost_grip(state):
		if 1.0 < speed:
			var wet := state.weather == CarTypes.Weather.RAIN or state.weather == CarTypes.Weather.SNOW
			factor = 0.9985 if wet else 0.9995
		elif speed < 1.0 and is_gear_neutral(state):
			factor = 0.5
	output.updated = HandlingOutput.F_LINEAR_ACCELERATION
	output.linear_acceleration = basis * Vector3(0, 0, (factor - 1) * velocity_local.z * 32)


func process_steering_input_cm(state: HandlingState, output: HandlingOutput) -> void:
	var steering := state.current_steering
	var performance := state.performance
	var turn_input := state.turn_input
	var steering_target := 128.0 * turn_input
	var ramp_scale := 32 * state.timestep
	var turning_in := (
		(steering_target < 0 or steering >= 0) and (steering_target > 0 or steering <= 0)
	)
	if turning_in:
		var step := round_half_even(performance.turn_in_ramp) * ramp_scale
		steering = move_toward(steering, steering_target, step)
	else:
		var step := round_half_even(performance.turn_out_ramp) * ramp_scale
		steering = move_toward(steering, 0.0, step)
	output.updated = HandlingOutput.F_CURRENT_STEERING
	output.current_steering = steering


func process_throttle_input_cm(state: HandlingState, output: HandlingOutput) -> void:
	var throttle := state.throttle
	var input := state.throttle_input
	const delta = 16 / 255.0
	throttle = move_toward(throttle, input, delta * 32 * state.timestep)
	output.updated = HandlingOutput.F_THROTTLE
	output.throttle = throttle


func process_brake_input_cm(state: HandlingState, output: HandlingOutput) -> void:
	var performance := state.performance
	var brake := state.brake
	var input := state.brake_input
	var idx := roundi(brake * 255) >> 5
	var curve := performance.brake_increasing_curve
	if input < brake:
		curve = performance.brake_decreasing_curve
	var delta := round_half_even(curve[idx]) / 255.0
	brake = move_toward(brake, input, delta * 32 * state.timestep)
	if state.controls_locked:
		brake = 1.0
	output.updated = HandlingOutput.F_BRAKE
	output.brake = brake


func process_gear_input_cm(state: HandlingState, output: HandlingOutput) -> void:
	var performance := state.performance
	var gear := state.gear
	var next_gear := state.next_gear
	var gear_shift_counter := state.gear_shift_counter - 1
	var shifted_down := state.shifted_down
	if next_gear != gear and not state.controls_locked:
		gear_shift_counter = performance.gear_shift_delay
		shifted_down = next_gear < gear and CarTypes.Gear.NEUTRAL < next_gear
		gear = next_gear
	output.updated = HandlingOutput.F_GEAR | HandlingOutput.F_SHIFTED_DOWN | HandlingOutput.F_GEAR_SHIFT_COUNTER
	output.gear = gear
	output.shifted_down = shifted_down
	output.gear_shift_counter = max(0, gear_shift_counter)


func gravity_cm(state: HandlingState, output: HandlingOutput) -> void:
	var gravity = state.gravity_vector
	output.linear_acceleration = gravity
	output.updated = HandlingOutput.F_LINEAR_ACCELERATION


func ground_gravity_cm(state: HandlingState, output: HandlingOutput) -> void:
	var road := state.basis_to_road
	var gravity := state.gravity_vector
	var normal_part := road.y * road.y.dot(gravity)
	var forward_part := road.z * road.z.dot(gravity)
	var side_part := road.x * road.x.dot(gravity)
	var result := normal_part
	if 0.87 <= self.road_normal_y(state):
		if 0.9 <= orientation_to_ground(road, state.basis).y:
			result += forward_part
	else:
		result += side_part + forward_part
	output.linear_acceleration = result
	output.updated = HandlingOutput.F_LINEAR_ACCELERATION


func is_moving_sideways_locked(state: HandlingState) -> bool:
	var velocity_local := state.basis_to_road.transposed() * state.linear_velocity
	return (
		0.5 <= state.throttle and 0.75 <= state.brake
		and 64.0 < absf(state.current_steering) and absf(velocity_local.z) <= 5.0
	)


func prevent_moving_sideways_cm(state: HandlingState, output: HandlingOutput) -> void:
	var result := state.linear_velocity
	if state.stop_moving_sideways:
		result *= 0
	output.updated = HandlingOutput.F_LINEAR_VELOCITY
	output.linear_velocity = result


func near_stop_deceleration(state: HandlingState, output: HandlingOutput) -> void:
	const VELOCITY_THRESHOLD_REVERSE = 4.0
	const VELOCITY_THRESHOLD_FORWARD = 5.0
	const DAMP_FACTOR = 0.8
	var gear: CarTypes.Gear = state.gear
	var basis: Basis = state.basis_to_road
	var linear_velocity: Vector3 = state.linear_velocity
	var angular_velocity: Vector3 = state.angular_velocity
	var linear_acceleration := Vector3.ZERO
	var angular_acceleration := Vector3.ZERO
	var threshold := VELOCITY_THRESHOLD_FORWARD
	if gear == CarTypes.Gear.REVERSE:
		threshold = VELOCITY_THRESHOLD_REVERSE
	var velocity_local := basis.transposed() * linear_velocity
	if abs(velocity_local.z) < threshold:
		var damp := DAMP_FACTOR - 1.0
		linear_acceleration = damp * linear_velocity * 32
		angular_acceleration = damp * angular_velocity * 32
	output.updated = HandlingOutput.F_LINEAR_ACCELERATION | HandlingOutput.F_ANGULAR_ACCELERATION
	output.linear_acceleration = linear_acceleration
	output.angular_acceleration = angular_acceleration


var should_come_to_stop: Callable = predicate_all(
	[
		throttle_in_range_uint8(0, 31),
		brake_in_range_uint8(0, 31),
		neg(is_gear_neutral),
		neg(is_airborne),
	]
)

var near_stop_deceleration_cm: Callable = enable_if(
	should_come_to_stop, integrate(self.near_stop_deceleration)
)


func brake_force(state: HandlingState, wheel_data: WheelData) -> float:
	var performance := state.performance
	var brake := state.brake
	var brake_deceleration := brake * performance.maximum_braking_deceleration
	var wheel_type := wheel_data.type
	var front_brake_ratio := performance.front_brake_bias()
	var basis := state.basis_to_road
	var linear_velocity := state.linear_velocity
	var velocity_local := basis.transposed() * linear_velocity
	var brake_maximum := absf(32 * velocity_local.z)
	var has_spoiler := performance.has_spoiler()
	var downforce_mult := performance.downforce_mult()
	if 0.15 < brake and has_spoiler:
		brake_deceleration += absf(velocity_local.z) * downforce_mult
	brake_deceleration = minf(brake_maximum, brake_deceleration)
	if self.get_lost_grip(state):
		front_brake_ratio += 0.05
	var rear_brake_ratio := 1.0 - front_brake_ratio
	match wheel_type:
		CarTypes.Wheel.FRONT_RIGHT, CarTypes.Wheel.FRONT_LEFT:
			brake_deceleration *= front_brake_ratio
		CarTypes.Wheel.REAR_RIGHT, CarTypes.Wheel.REAR_LEFT:
			brake_deceleration *= rear_brake_ratio
	return sign(velocity_local.z) * brake_deceleration


func limit_angular_velocity(angular_velocity: Vector3, limit: float) -> Vector3:
	var vec_limit := limit * Vector3.ONE
	return angular_velocity.clamp(-vec_limit, vec_limit)


func height_above_surface(state: HandlingState) -> float:
	var dimensions := state.dimensions
	var basis := state.basis
	var basis_to_road := state.basis_to_road
	var distance_above_ground := state.distance_above_ground
	var projected := Vector3(
		basis.x.dot(basis_to_road.y),
		basis.y.dot(basis_to_road.y),
		basis.z.dot(basis_to_road.y),
	)
	var dimensions_projected := -projected.abs() * (dimensions / 2.0)
	return distance_above_ground + dimensions_projected.x + dimensions_projected.y + dimensions_projected.z


func limit_angular_velocity_cm(state: HandlingState, output: HandlingOutput) -> void:
	const ANGULAR_VELOCITY_LIMIT = 2.4
	var result := self.limit_angular_velocity(state.angular_velocity, ANGULAR_VELOCITY_LIMIT)
	output.updated = HandlingOutput.F_ANGULAR_VELOCITY
	output.angular_velocity = result


func downforce_cm(state: HandlingState, output: HandlingOutput) -> void:
	const BODY_DAMAGE_DOWNFORCE := 0.2
	var basis := state.basis
	var linear_velocity := state.linear_velocity
	var velocity_local := basis.transposed() * linear_velocity
	var downforce_accel := 0.0
	var upright := 0.75 < orientation_to_ground(state.basis_to_road, basis).y
	var speed_xz := Vector2(linear_velocity.x, linear_velocity.z).length()
	if upright and 10.0 < speed_xz and 0.0 < velocity_local.z:
		var downforce := state.performance.downforce_mult() * (1.0 - state.body_damage * BODY_DAMAGE_DOWNFORCE)
		downforce_accel = -downforce * velocity_local.z * 32
	output.updated = HandlingOutput.F_LINEAR_ACCELERATION
	output.linear_acceleration = basis * Vector3(0, downforce_accel, 0)


func is_flipped(state: HandlingState) -> bool:
	return self.orientation_to_ground(state.basis_to_road, state.basis).y < 0.9


func is_near_road(state: HandlingState) -> bool:
	return state.height_above_road < 0.6


func road_aligned_basis(basis: Basis, normal: Vector3) -> Basis:
	var x: Vector3
	var z: Vector3
	if 0.5 <= basis.y.dot(normal) or absf(basis.x.dot(normal)) <= 0.5:
		z = basis.x.cross(normal).normalized()
		x = normal.cross(z).normalized()
	else:
		x = normal.cross(basis.z).normalized()
		z = x.cross(normal).normalized()
	return Basis(x, normal, z)


func is_resting_flat_on_ground(state: HandlingState) -> bool:
	const LIMIT = 1.0 / 72.0
	var lean := self.orientation_to_ground(state.basis_to_road, state.basis).abs()
	var size := state.dimensions
	var on_wheels_or_roof := (
		atan2(lean.z * size.y, lean.y * size.z) / TAU < LIMIT
		and atan2(lean.x * size.y, lean.y * size.x) / TAU < LIMIT
	)
	var on_side := (
		atan2(lean.y * size.x, lean.x * size.y) / TAU < LIMIT
		and atan2(lean.z * size.x, lean.x * size.z) / TAU < LIMIT
	)
	return on_wheels_or_roof or on_side


func lift_off_cm(state: HandlingState, output: HandlingOutput) -> void:
	var has_contact_with_ground := state.has_contact_with_ground
	if not self.is_resting_flat_on_ground(state) or self.road_normal_y(state) < 0.6:
		has_contact_with_ground = false
	output.updated = HandlingOutput.F_HAS_CONTACT_WITH_GROUND
	output.has_contact_with_ground = has_contact_with_ground


func collision_shape_points(state: HandlingState) -> Array[Vector3]:
	var half_size := state.dimensions / 2.0
	var points: Array[Vector3] = [
		Vector3(-1, -1, 1) * half_size,
		Vector3(1, -1, 1) * half_size,
		Vector3(1, -1, -1) * half_size,
		Vector3(-1, -1, -1) * half_size,
		Vector3(-0.75, 0.5, 0.8) * half_size,
		Vector3(0.75, 0.5, 0.8) * half_size,
		Vector3(1, 1, -0.8) * half_size,
		Vector3(-1, 1, -0.8) * half_size,
	]
	for face: Array in [[0, 1, 4, 5], [2, 3, 6, 7], [0, 3, 4, 7], [1, 2, 5, 6], [4, 5, 6, 7], [0, 1, 2, 3]]:
		points.append((points[face[0]] + points[face[1]] + points[face[2]] + points[face[3]]) * 0.25)
	return points


func collision_outline_points(state: HandlingState) -> Array[Vector3]:
	var half_size := state.dimensions / 2.0
	return [
		Vector3(-1, 0, 1) * half_size,
		Vector3(1, 0, 1) * half_size,
		Vector3(1, 0, -1) * half_size,
		Vector3(-1, 0, -1) * half_size,
		Vector3(0, 0, 1) * half_size,
		Vector3(0, 0, -1) * half_size,
		Vector3(-1, 0, 0) * half_size,
		Vector3(1, 0, 0) * half_size,
	]


func collision_body(state: HandlingState) -> CollisionParams:
	var body := CollisionParams.new()
	body.basis = state.basis
	body.position = state.position
	body.linear_velocity = state.linear_velocity
	body.angular_velocity = state.angular_velocity
	body.inertia_inv = state.inertia_inv
	body.mass = state.mass
	body.friction = state.friction
	return body


func collide(body: CollisionParams, body_point: Vector3, impact_point: Vector3, normal: Vector3, friction: float) -> bool:
	var result := CollisionOutput.new()
	var collided := self.calculate_impact(body, body_point, impact_point, normal, friction, result)
	body.position = result.position
	body.linear_velocity = result.linear_velocity
	body.angular_velocity = result.angular_velocity
	return collided


func collide_shape_with_plane(state: HandlingState, body: CollisionParams, normal: Vector3, plane_point: Vector3, reach: float, friction: float) -> bool:
	var upright := 0.5 < absf(self.orientation_to_ground(state.basis_to_road, state.basis).y)
	var shape: Array[Vector3]
	if state.has_contact_with_ground and upright:
		shape = self.collision_outline_points(state)
	else:
		shape = self.collision_shape_points(state)
	var nearest := reach
	var nearest_point := Vector3.ZERO
	for shape_point in shape:
		var point := body.basis * shape_point + body.position
		var distance := (point - plane_point).dot(normal)
		if distance < nearest:
			nearest = distance
			nearest_point = point
	var collided := false
	if nearest < reach:
		collided = self.collide(body, nearest_point, plane_point, normal, friction)
	body.angular_velocity = self.limit_angular_velocity(body.angular_velocity, 1.8)
	return collided


func road_collision_points(state: HandlingState) -> Array[Vector3]:
	return self.collision_shape_points(state).slice(0, 8)


func is_landing(state: HandlingState) -> bool:
	var falling := state.linear_velocity.dot(state.basis_to_road.y) < 0.0
	return not state.has_contact_with_ground and self.is_near_road(state) and falling


func road_lookahead_point(state: HandlingState) -> Vector3:
	var basis := state.basis
	var half_size := state.dimensions / 2.0
	var direction := state.linear_velocity.normalized()
	var leading_edge := Vector3(direction.dot(basis.x), -1.0, direction.dot(basis.z)) * half_size
	return state.position + state.linear_velocity * state.timestep + basis * leading_edge


func adjust_to_road_cm(state: HandlingState, output: HandlingOutput) -> void:
	const LIMIT = 0.97222
	const DEAD_ZONE = 0.02
	const MAX_RATE = 0.5
	var road := state.basis_to_road
	var basis := state.basis
	var body := self.collision_body(state)
	var road_normal := road.y
	var surface_normal := road_normal
	var height := state.height_above_road
	var collided := state.collided
	var ahead_normal := state.road_normal_ahead
	var similar := 0.87 <= 1.0 - absf(road_normal.y - ahead_normal.y)
	if similar or 0.0 <= body.linear_velocity.dot(ahead_normal) or road_normal.y <= ahead_normal.y:
		surface_normal = road_normal.slerp(ahead_normal, 0.5)
	else:
		var wall_normal := Vector3(ahead_normal.x, 0.0, ahead_normal.z).normalized()
		var reach := Vector2(body.linear_velocity.x, body.linear_velocity.z).length() * state.timestep
		var friction := SURFACE_FRICTION[state.road_surface]
		if self.collide_shape_with_plane(state, body, wall_normal, self.road_lookahead_point(state), reach, friction):
			collided = true
	if height <= 0.0:
		road_normal = surface_normal
		body.position -= road_normal * height
		height = 0.0
		var normal_velocity := body.linear_velocity.dot(road_normal)
		if normal_velocity < 0.5:
			body.linear_velocity -= road_normal * normal_velocity
	var orientation := self.orientation_to_ground(road, basis)
	var lean := orientation.abs()
	if LIMIT < lean.x or LIMIT < lean.y or LIMIT < lean.z:
		var axis := Vector3.AXIS_Y
		if lean.y <= LIMIT:
			axis = Vector3.AXIS_X if LIMIT < lean.x else Vector3.AXIS_Z
		var resting_axis: Vector3 = basis[axis] * (1.0 if 0.0 < orientation[axis] else -1.0)
		var roll := resting_axis.x - road_normal.x
		var pitch := road_normal.z - resting_axis.z
		if DEAD_ZONE < absf(roll) or DEAD_ZONE < absf(pitch):
			body.angular_velocity.z = clampf(roll, -MAX_RATE, MAX_RATE)
			body.angular_velocity.x = clampf(pitch, -MAX_RATE, MAX_RATE)
		else:
			body.angular_velocity.z = 0.0
			body.angular_velocity.x = 0.0
	state.height_above_road = height
	state.collided = collided
	output.updated = (HandlingOutput.F_POSITION | HandlingOutput.F_LINEAR_VELOCITY
		| HandlingOutput.F_ANGULAR_VELOCITY)
	output.position = body.position
	output.linear_velocity = body.linear_velocity
	output.angular_velocity = body.angular_velocity


func landing_damp(state: HandlingState) -> float:
	const SUSPENSION_DAMAGE_BOUNCE := 0.25 * 0.2
	var suspension := state.suspension_damage
	var damage := (suspension[0] + suspension[1] + suspension[2] + suspension[3]) * SUSPENSION_DAMAGE_BOUNCE
	return clampf(state.performance.suspension_stiffness * 0.1 + damage, 0.0, 0.2) + 0.5


func landing_cm(state: HandlingState, output: HandlingOutput) -> void:
	const UPRIGHT = 0.97222
	var road := state.basis_to_road
	var normal := road.y
	var linear_velocity := state.linear_velocity
	var angular_velocity := state.angular_velocity
	var height := state.height_above_road
	if state.road_collided:
		height = 0.0
		if UPRIGHT < self.orientation_to_ground(road, state.basis).y:
			var damp := self.landing_damp(state)
			var velocity_local := road.transposed() * linear_velocity
			velocity_local.y *= damp
			linear_velocity = road * velocity_local
			angular_velocity *= damp
	var settled := (
		linear_velocity.dot(normal) < 0.5
		and absf(angular_velocity.x) < 0.5 and absf(angular_velocity.z) < 0.5
		and self.is_resting_flat_on_ground(state) and height <= 0.0
	)
	state.height_above_road = height
	output.updated = (HandlingOutput.F_LINEAR_VELOCITY | HandlingOutput.F_ANGULAR_VELOCITY
		| HandlingOutput.F_HAS_CONTACT_WITH_GROUND)
	output.linear_velocity = linear_velocity
	output.angular_velocity = angular_velocity
	output.has_contact_with_ground = settled


func leave_road_cm(state: HandlingState, output: HandlingOutput) -> void:
	state.just_left_ground = state.has_contact_with_ground
	self.limit_angular_velocity_cm(state, output)
	output.updated |= HandlingOutput.F_HAS_CONTACT_WITH_GROUND
	output.has_contact_with_ground = false


func flipped_engine_cm(state: HandlingState, output: HandlingOutput) -> void:
	const RPM_DROP = 500
	var engine_min_rpm := state.performance.engine_min_rpm()
	var rpm := state.rpm
	if engine_min_rpm + RPM_DROP < rpm:
		rpm -= RPM_DROP
	else:
		rpm = engine_min_rpm
	state.slip_angle = 0.0
	output.updated = HandlingOutput.F_RPM | HandlingOutput.F_FORCE | HandlingOutput.F_DRIVETRAIN_OVERLOAD
	output.rpm = rpm
	output.force = 0.0
	output.drivetrain_overload = false


func flipped_friction_cm(state: HandlingState, output: HandlingOutput) -> void:
	const GROUND_FRICTION = 0.98
	const SLIDE_FRICTION = 0.95
	var road := state.basis_to_road
	var linear_velocity := state.linear_velocity
	var angular_velocity := state.angular_velocity
	if state.has_contact_with_ground and state.height_above_road <= 0.2 and 0.5 <= self.road_normal_y(state):
		var velocity_local := road.transposed() * linear_velocity
		var angular_local := road.transposed() * angular_velocity
		velocity_local.x *= GROUND_FRICTION * SLIDE_FRICTION
		velocity_local.z *= GROUND_FRICTION * SLIDE_FRICTION
		angular_local.y *= GROUND_FRICTION
		linear_velocity = road * velocity_local
		angular_velocity = road * angular_local
	output.updated = HandlingOutput.F_LINEAR_VELOCITY | HandlingOutput.F_ANGULAR_VELOCITY
	output.linear_velocity = linear_velocity
	output.angular_velocity = angular_velocity


var flipped_pipeline: Callable = make_model_pipeline([flipped_engine_cm, flipped_friction_cm])


func takeoff_cm(state: HandlingState, output: HandlingOutput) -> void:
	const PITCH_DAMP = 0.15
	var basis := state.basis
	var angular_velocity := state.angular_velocity
	var rising := 0.0 < state.linear_velocity.dot(state.basis_to_road.y)
	if state.just_left_ground and not state.collided and rising:
		var angular_local := basis.transposed() * angular_velocity
		angular_local.x *= PITCH_DAMP
		angular_velocity = basis * angular_local
	output.updated = HandlingOutput.F_ANGULAR_VELOCITY
	output.angular_velocity = angular_velocity


func upset_spin_damp_cm(state: HandlingState, output: HandlingOutput) -> void:
	var angular_velocity := state.angular_velocity
	var upset := self.orientation_to_ground(state.basis_to_road, state.basis).y < 0.5
	if state.has_contact_with_ground and state.height_above_road < 5.0 and upset:
		angular_velocity -= angular_velocity / 64.0
	output.updated = HandlingOutput.F_ANGULAR_VELOCITY
	output.angular_velocity = angular_velocity

# Predicates

func predicate_all(func_array: Array) -> Callable:
	return func(ctx) -> bool:
		return func_array.all(func(x): return x.call(ctx))


func predicate_any(func_array: Array) -> Callable:
	return func(ctx) -> bool:
		return func_array.any(func(x): return x.call(ctx))


func is_gear_neutral(params) -> bool:
	return params.get("gear") == CarTypes.Gear.NEUTRAL


func is_gear_reverse(params) -> bool:
	return params.get("gear") == CarTypes.Gear.REVERSE


func is_airborne(params) -> bool:
	return params.get("has_contact_with_ground") == false


func throttle_in_range(lower: float, upper: float) -> Callable:
	return func(ctx) -> bool:
		var throttle = ctx.get("throttle")
		return lower <= throttle and throttle <= upper


func brake_in_range(lower: float, upper: float) -> Callable:
	return func(ctx) -> bool:
		var throttle = ctx.get("brake")
		return lower <= throttle and throttle <= upper


func throttle_in_range_uint8(lower: int, upper: int) -> Callable:
	return throttle_in_range(lower / 255.0, upper / 255.0)


func brake_in_range_uint8(lower: int, upper: int) -> Callable:
	return brake_in_range(lower / 255.0, upper / 255.0)


func traction_pipeline(state: HandlingState, output: HandlingOutput) -> void:
	state.slip_angle = self.vehicle_slip_angle_tg(state)
	state.speed_xz = self.calculate_speed_xz(state)
	state.drivetrain_overload = false
	state.force = 0.0
	state.lost_grip = true
	state.wheel_linear_acceleration = Vector3.ZERO
	state.wheel_angular_acceleration = Vector3.ZERO
	state.stop_moving_sideways = false
	var traction := make_model_pipeline([
		integrate(self.apply_wheel_linear_acceleration_cm),
		prevent_moving_sideways_cm,
		integrate(self.damp_lateral_velocity_cm),
		integrate(self.damp_longitudinal_velocity_cm),
		integrate(self.apply_wheel_angular_acceleration_cm),
		integrate(turning_circle_cm),
		enable_if(is_gear_neutral, integrate(self.neutral_gear_deceleration_cm)),
	])
	var pipeline := make_model_pipeline([
		process_brake_input_cm,
		process_throttle_input_cm,
		process_steering_input_cm,
		process_gear_input_cm,
		steering_angle,
		traction_model,
		enable_if(self.has_traction, self.wheel_forces_cm),
		near_stop_deceleration_cm,
		enable_if(self.has_traction, traction),
	])
	pipeline.call(state, output)


func apply_collision_velocities(params: CollisionParams, momentum: Vector3, radius: Vector3, mass_ratio: float, friction: float, result: CollisionOutput) -> void:
	var mass: float = params.mass
	var mass_inv := 1.0 / mass
	var linear_velocity: Vector3 = params.linear_velocity
	var angular_velocity: Vector3 = params.angular_velocity
	var basis: Basis = params.basis
	var basis_inv := basis.inverse()
	var inertia_inv: Vector3 = params.inertia_inv
	var inertia := inertia_inv.inverse()
	var result_linear_velocity := linear_velocity
	var result_angular_velocity := angular_velocity
	if mass < momentum.length():
		momentum *= friction
	momentum *= mass_ratio
	var radius_norm := radius.normalized()
	var momentum_radius_dot := -radius_norm.dot(momentum)
	if 0.0 < momentum_radius_dot:
		var vel_correction := -momentum_radius_dot * radius_norm * mass_inv
		result_linear_velocity = linear_velocity + vel_correction
	if not is_zero_approx(radius.length()):
		var arm := basis_inv * radius
		var momentum_local := basis_inv * momentum
		var angular_momentum := arm.cross(momentum_local)
		var arm_2 := arm * arm
		var radvalues := Vector3(
			arm_2.z + arm_2.y,
			arm_2.x + arm_2.z,
			arm_2.x + arm_2.y
		)
		var shifted_inertia = radvalues * mass + inertia
		var corr_angular_velocity = angular_momentum / shifted_inertia
		result_angular_velocity = angular_velocity + (basis * corr_angular_velocity) / TAU
	result_angular_velocity = limit_angular_velocity(result_angular_velocity, 1.8)
	result.linear_velocity = result_linear_velocity
	result.angular_velocity = result_angular_velocity


func kinetic_energy(params: CollisionParams) -> float:
	var angular_velocity: Vector3 = params.angular_velocity
	var linear_velocity: Vector3 = params.linear_velocity
	var inerta_inv: Vector3 = params.inertia_inv
	var mass: float = params.mass
	var inertia := inerta_inv.inverse()
	var rotational := (angular_velocity.length() ** 2) * inertia.length() / 2.0
	var linear := (linear_velocity.length() ** 2) * mass / 2.0
	return rotational + linear


func damp_contact_sliding(basis: Basis, normal: Vector3, result: CollisionOutput) -> void:
	const SPEED_THRESHOLD = 22.0
	const DAMP = 0.958
	const FORWARD_DAMP = 0.975
	var basis_inv := basis.transposed()
	var velocity_local := basis_inv * result.linear_velocity
	var angular_local := basis_inv * result.angular_velocity
	var normal_local := basis_inv * normal
	var normal_velocity := normal_local * velocity_local.dot(normal_local)
	var normal_spin := normal_local * angular_local.dot(normal_local)
	var sliding := velocity_local - normal_velocity
	var damp := Vector3(DAMP, DAMP, DAMP)
	if 0.9 < basis.y.dot(normal):
		damp.z = FORWARD_DAMP
	for axis in 3:
		if SPEED_THRESHOLD < absf(sliding[axis]):
			sliding[axis] *= damp[axis]
	result.linear_velocity = basis * (sliding + normal_velocity)
	result.angular_velocity = basis * (angular_local - normal_spin + normal_spin * DAMP)


func calculate_impact(params: CollisionParams, body_point: Vector3, impact_point: Vector3, normal: Vector3, friction: float, result: CollisionOutput) -> bool:
	var energy_before := self.kinetic_energy(params)
	if not self.calculate_impact_impulse(params, body_point, impact_point, normal, friction, result):
		result.collided = false
		return false
	params.linear_velocity = result.linear_velocity
	params.angular_velocity = result.angular_velocity
	var energy_after := self.kinetic_energy(params)
	if energy_before < energy_after:
		var energy_ratio := sqrt(energy_before / energy_after)
		result.linear_velocity *= energy_ratio
		result.angular_velocity *= energy_ratio
	self.damp_contact_sliding(params.basis, normal, result)
	result.collided = true
	return true


func calculate_impact_impulse(params: CollisionParams, body_point: Vector3, impact_point: Vector3, normal: Vector3, friction: float, result: CollisionOutput) -> bool:
	var current_position: Vector3 = params.position
	var angular_velocity: Vector3 = params.angular_velocity
	var linear_velocity: Vector3 = params.linear_velocity
	var car_friction: float = params.friction
	var mass: float = params.mass
	result.position = current_position
	var diff := body_point - impact_point
	var dot := diff.dot(normal)
	if dot < 0:
		var correction := -dot * normal
		result.position += correction
		current_position = result.position
	var body_point_to_origin := body_point - current_position
	var angular_velocity_tau := angular_velocity * TAU
	var tangential_velocity := angular_velocity_tau.cross(body_point_to_origin)
	var body_point_linear_velocity := tangential_velocity + linear_velocity
	var momentum_at_body_point := body_point_linear_velocity * mass
	var momentum_dot := momentum_at_body_point.dot(normal)
	result.linear_velocity = linear_velocity
	result.angular_velocity = angular_velocity
	if momentum_dot >= 0.0:
		return false
	var projected_momentum := -momentum_dot * normal
	var combined_friction := car_friction * friction
	self.apply_collision_velocities(params, projected_momentum, body_point_to_origin, 1.0, combined_friction, result)
	return true


func process_collision(params: CollisionParams, body_point: Vector3, impact_point: Vector3, normal: Vector3, friction: float, result: CollisionOutput) -> bool:
	params.angular_velocity /= TAU
	var collided := calculate_impact(params, body_point, impact_point, normal, friction, result)
	result.angular_velocity *= TAU
	return collided


func process_external_forces(state: HandlingState, output: HandlingOutput) -> void:
	state.angular_velocity /= TAU
	state.height_above_road = self.height_above_surface(state)
	state.just_left_ground = false
	state.road_collided = false
	var external_forces := make_model_pipeline([
		integrate(self.downforce_cm),
		enable_if(is_airborne, integrate(airborne_drag_cm)),
		lift_off_cm,
		either(is_airborne, integrate(self.gravity_cm), integrate(self.ground_gravity_cm)),
	])
	external_forces.call(state, output)
	state.angular_velocity *= TAU


func process_road_collision(state: HandlingState, body_point: Vector3, road: Plane) -> bool:
	if 0.0 <= road.distance_to(body_point):
		return false
	state.angular_velocity /= TAU
	var body := self.collision_body(state)
	var friction := SURFACE_FRICTION[state.road_surface]
	var collided := self.collide(body, body_point, road.project(body_point), road.normal, friction)
	state.position = body.position
	state.linear_velocity = body.linear_velocity
	state.angular_velocity = body.angular_velocity * TAU
	if collided:
		state.road_collided = true
		state.collided = true
	return collided


func process(state: HandlingState, output: HandlingOutput) -> void:
	state.angular_velocity /= TAU
	var road_contact := either(
		self.is_near_road,
		either(is_airborne, landing_cm, adjust_to_road_cm),
		leave_road_cm,
	)
	var model := make_model_pipeline([
		road_contact,
		either(self.is_flipped, flipped_pipeline, traction_pipeline),
		takeoff_cm,
		upset_spin_damp_cm,
	])
	model.call(state, output)
	state.angular_velocity *= TAU
	output.position = state.position
	output.angular_velocity = state.angular_velocity
	output.linear_velocity = state.linear_velocity
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
	output.engine_damage = state.engine_damage
	output.updated = (HandlingOutput.F_LINEAR_VELOCITY | HandlingOutput.F_ANGULAR_VELOCITY |
		HandlingOutput.F_GEAR | HandlingOutput.F_RPM | HandlingOutput.F_CURRENT_STEERING |
		HandlingOutput.F_LOST_GRIP | HandlingOutput.F_HANDBRAKE_ACCUMULATOR |
		HandlingOutput.F_FORCE | HandlingOutput.F_GEAR_SHIFT_COUNTER |
		HandlingOutput.F_SHIFTED_DOWN | HandlingOutput.F_G_TRANSFER |
		HandlingOutput.F_THROTTLE | HandlingOutput.F_BRAKE |
		HandlingOutput.F_HAS_CONTACT_WITH_GROUND | HandlingOutput.F_POSITION)
