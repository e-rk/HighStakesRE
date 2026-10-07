extends "res://tests/handling-model/test-steering-input.gd"


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/steering_ramp.csv", FileAccess.READ)
