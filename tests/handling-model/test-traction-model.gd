extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/B911/B911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

const EPSILON = 0.000001


func before_all():
	self.model = HandlingModelRE.new()

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/traction_model.csv", FileAccess.READ)

func make_params(data: Dictionary) -> Dictionary:
	var result = Dictionary()
	result["performance"] = self.performance
	result["basis_to_road"] = Basis()
	result["rpm"] = self.rpm(data)
	result["gear"] = self.gear(data)
	result["linear_velocity"] = self.local_linear_velocity(data)
	result["handbrake"] = self.handbrake(data)
	result["lost_grip"] = false
	result["throttle"] = self.throttle(data)
	result["weather"] = self.weather(data)
	result["slip_angle"] = self.slip_angle(data)
	result["brake"] = self.brake(data)
	result["shifted_down"] = data["unknown_engine_value"] != "0"
	result["gear_shift_counter"] = (int(data["unknown_engine_value2"]) >> 0x10)
	result["has_contact_with_ground"] = not self.is_airborne(data)
	result["handbrake_accumulator"] = self.handbrake_accumulator(data)
	result["speed_xz"] = self.speed_xz(data)
	return result

func body(data: Dictionary):
	var params = self.make_params(data)
	var expected_rpm = int(data["result_rpm"])
	var expected_gear = int(data["result_gear"])
	var expected_handbrake = data["result_handbrake"] != "0"
	var expected_force = float(data["result_force"])
	var result = self.model.traction_model(params)
	var msg = "rpm=" + str(params["rpm"]) \
			+ " gear=" + str(params["gear"]) \
			+ " thr=" + str(params["throttle"]) \
			+ " brk=" + str(params["brake"]) \
			+ " air=" + str(not params["has_contact_with_ground"]) \
			+ " v.z=" + str(params["linear_velocity"].z) \
			+ " sd=" + str(params["shifted_down"]) \
			+ " sc=" + str(params["gear_shift_counter"])
	assert_almost_eq(result["force"], expected_force, EPSILON, "force: " + msg)
	assert_eq(result["lost_grip"], expected_handbrake, "hb: " + msg)
	assert_eq(result["rpm"], expected_rpm, "rpm: " + msg)
