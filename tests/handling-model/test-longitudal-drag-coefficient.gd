extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

const EPSILON = 0.00000001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/longitudal_drag_coefficient.csv", FileAccess.READ)


func make_params(_data: Dictionary) -> HandlingModelRE.HandlingState:
	var result := HandlingModelRE.HandlingState.new()
	result.performance = self.performance
	return result


func body(data: Dictionary):
	var params := self.make_params(data)
	var expected := float(data["longitudal_drag_coefficient"])
	var result := self.model.longitudal_drag_coefficient(params)
	assert_almost_eq(result, expected, EPSILON)
