extends Node

@export var steering_enabled: bool = true

@export_range(-1.0, 1.0) var steering := 0.0:
	set(value):
		steering = clamp(value, -1.0, 1.0)
	get:
		return steering

@export_range(0.0, 1.0) var throttle := 0.0:
	set(value):
		throttle = clamp(value, 0.0, 1.0)
	get:
		return throttle

@export_range(0.0, 1.0) var brake := 0.0:
	set(value):
		brake = clamp(value, 0.0, 1.0)
	get:
		return brake

@export var gear := CarTypes.Gear.NEUTRAL:
	set(value):
		gear = clamp(value, CarTypes.Gear.REVERSE, self.max_gear)
	get:
		return gear

@export var handbrake := false

@export var lights_on := false

signal reposition_requested

var max_gear := CarTypes.Gear.GEAR_6


func shift_up():
	self.gear += 1


func shift_down():
	self.gear -= 1


func set_max_gear(value: CarTypes.Gear):
	self.max_gear = value


func _input(event: InputEvent):
	if self.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	if event.is_action_pressed("shift_up"):
		self.shift_up()
	if event.is_action_pressed("shift_down"):
		self.shift_down()
	if event.is_action_pressed("lights"):
		self.lights_on = not self.lights_on
	self.steering = Input.get_axis("turn_right", "turn_left")
	self.handbrake = Input.is_action_pressed("handbrake")
	self.throttle = Input.get_action_strength("accelerate")
	self.brake = Input.get_action_strength("brake")


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		self.reposition.rpc()


@rpc("authority", "call_local", "reliable")
func reposition():
	self.reposition_requested.emit()
