extends CsvTest

var model: HandlingModelRE

var result := HandlingModelRE.HandlingOutput.new()

const EPSILON = 0.00001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/handbrake_longitudinal_damping.csv", FileAccess.READ
	)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.basis_to_road = Basis()
	params.linear_velocity = self.local_linear_velocity(data)
	params.handbrake = self.handbrake(data)
	params.lost_grip = false
	params.weather = self.weather(data)
	params.gear = self.gear(data) as CarTypes.Gear
	params.timestep = 1.0 / 32.0
	self.model.integrate(self.model.damp_longitudinal_velocity_cm).call(params, result)
	var expected := self.vector3("result_local_linear_velocity", data)
	var msg: String = "hb=" + data.handbrake + " weather=" + data.weather + " gear=" + data.gear \
			+ " v=" + str(params.linear_velocity)
	assert_almost_eq(result.linear_velocity, expected, EPSILON * Vector3.ONE, msg)
