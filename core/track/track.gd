class_name RaceTrack
extends Node3D

@export var night: bool = false

@onready var waypoints: Waypoints = $Waypoints
@onready var nav_path: NavPath = $Waypoints/NavPath


func _ready() -> void:
	self.add_to_group(&"Track")
	for child in self.get_children():
		if child is AnimationPlayer:
			var action = child.get_meta(&"action", "")
			if not action:
				continue
			child.play(action)


func get_waypoints() -> Array[Vector3]:
	return waypoints.get_points()


func get_curve() -> Curve3D:
	return self.waypoints.waypoints


func get_closest_transform(position: Vector3) -> Transform3D:
	return waypoints.get_closest_transform(position).translated(Vector3.UP)
