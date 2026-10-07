extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var performance: CarPerformance = car.performance

var result := HandlingModelRE.HandlingOutput.new()

const EPSILON = 0.00001


func before_all():
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/traction.csv", FileAccess.READ)


func body(data: Dictionary):
	var params := HandlingModelRE.HandlingState.new()
	params.performance = self.performance
	params.basis_to_road = self.basis_to_road(data)
	params.basis = params.basis_to_road
	params.linear_velocity = self.global_linear_velocity(data)
	params.angular_velocity = self.global_angular_velocity(data)
	params.gear = CarTypes.Gear.GEAR_2
	params.next_gear = CarTypes.Gear.GEAR_2
	params.rpm = 3000
	params.throttle = 1.0
	params.throttle_input = 1.0
	params.has_contact_with_ground = true
	params.gravity_vector = Vector3(0, -9.81, 0)
	params.timestep = 1.0 / 32.0
	params.mass = 1275.0
	params.inertia_inv = Vector3(0, 0.00038336761645041406, 0)
	params.wheels = [
		{"type": CarTypes.Wheel.FRONT_RIGHT, "road_surface": 1},
		{"type": CarTypes.Wheel.FRONT_LEFT, "road_surface": 1},
		{"type": CarTypes.Wheel.REAR_RIGHT, "road_surface": 1},
		{"type": CarTypes.Wheel.REAR_LEFT, "road_surface": 1},
	]
	var msg: String = "road normal=" + str(params.basis_to_road.y) + " v=" + str(params.linear_velocity)
	self.model.traction_pipeline(params, result)
	assert_almost_eq(
		params.linear_velocity, self.result_global_linear_velocity(data), EPSILON * Vector3.ONE, msg
	)
	assert_almost_eq(
		params.angular_velocity, self.result_global_angular_velocity(data), EPSILON * Vector3.ONE, msg
	)
