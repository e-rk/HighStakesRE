extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

var EPSILON = 0.000001

func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/handbrake_loss.csv", FileAccess.READ)


func make_params(data: Dictionary) -> HandlingModelRE.HandlingState:
	var result = HandlingModelRE.HandlingState.new()
	result.handbrake_accumulator = self.handbrake_accumulator(data)
	result.weather = self.weather(data)
	result.gear = self.gear(data)
	return result


func body(data: Dictionary):
	var params = self.make_params(data)
	var expected = self.wheel_force(data)
	var planar_vector = self.wheel_planar_vector(data)
	var wheel_traction = self.wheel_traction(data)
	var wheel_data := HandlingModelRE.WheelData.new()
	wheel_data.grip = self.wheel_lateral_grip(data)
	wheel_data.downforce = self.wheel_downforce2(data)
	wheel_data.handbrake_accumulator = params.handbrake_accumulator
	var result = self.model.handbrake_loss_of_grip(params, wheel_data, planar_vector, wheel_traction)
	var msg = "hba=" + str(params.handbrake_accumulator) + " trc=" + str(wheel_traction)
	assert_almost_eq(result, expected, EPSILON * Vector3.ONE, msg)
