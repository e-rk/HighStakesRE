extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance.duplicate() as CarPerformance

const EPSILON = 0.0001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/torque_curve_tail.csv", FileAccess.READ)


func body(data: Dictionary):
	var curve := self.performance.torque_curve.duplicate()
	curve[19] = float(data.torque_19)
	curve[20] = float(data.torque_20)
	self.performance.torque_curve = curve
	var result := self.model.torque_for_rpm(self.performance, int(data.rpm))
	var msg: String = "rpm=" + data.rpm + " tail=" + data.torque_19 + "/" + data.torque_20
	assert_almost_eq(result, float(data.result_torque), EPSILON, msg)
