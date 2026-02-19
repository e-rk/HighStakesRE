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
var previous_gear: int = 0


func _ready():
	assert(self.name.is_valid_int())
	self.authority = self.name.to_int()
	var color_set = CarColorSet.from_colors(primary_color, secondary_color, driver_color, interior_color)
	var car = CarDB.get_car_by_uuid(self.car_uuid)
	self.car = load(car.path).instantiate()
	self.car.global_transform = initial_transform
	self.add_child(self.car)
	self.car.owner = self
	self.car.color = color_set


func is_local() -> bool:
	return self.authority == multiplayer.get_unique_id()


func _physics_process(_delta):
	var input_gear = self.input.gear
	if not self.disable_steering:
		car.brake = input.brake
		car.steering = input.steering
		car.handbrake = input.handbrake
		if self.previous_gear != input_gear:
			# Gear change by difference to avoid duplicated states.
			car.gear += (input_gear - previous_gear)
	else:
		car.brake = 1.0
		car.handbrake = false
		car.gear = CarTypes.Gear.NEUTRAL
		car.steering = 0.0
	self.previous_gear = input_gear
	car.throttle = input.throttle
	car.lights_on = input.lights_on
	car.siren_on = input.siren_on

func _on_input_reposition_requested():
	self.reposition_requested.emit()
