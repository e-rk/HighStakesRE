extends "res://tests/handling-model/test-neutral-gear-deceleration.gd"


func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/damp_velocity_when_neutral_slope.csv", FileAccess.READ
	)
