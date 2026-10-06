extends CsvTest

var sample := EngineSample.new()

func get_csv() -> FileAccess:
	return FileAccess.open("res://tests/audio/data/volume_calculate.csv", FileAccess.READ)


func body(data: Dictionary):
	var volume_value := int(data["volume"])
	var is_load: bool = data["is_load"] != "0"
	var is_rear: bool = data["rear"] != "0"
	var gas := int(data["gas"])
	var mix := int(data["mix"])
	var expected := int(data["result"])
	var result := self.sample.volume_calculate_re(volume_value, is_load, is_rear, gas, mix)
	var msg := "v=" + str(volume_value) \
			+ " load=" + str(is_load) \
			+ " rear=" + str(is_rear) \
			+ " gas=" + str(gas) \
			+ " mix=" + str(mix)
	assert_eq(result, expected, msg)
