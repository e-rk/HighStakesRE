extends MeshInstance3D
class_name CarMeter

@export var value: float = 0.0:
	set(val):
		value = val
		self.rotation = TAU * lerp(start, stop, value) * Vector3.MODEL_FRONT
	get:
		return value

@export var start: float = 0.0
@export var stop: float = 1.0
