extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance.duplicate() as CarPerformance


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/wheel_rpm_rounding.csv", FileAccess.READ)


func body(data: Dictionary):
	var ratios := self.performance.manual_velocity_to_rpm_ratio.duplicate()
	ratios[CarTypes.Gear.GEAR_1] = float(data.velocity_to_rpm_ratio)
	self.performance.manual_velocity_to_rpm_ratio = ratios
	var state := HandlingModelRE.TractionState.new()
	state.performance = self.performance
	state.gear = CarTypes.Gear.GEAR_1
	state.linear_velocity = Vector3(0, 0, float(data.local_linear_velocity_z))
	var msg: String = "v.z=" + data.local_linear_velocity_z + " ratio=" + data.velocity_to_rpm_ratio
	assert_eq(self.model.rpm_from_velocity_rounded(state), int(data.result_wheel_rpm), msg)
