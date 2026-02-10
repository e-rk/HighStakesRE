extends CsvTest

var emitter = preload("res://core/car/car_engine_audio.tscn").instantiate()

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/pitch_calculate.csv", FileAccess.READ)


func body(data: Dictionary):
	var value = int(data["bendval"]) >> 24
	var unknown1 = int(data["unknown1"])
	var unknown2 = int(data["unknown2"])
	var expected = int(data["result"])
	var result = self.emitter.pitch_calculate(value, unknown1, unknown2)
	var msg = "v=" + str(value) \
			+ " u1=" + str(unknown1) \
			+ " u2=" + str(unknown2)
	assert_eq(result, expected, msg)
