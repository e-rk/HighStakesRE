extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/B911/B911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

const EPSILON = 1


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/handling_full.csv", FileAccess.READ
	)


func make_params(data: Dictionary) -> Dictionary:
	var result = Dictionary()
	result["performance"] = self.performance
	result["basis_to_road"] = self.basis_to_road(data)
	result["basis"] = self.basis(data)
	result["gear"] = self.gear(data)
	result["next_gear"] = self.next_gear(data)
	result["linear_velocity"] = self.global_linear_velocity(data)
	result["angular_velocity"] = self.global_angular_velocity(data)
	result["current_steering"] = self.steering(data)
	result["turn_input"] = self.steering_input(data) / 128.0
	result["throttle_input"] = self.throttle_input(data)
	result["throttle"] = self.throttle(data)
	result["handbrake"] = self.handbrake(data)
	result["inertia_inv"] = self.inertia_inv(data)
	result["mass"] = self.mass(data)
	result["has_contact_with_ground"] = !self.is_airborne(data)
	result["weather"] = 0
	result["rpm"] = self.rpm(data)
	#result["speed_xz"] = self.speed_xz(data)
	#result["slip_angle"] = self.slip_angle(data)
	result["road_surface"] = self.road_surface(data)
	result["g_transfer"] = self.g_transfer(data)
	result["gravity_vector"] = Vector3(0, -9.81, 0)
	result["brake_input"] = self.brake_input(data)
	result["brake"] = self.brake(data)
	result["timestep"] = 1 / 32.0
	result["handbrake_accumulator"] = self.handbrake_accumulator(data)
	result["gear_shift_counter"] = (int(data["unknown_engine_value2"]) >> 0x10)
	result["shifted_down"] = data["unknown_engine_value"] != "0"
	result["wheels"] = [
		{"type": CarTypes.Wheel.FRONT_RIGHT, "road_surface": self.wheel_road_surface(data, 0)},
		{"type": CarTypes.Wheel.FRONT_LEFT, "road_surface": self.wheel_road_surface(data, 1)},
		{"type": CarTypes.Wheel.REAR_RIGHT, "road_surface": self.wheel_road_surface(data, 2)},
		{"type": CarTypes.Wheel.REAR_LEFT, "road_surface": self.wheel_road_surface(data, 3)},
	]
	return result


func body(data: Dictionary):
	var params = self.make_params(data)
	var expected_rpm = int(data["result_rpm"])
	var expected_velocity = self.result_global_linear_velocity(data)
	var expected_angular = self.result_global_angular_velocity(data)
	var expected_handbrake = data["result_handbrake"] != "0"
	var expected_gear = int(data["result_gear"])
	var expected_steering = float(data["result_current_steering"])
	var expected_throttle = float(data["result_throttle"])
	var expected_brake = float(data["result_brake"])
	var wheel_data = Dictionary()
	if is_equal_approx(1.0, expected_brake):
		pass
	var result = self.model.traction_pipeline(params)
	var ttt = result["brake"]
	var msg = "gear=" + str(params["gear"]) \
			+ " hb=" + str(params["handbrake"]) \
			+ " v=" + str(params["linear_velocity"]) \
			+ " w=" + str(params["angular_velocity"]) \
			+ " bi=" + str(params["brake_input"])
	#assert_eq(result["rpm"], expected_rpm, msg)
	#assert_eq(result["handbrake"], expected_handbrake, msg)
	assert_eq(result["gear"], expected_gear, msg)
	assert_almost_eq(result["linear_velocity"], expected_velocity, Vector3.ONE * 0.01, msg)
	#assert_almost_eq(result["angular_velocity"], expected_angular, Vector3.ONE * 0.001, msg)
	#assert_almost_eq(result["current_steering"], expected_steering, 0.001, msg)
	assert_almost_eq(result["throttle"], expected_throttle, 0.001, msg)
	#assert_almost_eq(result["brake"], expected_brake, 0.001, msg)
