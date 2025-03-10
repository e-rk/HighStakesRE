class_name Minimap
extends Control

var draw_scale = 300
var center_point = Vector2.ZERO
var _waypoints = [Vector2(0, 0)]
var players: Array = []:
	set(value):
		players = value
	get:
		return players


func to_vec2(point: Vector3) -> Vector2:
	return Vector2(-point.x, -point.z)


func center_points_custom(points: Array, center: Vector2):
	return points.map(func(x): return x - center)


func center_points(points: Array) -> Array:
	var sum = points.reduce(func(a, x): return a + x)
	var center = sum / len(points)
	return center_points_custom(points, center)


func normalize_points(points: Array) -> Array:
	var factor = calculate_normalization_factor(points)
	return points.map(func(x): return x / factor)


func calculate_normalization_factor(points: Array) -> float:
	var centered = center_points(points)
	return centered.reduce(func(a, x): return max(a, x.length()), 0)


func scale_points(points: Array, scale: float) -> Array:
	return points.map(func(x): return x * scale)


func refresh():
	self.queue_redraw()


func set_waypoints(points: Array):
	_waypoints = points.map(to_vec2)
	refresh()


func set_minimap_center(point: Vector3):
	center_point = to_vec2(point)
	refresh()


func _draw():
	var centered_points = center_points_custom(_waypoints, center_point)
	var factor = calculate_normalization_factor(centered_points)
	var normalized_points = normalize_points(centered_points)
	var scaled_points = scale_points(normalized_points, draw_scale)
	var prev = scaled_points[0]
	scaled_points.append(scaled_points[0])
	draw_polyline(PackedVector2Array(scaled_points), Color.WHITE, -1.0)

	for player in players:
		var player_pos = ((to_vec2(player["global_position"]) - center_point) / factor) * draw_scale
		var radius = 15.0 if player["emphasis"] else 10.0
		draw_circle(player_pos, radius, player["color"])
