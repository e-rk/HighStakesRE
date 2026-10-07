extends CsvTest

var model: HandlingModelRE

var result := HandlingModelRE.HandlingOutput.new()

const EPSILON = 0.00001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/airborne_drag.csv", FileAccess.READ)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.basis = self.basis(data)
	params.linear_velocity = self.global_linear_velocity(data)
	params.timestep = 1.0 / 32.0
	self.model.integrate(self.model.airborne_drag_cm).call(params, result)
	var msg: String = "basis=" + str(params.basis) + " v=" + str(params.linear_velocity)
	assert_almost_eq(
		result.linear_velocity, self.result_global_linear_velocity(data), EPSILON * Vector3.ONE, msg
	)
