class_name PlayerConfig
extends Resource

@export var player_name: String
@export var car_uuid: String
@export var color_primary: Color
@export var color_secondary: Color
@export var color_driver: Color
@export var color_interior: Color


func serialize() -> Dictionary:
	return {
		"player_name": self.player_name,
		"car_uuid": self.car_uuid,
		"color_set": {
			"primary": self.color_primary,
			"secondary": self.color_secondary,
			"driver": self.color_driver,
			"interior": self.color_interior,
		}
	}


static func deserialize(data: Dictionary) -> PlayerConfig:
	var result = PlayerConfig.new()
	result.player_name = data["player_name"]
	result.car_uuid = data["car_uuid"]
	var color_set_data = data["color_set"]
	result.color_primary = color_set_data["primary"]
	result.color_secondary = color_set_data["secondary"]
	result.color_driver = color_set_data["driver"]
	result.color_interior = color_set_data["interior"]
	return result
