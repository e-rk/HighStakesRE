class_name Player
extends Node

@export var car_uuid: String
@export var player_name: String
@export var initial_transform: Transform3D
@export var disable_steering := false
@export var primary_color: Color
@export var secondary_color: Color
@export var interior_color: Color
@export var driver_color: Color
@export var position_along_track: float = 0.0
@export var current_node_idx: float = 0.0
@export var night: bool = false

signal reposition_requested

var car: Car = null
var player_avoidance_data := OptimizerServer.ObstacleData.new()


func _ready():
	var color_set = CarColorSet.from_colors(primary_color, secondary_color, driver_color, interior_color)
	var car = CarDB.get_car_by_uuid(self.car_uuid)
	self.car = load(car.path).instantiate()
	self.car.global_transform = initial_transform
	self.add_child(self.car)
	self.car.owner = self
	self.car.color = color_set
	if self.night:
		self.car.lights_on = true
	if self.car.license_plate:
		self.car.license_plate.text = self.player_name
	self._update_static_player_avoidance()


func is_local() -> bool:
	return false


func is_ai() -> bool:
	return false


func _update_static_player_avoidance():
	player_avoidance_data.dimensions = car.dimensions()


func _update_dynamic_player_avoidance():
	player_avoidance_data.position = car.global_position
	player_avoidance_data.velocity = car.linear_velocity
	player_avoidance_data.offset = current_node_idx
