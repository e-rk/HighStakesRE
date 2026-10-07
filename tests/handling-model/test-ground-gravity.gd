extends CsvTest

var model: HandlingModelRE

var result := HandlingModelRE.HandlingOutput.new()

const EPSILON = 0.00001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/ground_gravity.csv", FileAccess.READ)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.basis_to_road = self.basis_to_road(data)
	params.basis = self.basis(data)
	params.gravity_vector = Vector3(0, -9.81, 0)
	params.timestep = 1.0 / 32.0
	self.model.integrate(self.model.ground_gravity_cm).call(params, result)
	var msg: String = "road normal=" + str(params.basis_to_road.y) + " car up=" + str(params.basis.y)
	assert_almost_eq(
		result.linear_velocity, self.result_global_linear_velocity(data), EPSILON * Vector3.ONE, msg
	)
