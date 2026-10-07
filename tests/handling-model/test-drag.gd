extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

const EPSILON = 0.000001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/drag.csv", FileAccess.READ)


func make_params(data: Dictionary) -> HandlingModelRE.HandlingState:
	var result := HandlingModelRE.HandlingState.new()
	result.performance = self.performance
	result.basis_to_road = Basis()
	result.linear_velocity = self.local_linear_velocity(data)
	return result


func body(data: Dictionary):
	var params := self.make_params(data)
	var expected := float(data["result"])
	var result := self.model.drag(params)
	var msg := "v=" + str(params.linear_velocity)
	assert_almost_eq(result, expected, EPSILON, msg)
