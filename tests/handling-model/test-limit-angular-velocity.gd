extends CsvTest

var model: HandlingModelRE

var result := HandlingModelRE.HandlingOutput.new()

const EPSILON = 0.00001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/limit_angular_velocity.csv", FileAccess.READ)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.angular_velocity = self.global_angular_velocity(data)
	self.model.limit_angular_velocity_cm(params, result)
	assert_almost_eq(
		result.angular_velocity, self.result_global_angular_velocity(data), EPSILON * Vector3.ONE,
		"w=" + str(params.angular_velocity)
	)
