extends CsvTest

var emitter = preload("res://core/car/car_engine_audio.tscn").instantiate()

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/pitch_detune.csv", FileAccess.READ)


func body(data: Dictionary):
	var value = int(data["value"])
	var expected = int(data["result"])
	var result = self.emitter.detune_to_linear(value)
	var msg = "v=" + str(value)
	assert_eq(result, expected, msg)
