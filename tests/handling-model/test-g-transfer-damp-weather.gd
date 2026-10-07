extends "res://tests/handling-model/test-g-transfer-damp.gd"

func get_csv() -> FileAccess:
	return FileAccess.open(
		"res://tests/handling-model/data/g_transfer_damp_weather.csv", FileAccess.READ
	)
