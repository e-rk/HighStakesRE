extends CsvTest

var model: HandlingModelRE

@onready var car: Car = preload("res://import/cars/b911/b911.glb").instantiate()
@onready var spectator = preload("res://core/gameplay/player_spectator.tscn").instantiate()

const EPSILON = 0.00001


func before_all():
	self.add_child_autofree(spectator)
	self.add_child_autofree(car)
	self.model = HandlingModelRE.new()


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/camera/data/heli_camera_position.csv", FileAccess.READ
	)


func body(data: Dictionary):
	car.basis = self.basis(data)
	car.position = self.global_position(data)
	car.linear_velocity = car.basis * self.local_linear_velocity(data)
	car.linear_acceleration = car.basis * self.local_linear_acceleration(data)
	spectator.previous_global_offset = self.global_camera_offset(data)
	spectator.set_target_position(self.local_offset(data))
	spectator.camera_arm.notification(NOTIFICATION_INTERNAL_PHYSICS_PROCESS)  # Simulate single physics tick
	spectator.factor = float(data["interpolation_factor"])
	var expected = self.result_global_camera_position(data)
	var result = self.spectator.interpolate_camera(car)
	var msg = "ln=" + str(self.current_line) \
			+ " v=" + str(self.local_linear_velocity(data)) \
			+ " a=" + str(self.local_linear_acceleration(data)) \
			+ " pos=" + str(self.global_position(data)) \
			+ " goff=" + str(self.global_camera_offset(data))
	assert_almost_eq(result, expected, Vector3.ONE * EPSILON, msg)
