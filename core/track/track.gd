class_name RaceTrack
extends Node3D

@onready var waypoints: Waypoints = $Waypoints
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	for child in self.get_children():
		if child is AnimationPlayer:
			var action = child.get_meta(&"action", "")
			if not action:
				continue
			child.play(action)


func get_spawn_transform(idx) -> Transform3D:
	var points = get_waypoints()
	var point_idx = idx * 3 + 1
	var spawn_point = points[-point_idx]
	return self.get_closest_transform(spawn_point)


func get_waypoints() -> Array[Vector3]:
	return waypoints.get_points()


func progress_along_track(position: Vector3) -> float:
	return waypoints.offset_normalized(position)


func get_closest_transform(position: Vector3) -> Transform3D:
	return waypoints.get_closest_transform(position).translated(Vector3.UP)
