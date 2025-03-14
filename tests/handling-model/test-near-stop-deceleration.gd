extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/B911/B911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

const EPSILON = 0.000001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/near_stop_deceleration.csv", FileAccess.READ)


func make_params(data: Dictionary) -> Dictionary:
	var result = Dictionary()
	result["performance"] = self.performance
	result["basis_to_road"] = self.basis_to_road(data)
	result["linear_velocity"] = self.global_linear_velocity(data)
	result["angular_velocity"] = self.global_angular_velocity(data)
	result["timestep"] = 1.0 / 32.0
	result["gear"] = self.gear(data)
	result["throttle"] = self.throttle(data)
	result["brake"] = self.brake(data)
	result["rpm"] = 0.0
	result["current_steering"] = 0.0
	result["lost_grip"] = false
	result["handbrake_accumulator"] = 0
	result["force"] = 0.0
	result["gear_shift_counter"] = 0
	result["shifted_down"] = false
	result["has_contact_with_ground"] = not self.is_airborne(data)
	result["g_transfer"] = 0.0
	return result


func body(data: Dictionary):
	var params = self.make_params(data)
	var expected_linear = Vector3(float(data["result_global_linear_velocity_x"]), float(data["result_global_linear_velocity_y"]), float(data["result_global_linear_velocity_z"]))
	var expected_angular = Vector3(float(data["result_global_angular_velocity_x"]), float(data["result_global_angular_velocity_y"]), float(data["result_global_angular_velocity_z"]))
	var result = self.model.integrate(self.model.near_stop_deceleration_cm).call(params)
	var msg = "thr=" + str(params["throttle"]) + " brk=" + str(params["brake"]) + " gear=" + str(params["gear"]) + " v=" + str(params["linear_velocity"])
	assert_almost_eq(result["linear_velocity"], expected_linear, EPSILON * Vector3.ONE, "vel " + msg)
	assert_almost_eq(result["angular_velocity"], expected_angular, EPSILON * Vector3.ONE, "ang " + msg)
