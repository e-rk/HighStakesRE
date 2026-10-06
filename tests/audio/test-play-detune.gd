extends CsvTest

var sample := EngineSample.new()

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/play_detune.csv", FileAccess.READ)


func body(data: Dictionary):
	self.sample.root_key = int(data["root_key"])
	self.sample.detune = int(data["detune"])
	self.sample.detune_random_range = int(data["detune_random_range"])
	var note := int(data["note"])
	var random := int(data["random"])
	var expected := int(data["result"])
	var result := self.sample.play_detune(note, random)
	var msg := "root_key=" + str(self.sample.root_key) \
			+ " detune=" + str(self.sample.detune) \
			+ " range=" + str(self.sample.detune_random_range) \
			+ " note=" + str(note) \
			+ " random=" + str(random)
	assert_eq(result, expected, msg)
