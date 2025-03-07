extends CsvTest

var emitter = preload("res://core/car/car_engine_audio.tscn").instantiate()

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/pitch_calculate.csv", FileAccess.READ)


func body(data: Dictionary):
	var value = int(data["bendval"])
	var unknown1 = int(data["unknown1"])
	var expected = int(data["result"])
	var result = self.emitter.pitch_calculate(value, unknown1)
	var msg = "v=" + str(value) \
			+ " u=" + str(unknown1)
	assert_eq(result, expected, msg)
