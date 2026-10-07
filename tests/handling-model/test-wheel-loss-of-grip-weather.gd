extends "res://tests/handling-model/test-wheel-loss-of-grip.gd"


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/wheel_force_loss_of_grip_weather.csv", FileAccess.READ
	)
