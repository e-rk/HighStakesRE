extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

var result := HandlingModelRE.HandlingOutput.new()

const EPSILON = 0.0001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/brake_input.csv", FileAccess.READ)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.performance = self.performance
	params.brake = float(data.brake)
	params.brake_input = self.brake_input(data)
	params.controls_locked = data.controls_locked != "0"
	params.timestep = 1.0 / 32.0
	self.model.process_brake_input_cm(params, result)
	var msg: String = "brake=" + data.brake + " input=" + data.brake_input + " locked=" + data.controls_locked
	assert_almost_eq(result.brake, float(data.result_brake), EPSILON, msg)
