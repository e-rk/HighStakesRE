extends SubViewportContainer

@export var car: PackedScene:
	set(value):
		car = value
		self._on_car_changed()
	get:
		return car
		
@export var color_set: CarColorSet:
	set(value):
		color_set = value
		self._on_car_color_changed()
	get:
		return color_set

@onready var viewport: SubViewport = %CarViewport
@onready var camera: Camera3D = %CarViewerCamera

var car_instance: Car
const spin_angular_velocity = -2 * PI / 6

func _ready() -> void:
	self._on_car_changed.call_deferred()

func _set_car(scene: PackedScene):
	pass

func _physics_process(delta: float) -> void:
	if self.car_instance:
		self.car_instance.rotate(Vector3.UP, spin_angular_velocity * delta)
		
func _on_car_changed():
	var rotation = Vector3()
	if car:
		if car_instance:
			rotation = self.car_instance.rotation
			car_instance.queue_free()
			car_instance = null
		car_instance = car.instantiate()
		if self.color_set:
			car_instance.color = self.color_set
		self.viewport.add_child(car_instance)
		car_instance.position = Vector3.UP * (car_instance.dimensions().y / 2)
		car_instance.rotation = rotation
		car_instance.lights_on = true
		car_instance.freeze = true
		car_instance.enable_sync(false)

func _on_car_color_changed():
	if car_instance:
		car_instance.color = self.color_set
