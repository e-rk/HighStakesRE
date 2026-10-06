extends CsvTest

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/front_rear_mix.csv", FileAccess.READ)


func body(data: Dictionary):
	var forward := int(data["forward"])
	var distance := int(data["distance"])
	var expected := int(data["mix"])
	var result := EngineSample.front_rear_mix(forward, distance)
	var msg := "forward=" + str(forward) + " distance=" + str(distance)
	assert_eq(result, expected, msg)
