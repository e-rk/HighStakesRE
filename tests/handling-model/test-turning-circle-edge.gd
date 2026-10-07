extends "res://tests/handling-model/test-turning-circle.gd"


func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/handling-model/data/turning_circle_edge.csv", FileAccess.READ)
