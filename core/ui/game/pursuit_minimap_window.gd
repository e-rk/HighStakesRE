extends Control
class_name PursuitMinimapWindow

## Top-down pursuit detail map for police players. Renders only the driveable
## road collision meshes plus box proxies for cars and track objects, all on
## the dedicated MINIMAP visual layer so no other camera sees them.

@export var padding_m: float = 20.0
@export var min_view_size_m: float = 60.0
@export var max_view_size_m: float = 280.0
@export var camera_height_m: float = 120.0

@onready var camera: Camera3D = %PursuitCamera

static func view_size(a: Vector3, b: Vector3, padding: float, min_size: float, max_size: float) -> float:
	var distance := a.distance_to(b)
	return clampf(distance + 2.0 * padding, min_size, max_size)


func view_center(a: Vector3, b: Vector3) -> Vector3:
	var center := a.lerp(b, 0.5)
	center.y = max(a.y, b.y) + 10.0
	return center


## Camera yaw that puts `forward` (a world-space heading) at the top of the map.
static func heading_up_yaw(forward: Vector3) -> float:
	return atan2(-forward.x, -forward.z)


func update_state(police_car: Car, target_car: Car, others: Array[Car]) -> void:
	self.show()
	var police_position := police_car.global_position
	var target_position := target_car.global_position
	var center := view_center(police_position, target_position)
	var size_m := view_size(police_position, target_position, self.padding_m, self.min_view_size_m, self.max_view_size_m)
	self.camera.size = size_m
	self.camera.global_position = center + Vector3.UP * self.camera_height_m
	var forward := police_car.global_basis * Vector3.MODEL_FRONT
	self.camera.rotation = Vector3(-PI / 2.0, heading_up_yaw(forward), 0.0)
	police_car.minimap_color = GlobalConfig.minimap_self_color
	target_car.minimap_color = GlobalConfig.minimap_target_color
	for car in others:
		var color = GlobalConfig.minimap_police_color if car.is_police() else GlobalConfig.minimap_racer_color as Color
		car.minimap_color = color


func clear() -> void:
	self.hide()
