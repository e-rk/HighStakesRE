extends CsvTest

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/randrange.csv", FileAccess.READ)


func body(data: Dictionary):
	var limit := int(data["limit"])
	var random := int(data["random"])
	var expected := int(data["result"])
	var result := EngineSample.randrange(limit, random)
	var msg := "limit=" + str(limit) + " random=" + str(random)
	assert_eq(result, expected, msg)
