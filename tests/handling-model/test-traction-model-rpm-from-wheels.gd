extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance


func before_all():
	self.model = HandlingModelRE.new()

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/traction_model_rpm_from_wheels.csv", FileAccess.READ)

func make_params(data: Dictionary) -> HandlingModelRE.TractionState:
	var result = HandlingModelRE.TractionState.new()
	result.performance = self.performance
	result.linear_velocity = self.local_linear_velocity(data)
	result.gear = self.gear(data)
	return result

func body(data: Dictionary):
	var params = self.make_params(data)
	var expected_rpm := roundi(float(data.result_rpm_from_wheels))
	var result := self.model.rpm_from_velocity_rounded(params)
	var msg = "v.z=" + str(params.linear_velocity.z) \
			+ " gear=" + str(params.gear) \
			+ " res=" + str(self.model.rpm_from_velocity(params))
	assert_eq(result, expected_rpm, msg)
