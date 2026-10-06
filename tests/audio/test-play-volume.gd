extends CsvTest

var sample := EngineSample.new()

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/play_volume.csv", FileAccess.READ)


func body(data: Dictionary):
	self.sample.volume = int(data["volume"])
	self.sample.volume_random_range = int(data["volume_random_range"])
	var velocity := int(data["velocity"])
	var random := int(data["random"])
	var expected := int(data["result"])
	var result := self.sample.play_volume(velocity, random)
	var msg := "volume=" + str(self.sample.volume) \
			+ " range=" + str(self.sample.volume_random_range) \
			+ " velocity=" + str(velocity) \
			+ " random=" + str(random)
	assert_eq(result, expected, msg)
