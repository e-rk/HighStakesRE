extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

var result := HandlingModelRE.HandlingOutput.new()


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/handling_full.csv", FileAccess.READ
	)


func make_params(data: Dictionary) -> HandlingModelRE.HandlingState:
	var result = HandlingModelRE.HandlingState.new()
	result.performance = self.performance
	result.basis_to_road = self.basis_to_road(data)
	result.basis = self.basis(data)
	result.gear = self.gear(data)
	result.next_gear = self.next_gear(data)
	result.linear_velocity = self.global_linear_velocity(data)
	result.angular_velocity = self.global_angular_velocity(data)
	result.current_steering = self.steering(data)
	result.turn_input = self.steering_input(data) / 128.0
	result.throttle_input = self.throttle_input(data)
	result.throttle = self.throttle(data)
	result.handbrake = self.handbrake(data)
	result.inertia_inv = self.inertia_inv(data)
	result.mass = self.mass(data)
	result.has_contact_with_ground = !self.is_airborne(data)
	result.weather = 0
	result.rpm = self.rpm(data)
	result.road_surface = self.road_surface(data)
	result.g_transfer = self.g_transfer(data)
	result.gravity_vector = Vector3(0, -9.81, 0)
	result.brake_input = self.brake_input(data)
	result.brake = self.brake(data)
	result.timestep = 1 / 32.0
	result.handbrake_accumulator = self.handbrake_accumulator(data)
	result.gear_shift_counter = (int(data.unknown_engine_value2) >> 0x10)
	result.shifted_down = data.unknown_engine_value != "0"
	result.controls_locked = data.controls_locked != "0"
	result.traction_suspended = data.traction_suspended != "0"
	result.wheels = [
		{"type": CarTypes.Wheel.FRONT_RIGHT, "road_surface": self.wheel_road_surface(data, 0)},
		{"type": CarTypes.Wheel.FRONT_LEFT, "road_surface": self.wheel_road_surface(data, 1)},
		{"type": CarTypes.Wheel.REAR_RIGHT, "road_surface": self.wheel_road_surface(data, 2)},
		{"type": CarTypes.Wheel.REAR_LEFT, "road_surface": self.wheel_road_surface(data, 3)},
	]
	return result


func body(data: Dictionary):
	var params = self.make_params(data)
	var expected_rpm = int(data.result_rpm)
	var expected_velocity = self.result_global_linear_velocity(data)
	var expected_angular = self.result_global_angular_velocity(data)
	var expected_handbrake = data.result_handbrake != "0"
	var expected_gear = int(data.result_gear)
	var expected_steering = float(data.result_current_steering)
	var expected_throttle = float(data.result_throttle)
	var expected_brake = float(data.result_brake)
	var msg = " row=" + str(self.current_line) \
			+ " gear=" + str(params.gear) \
			+ " hb=" + str(params.handbrake) \
			+ " v=" + str(params.linear_velocity) \
			+ " w=" + str(params.angular_velocity) \
			+ " bi=" + str(params.brake_input)
	self.model.traction_pipeline(params, result)
	assert_eq(params.rpm, expected_rpm, "rpm" + msg)
	assert_eq(params.lost_grip, expected_handbrake, "lost grip" + msg)
	assert_eq(params.gear, expected_gear, "gear" + msg)
	assert_almost_eq(params.linear_velocity, expected_velocity, Vector3.ONE * 0.01, "vel" + msg)
	assert_almost_eq(params.angular_velocity, expected_angular, Vector3.ONE * 0.001, "ang" + msg)
	assert_almost_eq(params.current_steering, expected_steering, 0.001, "steer" + msg)
	assert_almost_eq(params.throttle, expected_throttle, 0.001, "thr" + msg)
	assert_almost_eq(params.brake, expected_brake, 0.001, "brake" + msg)
	if data.result_g_transfer != "":
		assert_almost_eq(params.g_transfer, float(data.result_g_transfer), 0.01, "g transfer" + msg)
	if data.result_handbrake_accumulator != "":
		assert_eq(params.handbrake_accumulator, int(data.result_handbrake_accumulator), "hb acc" + msg)
