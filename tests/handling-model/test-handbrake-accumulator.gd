extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/handbrake_accumulator.csv", FileAccess.READ)


func make_params(data: Dictionary) -> HandlingModelRE.HandlingState:
	var result = HandlingModelRE.HandlingState.new()
	result.handbrake = self.handbrake(data)
	result.lost_grip = false
	result.handbrake_accumulator = self.handbrake_accumulator(data)
	result.weather = self.weather(data)
	return result


func body(data: Dictionary):
	var params = self.make_params(data)
	var expected = int(data.result_handbrake_accumulator)
	var result = self.model.step_handbrake_accumulator(params, params.handbrake_accumulator)
	var msg = "hb=" + str(params.handbrake) + " hba=" + str(params.handbrake_accumulator)
	assert_eq(result, expected, msg)
