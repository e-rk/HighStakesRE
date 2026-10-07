extends CsvTest

var model: HandlingModelRE

var result := HandlingModelRE.HandlingOutput.new()

const EPSILON = 0.0001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/throttle_input.csv", FileAccess.READ)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.throttle = float(data.throttle)
	params.throttle_input = self.throttle_input(data)
	params.timestep = 1.0 / 32.0
	self.model.process_throttle_input_cm(params, result)
	var msg: String = "throttle=" + data.throttle + " input=" + data.throttle_input
	assert_almost_eq(result.throttle, float(data.result_throttle), EPSILON, msg)
