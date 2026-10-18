extends Control
class_name TrackPicker

@export var config: TrackConfig = TrackConfig.new()

@onready var track_selection: SyncableOptionButton = %TrackSelection
@onready var configure_panel: PopupPanel = $ConfigurePanel
@onready var configure_button: Button = %ConfigureButton
@onready var night_button: CheckButton = %NightButton
@onready var weather_button: CheckButton = %WeatherButton

signal track_selected


func _ready():
	TrackDB.database_updated.connect(self._on_track_database_updated)
	configure_panel.popup_window = false


func disable():
	configure_button.disabled = true
	track_selection.disabled = true


func enable():
	configure_button.disabled = false
	track_selection.disabled = false


func _on_track_database_updated():
	for track in TrackDB.tracks.values():
		track_selection.add_syncable_item(track.name, track.uuid)


func _on_track_selection_syncable_item_selected(uuid):
	self.config.track_uuid = uuid
	self._emit_config()


func _emit_config():
	if self.config.track_uuid.is_empty():
		return
	self.track_selected.emit(self.config.duplicate(true))


func _on_configure_button_pressed():
	configure_panel.show()


func _on_night_button_toggled(toggled_on):
	self.config.night = toggled_on
	self._emit_config()


func _on_weather_button_toggled(toggled_on):
	self.config.weather = toggled_on
	self._emit_config()


func _on_mirror_button_toggled(toggled_on):
	self.config.mirrored = toggled_on
	self._emit_config()
