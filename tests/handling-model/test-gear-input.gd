extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

var result := HandlingModelRE.HandlingOutput.new()


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/gear_input.csv", FileAccess.READ)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.performance = self.performance
	params.gear = self.gear(data) as CarTypes.Gear
	params.next_gear = self.next_gear(data) as CarTypes.Gear
	params.gear_shift_counter = int(data.gear_shift_counter)
	params.shifted_down = data.shifted_down != "0"
	params.controls_locked = data.controls_locked != "0"
	self.model.process_gear_input_cm(params, result)
	var msg: String = "gear=" + data.gear + " next=" + data.next_gear + " counter=" + data.gear_shift_counter \
			+ " locked=" + data.controls_locked
	assert_eq(result.gear, int(data.result_gear), "gear " + msg)
	assert_eq(result.gear_shift_counter, int(data.result_gear_shift_counter), "counter " + msg)
	assert_eq(result.shifted_down, data.result_shifted_down != "0", "shifted down " + msg)
