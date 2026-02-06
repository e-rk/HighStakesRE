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

signal reposition_requested

@onready var input = $Input

var car: Car = null
var authority = false


func _ready():
	assert(self.name.is_valid_int())
	self.authority = self.name.to_int()
	var color_set = CarColorSet.new()
	color_set.primary = primary_color
	color_set.secondary = secondary_color
	color_set.interior = interior_color
	color_set.driver = driver_color
	var car = CarDB.get_car_by_uuid(self.car_uuid)
	self.car = load(car.path).instantiate()
	self.car.global_transform = initial_transform
	self.add_child(self.car)
	self.car.color = color_set
	self.input.set_max_gear(self.car.max_gear())


func is_local() -> bool:
	return self.authority == multiplayer.get_unique_id()


func _physics_process(_delta):
	if not self.disable_steering:
		car.brake = input.brake
		car.throttle = input.throttle
	else:
		car.brake = 1.0
		car.throttle = 0.0
	car.steering = input.steering
	car.handbrake = input.handbrake
	car.gear = input.gear
	car.lights_on = input.lights_on


func _on_input_reposition_requested():
	self.reposition_requested.emit()
