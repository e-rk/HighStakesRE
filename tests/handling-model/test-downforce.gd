extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

var result := HandlingModelRE.HandlingOutput.new()

const EPSILON = 0.00001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/downforce.csv", FileAccess.READ)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.performance = self.performance
	params.basis = self.basis(data)
	params.basis_to_road = self.basis_to_road(data)
	params.linear_velocity = self.global_linear_velocity(data)
	params.timestep = 1.0 / 32.0
	self.model.integrate(self.model.downforce_cm).call(params, result)
	var msg: String = "car up=" + str(params.basis.y) + " v=" + str(params.linear_velocity)
	assert_almost_eq(
		result.linear_velocity, self.result_global_linear_velocity(data), EPSILON * Vector3.ONE, msg
	)
