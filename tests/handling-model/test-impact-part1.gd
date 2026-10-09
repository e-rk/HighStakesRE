extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

const EPSILON = 0.00001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/calculate_impact_part1.csv", FileAccess.READ
	)


func make_params(data: Dictionary) -> HandlingModelRE.CollisionParams:
	var result = HandlingModelRE.CollisionParams.new()
	result.basis = self.basis(data)
	result.angular_velocity = self.global_angular_velocity(data)
	result.linear_velocity = self.global_linear_velocity(data)
	result.mass = self.mass(data)
	result.inertia_inv = self.inertia_inv(data)
	result.position = self.global_position(data)
	result.friction = float(data["object_friction"])
	return result


func body(data: Dictionary):
	if current_line == 3:
		pass
	var params = self.make_params(data)
	var obj_position = self.vector3("obj_position", data)
	var collision_point = self.vector3("collision_point", data)
	var normal = self.vector3("normal", data)
	var friction = float(data["maybe_friction"])
	var expected_linear_velocity = self.result_global_linear_velocity(data)
	var expected_angular_velocity = self.result_global_angular_velocity(data)
	var expected_position = self.vector3("result_global_position", data)
	var result = HandlingModelRE.CollisionOutput.new()
	self.model.calculate_impact(params, obj_position, collision_point, normal, friction, result)
	assert_almost_eq(result["linear_velocity"], expected_linear_velocity, EPSILON * Vector3.ONE, " ln=" + str(self.current_line))
	assert_almost_eq(result["angular_velocity"], expected_angular_velocity, EPSILON * Vector3.ONE)
	assert_almost_eq(result["position"], expected_position, EPSILON * Vector3.ONE)
