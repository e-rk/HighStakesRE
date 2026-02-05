extends Control

@export var player := PlayerConfig.new()

signal player_config_changed
signal player_car_changed
signal player_color_changed
signal player_name_changed

const player_config_path = "user://last.player.tres"

@onready var player_name = %PlayerName
@onready var car_picker = %CarPicker
@onready var color_picker = %CarColorPicker


func _ready():
	var previous = load(player_config_path)
	if previous:
		apply_config.call_deferred(previous)


func apply_config(config: PlayerConfig):
	player_name.text = config.player_name
	self.player = config
	self.player_config_changed.emit()


func save_player():
	ResourceSaver.save(self.player, player_config_path)


func _on_car_picker_car_selected():
	self.player.car_uuid = car_picker.selected_car
	self.player_car_changed.emit()
	self.player_config_changed.emit()


func _on_player_name_text_submitted(new_text):
	player.player_name = new_text
	self.player_name_changed.emit()
	self.player_config_changed.emit()


func _on_car_color_picker_color_changed() -> void:
	var color_set = self.color_picker.selected_color_set
	self.player.color_primary = color_set.primary
	self.player.color_secondary = color_set.secondary
	self.player.color_interior = color_set.interior
	self.player.color_driver = color_set.driver
	self.player_color_changed.emit()
	self.player_config_changed.emit()
