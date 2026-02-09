extends Node
class_name CarDatabase

signal database_updated

@onready var watcher = %DirectoryWatcher

var cars: Dictionary = {}


class CarData:
	var name: String
	var path: String
	var uuid: String


func get_car_by_uuid(uuid: String) -> CarData:
	if cars.has(uuid):
		return cars[uuid]
	return null


func _on_directory_watcher_content_changed():
	var cars = {}
	var files = watcher.files.duplicate()
	files.sort()
	for file in files:
		var path = "%s/%s/%s.glb.import" % [watcher.directory, file, file]
		if not FileAccess.file_exists(path):
			continue
		path = path.trim_suffix(".import")
		var uuid = path
		var car = CarData.new()
		car.name = file
		car.path = path
		car.uuid = uuid
		cars[uuid] = car
	self.cars = cars
	self.database_updated.emit()
