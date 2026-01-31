extends Node
class_name TrackDatabase

signal database_updated

@onready var watcher = %DirectoryWatcher

var tracks: Dictionary = {}


class TrackData:
	var name: String
	var path: String
	var uuid: String


func get_track_by_uuid(uuid: String) -> TrackData:
	return tracks[uuid]


func _on_directory_watcher_content_changed():
	var tracks = {}
	for file in watcher.files:
		var path = "%s/%s/%s.glb.import" % [watcher.directory, file, file]
		if not FileAccess.file_exists(path):
			continue
		path = path.trim_suffix(".import")
		var uuid = path
		var car = TrackData.new()
		car.name = file
		car.path = path
		car.uuid = uuid
		tracks[uuid] = car
	self.tracks = tracks
	self.database_updated.emit()
