extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/B911/B911.glb").instantiate()
@onready var spectator = preload("res://core/gameplay/player_spectator.tscn").instantiate()

const EPSILON = 0.00001


func before_all():
	self.add_child_autofree(car)
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/heli_camera_position.csv", FileAccess.READ
	)
	

func body(data: Dictionary):
	car.basis = self.basis(data)
	car.position = self.global_position(data)
	car.linear_velocity = car.basis * self.local_linear_velocity(data)
	car.linear_acceleration = car.basis * self.local_linear_acceleration(data)
	spectator.position = car.position + self.global_camera_offset(data)
	spectator.offset = self.local_offset(data)
	spectator.factor = float(data["interpolation_factor"])
	var expected = self.result_global_camera_position(data)
	self.spectator.interpolate_camera(car)
	var pos = spectator.position
	assert_almost_eq(pos, expected, Vector3.ONE * EPSILON)
