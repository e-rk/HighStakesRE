extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

var result := HandlingModelRE.HandlingOutput.new()

const EPSILON = 0.000000001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/prevent_moving_sideways.csv", FileAccess.READ
	)


func make_params(data: Dictionary) -> HandlingModelRE.HandlingState:
	var result = HandlingModelRE.HandlingState.new()
	result.performance = self.performance
	result.basis_to_road = self.basis_to_road(data)
	result.linear_velocity = self.global_linear_velocity(data)
	result.current_steering = self.steering(data)
	result.throttle = self.throttle(data)
	result.brake = self.brake(data)
	return result


func body(data: Dictionary):
	var params = self.make_params(data)
	var expected = Vector3(float(data.result_global_linear_velocity_x), float(data.result_global_linear_velocity_y), float(data.result_global_linear_velocity_z))
	params.stop_moving_sideways = self.model.is_moving_sideways_locked(params)
	self.model.prevent_moving_sideways_cm(params, result)
	var msg = "thr=" + str(params.throttle) + " brk=" + str(params.brake) + " str=" + str(params.current_steering) + " v=" + str(params.linear_velocity)
	assert_almost_eq(result.linear_velocity, expected, EPSILON * Vector3.ONE, msg)
