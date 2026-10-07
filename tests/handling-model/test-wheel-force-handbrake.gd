extends "res://tests/handling-model/test-wheel-force-calculation.gd"


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/wheel_force_handbrake.csv", FileAccess.READ)
