extends "res://tests/handling-model/test-braking.gd"


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/braking_force_spoiler.csv", FileAccess.READ)
