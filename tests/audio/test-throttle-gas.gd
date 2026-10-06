extends CsvTest

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/throttle_gas.csv", FileAccess.READ)


func body(data: Dictionary):
	var throttle := float(data["throttle"])
	var expected := int(data["gas"])
	var result := EngineSample.gas_from_throttle(throttle)
	var msg := "throttle=" + str(throttle)
	assert_eq(result, expected, msg)
