extends CsvTest

var sample = EngineSample.new()

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/pitch_calculate.csv", FileAccess.READ)


func body(data: Dictionary):
	var value = int(data["bendval"]) >> 24
	var unknown1 = int(data["unknown1"])
	var unknown2 = int(data["unknown2"])
	var expected = int(data["result"])
	var result = self.sample.pitch_calculate_re(value, unknown1, unknown2)
	var msg = "v=" + str(value) \
			+ " u1=" + str(unknown1) \
			+ " u2=" + str(unknown2)
	assert_eq(result, expected, msg)
