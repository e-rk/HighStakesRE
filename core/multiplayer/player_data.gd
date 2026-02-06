class_name PlayerData
extends Node

@export var car_uuid: String
@export var player_name: String
@export var color_primary: Color
@export var color_secondary: Color
@export var color_interior: Color
@export var color_driver: Color
@export var player_status: Constants.PlayerStatus:
	set(value):
		player_status = value
		self.player_data_changed.emit()
	get:
		return player_status

signal player_data_changed


func _enter_tree() -> void:
	if self.name.is_valid_int():
		self.set_multiplayer_authority(self.name.to_int())


func get_config() -> PlayerConfig:
	var config = PlayerConfig.new()
	config.car_uuid = car_uuid
	config.player_name = player_name
	config.color_primary = color_primary
	config.color_secondary = color_secondary
	config.color_interior = color_interior
	config.color_driver = color_driver
	return config


func set_config(config: PlayerConfig):
	car_uuid = config.car_uuid
	player_name = config.player_name
	color_primary = config.color_primary
	color_secondary = config.color_secondary
	color_interior = config.color_interior
	color_driver = config.color_driver
	self.player_data_changed.emit()


func get_player_id() -> int:
	return self.name.to_int()


func _on_multiplayer_synchronizer_delta_synchronized():
	self.player_data_changed.emit()
