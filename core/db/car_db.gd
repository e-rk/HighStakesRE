extends Node
class_name CarDatabase

signal database_updated

@onready var watcher = %DirectoryWatcher

var cars: Dictionary = {}

enum CarClass { NONE, AAA, AA, A, B }

class CarData:
	var name: String
	var path: String
	var uuid: String
	var manifest: CarManifest


func get_car_by_uuid(uuid: String) -> CarData:
	if cars.has(uuid):
		return cars[uuid]
	return null


func _on_directory_watcher_content_changed():
	var new_cars = {}
	var files = watcher.files.duplicate()
	files.sort()
	for file in files:
		var path = "%s/%s/%s.glb" % [watcher.directory, file, file]
		var manifest_path = "%s/%s/%s_manifest.res" % [watcher.directory, file, file]
		if not ResourceLoader.exists(path) or not ResourceLoader.exists(manifest_path):
			continue
		path = path.trim_suffix(".import")
		var uuid = path
		var car = CarData.new()
		var manifest: CarManifest = load(manifest_path)
		car.name = manifest.name if manifest.name else file
		car.path = path
		car.uuid = uuid
		car.manifest = manifest
		new_cars[uuid] = car
	self.cars = new_cars
	self.database_updated.emit()
