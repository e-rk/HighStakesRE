class_name Waypoints
extends Node3D

@export var waypoints: Curve3D


func get_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i in range(0, waypoints.point_count):
		var current = waypoints.sample(i, 0.0)
		points.append(current)
	return points


func get_closest_point(position: Vector3) -> Vector3:
	return waypoints.get_closest_point(position)


func get_closest_transform(position: Vector3) -> Transform3D:
	var offset = waypoints.get_closest_offset(position)
	return waypoints.sample_baked_with_rotation(offset, false, false).rotated_local(Vector3.UP, PI)


func offset_normalized(position: Vector3) -> float:
	return self.waypoints.get_closest_offset(position) / self.waypoints.get_baked_length()
