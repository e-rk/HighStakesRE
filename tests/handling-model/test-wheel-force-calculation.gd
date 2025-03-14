extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/B911/B911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

const EPSILON = 0.01


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/wheel_force_calculations.csv", FileAccess.READ
	)


func make_params(data: Dictionary) -> Dictionary:
	var result = Dictionary()
	result["performance"] = self.performance
	result["gear"] = self.gear(data)
	result["linear_velocity"] = self.local_linear_velocity(data)
	result["basis_to_road"] = Basis()
	result["angular_velocity"] = self.global_angular_velocity(data)
	result["current_steering"] = self.steering(data)
	result["throttle"] = self.throttle(data)
	result["handbrake"] = self.handbrake(data)
	result["lost_grip"] = false
	result["inertia_inv"] = self.inertia_inv(data)
	result["mass"] = self.mass(data)
	result["has_contact_with_ground"] = !self.is_airborne(data)
	result["weather"] = 0
	result["rpm"] = self.rpm(data)
	result["speed_xz"] = self.speed_xz(data)
	result["slip_angle"] = self.slip_angle(data)
	result["road_surface"] = self.road_surface(data)
	result["steering"] = self.wheel_steering(data)
	return result


func body(data: Dictionary):
	var params = self.make_params(data)
	var expected = self.wheel_force(data)
	var wheel_data = Dictionary()
	wheel_data["traction"] = self.wheel_traction(data)
	wheel_data["grip"] = self.wheel_lateral_grip(data)
	if self.wheel_is_front(data):
		wheel_data["type"] = CarTypes.Wheel.FRONT_LEFT
	else:
		wheel_data["type"] = CarTypes.Wheel.REAR_LEFT
	if expected.is_equal_approx(Vector3(2.863228, 0, 0.345538)):
		pass
	var result = self.model.wheel_force(params, wheel_data)
	var msg = "gear=" + str(params["gear"]) \
			+ " thr=" + str(params["throttle"]) \
			+ " trac=" + str(wheel_data["traction"]) \
			+ " grip=" + str(wheel_data["grip"]) \
			+ " typ=" + str(wheel_data["type"]) \
			+ " str=" + str(params["current_steering"]) \
			+ " hb=" + str(params["handbrake"]) \
			+ " v=" + str(params["linear_velocity"]) \
			+ " w=" + str(params["angular_velocity"])
	assert_almost_eq(result, expected, Vector3.ONE * EPSILON, msg)
