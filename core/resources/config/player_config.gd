class_name PlayerConfig
extends Resource

@export var player_name: String
@export var car_uuid: String
@export var color_primary: Color
@export var color_secondary: Color
@export var color_driver: Color
@export var color_interior: Color


func get_color_set() -> CarColorSet:
	return CarColorSet.from_colors(color_primary, color_secondary, color_driver, color_interior)
