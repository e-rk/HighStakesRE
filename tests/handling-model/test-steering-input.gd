extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance.duplicate() as CarPerformance

var result := HandlingModelRE.HandlingOutput.new()

const EPSILON = 0.0001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/steering_input.csv", FileAccess.READ)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.performance = self.performance
	if data.has("turn_in_ramp"):
		params.performance.turn_in_ramp = float(data.turn_in_ramp)
		params.performance.turn_out_ramp = float(data.turn_out_ramp)
	params.current_steering = float(data.current_steering)
	params.turn_input = float(data.steering_input) / 128.0
	params.timestep = 1.0 / 32.0
	self.model.process_steering_input_cm(params, result)
	var msg: String = "current=" + data.current_steering + " input=" + data.steering_input \
			+ " ramps=" + str(params.performance.turn_in_ramp) + "/" + str(params.performance.turn_out_ramp)
	assert_almost_eq(result.current_steering, float(data.result_current_steering), EPSILON, msg)
