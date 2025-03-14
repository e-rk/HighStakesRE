extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/B911/B911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

const EPSILON = 0.0001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/braking_force.csv", FileAccess.READ)


func make_params(data: Dictionary) -> Dictionary:
	var result = Dictionary()
	result["performance"] = self.performance
	result["linear_velocity"] = self.local_linear_velocity(data)
	result["brake"] = self.brake(data)
	result["basis_to_road"] = Basis()
	result["handbrake"] = self.handbrake(data)
	result["lost_grip"] = false
	return result


func body(data: Dictionary):
	var params = self.make_params(data)
	var expected = -float(data["result_front_brake_force"])
	var wheel_data = { "type": CarTypes.Wheel.FRONT_RIGHT }
	var result = self.model.brake_force(params, wheel_data)
	var msg = "v=" + str(params["linear_velocity"])
	assert_almost_eq(result, expected, EPSILON, msg)
