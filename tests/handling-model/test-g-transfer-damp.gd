extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

const EPSILON = 0.0000001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/g_transfer_damp.csv", FileAccess.READ
	)


func make_params(data: Dictionary) -> HandlingModelRE.HandlingState:
	var result = HandlingModelRE.HandlingState.new()
	result.performance = self.performance
	result.g_transfer = self.g_transfer(data)
	result.weather = self.weather(data)
	result.drivetrain_overload = data.unknown_bool != "0"
	return result


func body(data: Dictionary):
	var params = self.make_params(data)
	var expected = float(data["result_g_transfer"])
	var result = self.model.g_transfer_damp(params)
	var msg = "gt=" + str(params["g_transfer"]) \
			+ " weather=" + str(params["weather"]) \
			+ " overload=" + str(params.drivetrain_overload)
	assert_almost_eq(result, expected, EPSILON, msg)
