extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/B911/B911.glb").instantiate()
@onready var performance: CarPerformance = car.performance


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/handbrake_accumulator.csv", FileAccess.READ)


func make_params(data: Dictionary) -> Dictionary:
	var result = Dictionary()
	result["handbrake"] = self.handbrake(data)
	result["lost_grip"] = false
	result["handbrake_accumulator"] = self.handbrake_accumulator(data)
	result["weather"] = self.weather(data)
	return result


func body(data: Dictionary):
	var params = self.make_params(data)
	var expected = int(data["result_handbrake_accumulator"])
	var result = self.model.update_handbrake_accumulator(params)
	var msg = "hb=" + str(params["handbrake"]) + " hba=" + str(params["handbrake_accumulator"])
	assert_eq(result, expected, msg)
