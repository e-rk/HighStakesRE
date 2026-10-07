extends CsvTest

var model: HandlingModelRE

const EPSILON = 0.00001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/wheel_slope_tilted.csv", FileAccess.READ)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.basis_to_road = self.basis_to_road(data)
	params.basis = self.basis(data)
	params.weather = self.weather(data)
	var forces := Vector3(float(data.wheel_lateral_force), 0, float(data.wheel_longitudal_force))
	var expected_forces := Vector3(
		float(data.result_wheel_lateral_force), 0, float(data.result_wheel_longitudal_force)
	)
	var wheel_data := HandlingModelRE.WheelData.new()
	wheel_data.road_surface = self.road_surface(data)
	var msg: String = "road normal=" + str(params.basis_to_road.y) + " car up=" + str(params.basis.y) \
			+ " surface=" + data.road_surface + " weather=" + data.weather
	assert_almost_eq(self.model.wheel_slope_vector(params, forces), expected_forces, EPSILON * Vector3.ONE, msg)
	assert_almost_eq(
		self.model.wheel_surface_grip_factor(params, wheel_data), float(data.result_surface_grip), EPSILON, msg
	)
