extends CsvTest

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/calc_volume.csv", FileAccess.READ)


func body(data: Dictionary):
	var master := int(data["master"])
	var request_volume := int(data["request_volume"])
	var timbre_volume := int(data["timbre_volume"])
	var envelope := int(data["envelope"])
	var expected := int(data["result"])
	var result := EngineSample.calc_volume_re(master, request_volume, timbre_volume, envelope)
	var msg := "master=" + str(master) \
			+ " request=" + str(request_volume) \
			+ " timbre=" + str(timbre_volume) \
			+ " envelope=" + str(envelope)
	assert_eq(result, expected, msg)
