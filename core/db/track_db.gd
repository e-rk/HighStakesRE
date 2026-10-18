extends Node
class_name TrackDatabase

signal database_updated

@onready var watcher = %DirectoryWatcher

var tracks: Dictionary[String, TrackData] = {}


class TrackData:
	var name: String
	var path: String
	var uuid: String

	func get_path(weather: bool, night: bool) -> String:
		var suffix: String = TrackDatabase._weather_suffix(weather, night)
		return "%s/%s%s.glb" % [self.path, self.name, suffix]


func get_track_by_uuid(uuid: String) -> TrackData:
	return tracks[uuid]


static func _weather_suffix(weather: bool, night: bool) -> String:
	match [weather, night]:
		[false, false]:
			return ""
		[false, true]:
			return "-n"
		[true, false]:
			return "-w"
		[true, true]:
			return "-nw"
	return ""

func _make_track_data(directory: String, file: String) -> TrackData:
	var track_directory = "%s/%s" % [directory, file]
	var path = "%s/%s.glb.import" % [track_directory, file]
	if not FileAccess.file_exists(path):
		return null
	var uuid = path
	var track = TrackData.new()
	track.name = file
	track.path = track_directory
	track.uuid = uuid
	return track


func _on_directory_watcher_content_changed():
	var new_tracks: Dictionary[String, TrackData] = {}
	var files = watcher.files.duplicate()
	files.sort()
	for file in files:
		var track = self._make_track_data(watcher.directory, file)
		if track:
			new_tracks[track.uuid] = track
	self.tracks = new_tracks
	self.database_updated.emit()
