extends Node3D
class_name NavPath

@export var points: PackedVector3Array
@export var orientations: Array[Basis]
@export var racing_line_offset: PackedFloat32Array
## Driving lanes on each side of each waypoint (road block): the width of one lane and the number
## of lanes. Empty on tracks converted before speedtools exported them.
@export var left_lane_widths: PackedFloat32Array
@export var right_lane_widths: PackedFloat32Array
@export var left_lane_counts: PackedInt32Array
@export var right_lane_counts: PackedInt32Array

var left_walls: PackedFloat32Array = PackedFloat32Array()
var right_walls: PackedFloat32Array = PackedFloat32Array()
var point_data: Array[PointData]


class PointData:
	var cumulative_distance: float
	var distance_to_next: float
	var distance_to_previous: float
	var tangent: Vector3
	var normal: Vector3


static func from_waypoints(points: PackedVector3Array):
	var ret = NavPath.new()
	ret.points = points
	return ret


func _ready() -> void:
	prepare_data()


func _hit_offset(point: Vector3, racing_line_off: float, orientation: Basis, left: bool) -> float:
	const QUERY_DISTANCE = 40
	const try_heights = [-0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 8.0]
	var query = PhysicsRayQueryParameters3D.new()
	var dss = get_world_3d().direct_space_state
	var direction = 1.0
	if not left:
		direction = -1.0
	for height_off in try_heights:
		var up_off = Vector3.UP * height_off
		var offset = racing_line_off
		var from = point + orientation * Vector3(offset, 0, 0) + up_off
		query.from = from
		query.collision_mask = Constants.collision_layer_to_mask([Constants.CollisionLayer.TRACK_WALLS])
		query.to = from + direction * (orientation.x * QUERY_DISTANCE)
		var result = dss.intersect_ray(query)
		if result:
			var dist = query.from.distance_to(result["position"]) + direction * offset
			return dist
	return QUERY_DISTANCE


func _measure_walls():
	left_walls.resize(self.points.size())
	left_walls.fill(2.0)
	right_walls.resize(self.points.size())
	right_walls.fill(2.0)
	for i in points.size():
		var hit_offset = self._hit_offset(points[i], racing_line_offset[i], orientations[i], true)
		right_walls[i] = hit_offset
		hit_offset = self._hit_offset(points[i], racing_line_offset[i], orientations[i], false)
		left_walls[i] = hit_offset


func prepare_data():
	var cumulative := 0.0
	for i in points.size():
		var previous = _next_idx(i, -1)
		var next = _next_idx(i, 1)
		var current_vertex = points[i]
		var previous_vertex = points[previous]
		var next_vertex = points[next]
		var tangent = (next_vertex - previous_vertex).normalized()
		var data = PointData.new()
		data.distance_to_next = current_vertex.distance_to(next_vertex)
		data.distance_to_previous = current_vertex.distance_to(previous_vertex)
		data.cumulative_distance = cumulative
		data.tangent = tangent
		data.normal = tangent.cross(Vector3.UP).normalized()
		self.point_data.append(data)
		cumulative += data.distance_to_next


func _path_distance(a: int, b: int) -> float:
	var ab := absf(self.point_data[b].cumulative_distance - self.point_data[a].cumulative_distance)
	var length := get_track_length()
	return minf(ab, length - ab)


func _find_closest_point_interval(min_idx: int, max_idx: int, global_position: Vector3) -> float:
	var min_distance_sq := INF
	var offset := 0.0
	var count := posmod(max_idx - min_idx, points.size() + 1)
	for _i in count:
		var i = _next_idx(min_idx, +_i)
		var current_point = points[i]
		var i_next = self._next_idx(i, 1)
		var distance = _path_distance(i_next, i)
		var to_next_norm = (points[i_next] - current_point) / distance
		var d = to_next_norm.dot(global_position - current_point)
		d = clamp(d, 0.0, distance - 0.001)
		var projected = current_point + d * to_next_norm
		var distance_sq = global_position.distance_squared_to(projected)
		if distance_sq < min_distance_sq:

			offset = i + (d / distance)
			min_distance_sq = distance_sq
	return offset


func get_closest_point(global_position: Vector3, hint: int = -1) -> float:
	var min_distance_sq := INF
	var offset := 0.0
	const DISTANCE_TOLERANCE_SQ := 50.0 ** 2
	const NODE_TOLERANCE := 2
	var try_found := -1.0
	if hint != -1:
		try_found = _find_closest_point_interval(hint - NODE_TOLERANCE, hint + NODE_TOLERANCE, global_position)
		var try_idx := floori(try_found)
		if points[try_idx].distance_squared_to(global_position) <= DISTANCE_TOLERANCE_SQ:
			return try_found
	return _find_closest_point_interval(0, points.size(), global_position)


func advance_by_distance(idx: int, distance: float) -> int:
	var current_idx := idx
	var accumulated_distance := 0.0
	var diff := 1 if distance >= 0.0 else -1
	while accumulated_distance < abs(distance):
		accumulated_distance += point_data[current_idx].distance_to_next
		current_idx = _next_idx(current_idx, diff)
	return current_idx


func advance_by_distance_smooth(offset: float, _global_position: Vector3, distance: float) -> Vector3:
	var idx := floori(offset)
	var t := offset - idx
	var advanced_idx = advance_by_distance(idx, distance)
	var next_idx = _next_idx(advanced_idx, 1)
	return points[advanced_idx].lerp(points[next_idx], t)


func get_track_length() -> float:
	return self.point_data[-1].cumulative_distance + self.point_data[-1].distance_to_next


func get_distance_along_track(offset: float) -> float:
	var idx := floori(offset) % points.size()
	return self.point_data[floori(idx)].cumulative_distance


func _next_idx(idx: int, diff: int) -> int:
	return posmod(idx + diff, points.size())


func _offset_to_idx(offset: float) -> int:
	return floori(offset) % self.points.size()


func offset_vector_at_idx(offset: float, lateral_offsets: PackedFloat32Array, global_position: Vector3) -> Vector3:
	var idx = self._offset_to_idx(offset)
	var lateral_x = 0.0
	if lateral_offsets.size() > 0:
		lateral_x = lateral_offsets[idx]
	return global_position + self.orientations[idx] * Vector3(lateral_x, 0.0, 0.0)


func tangent_vector_at_offset(offset: float, lateral_offsets: PackedFloat32Array) -> Vector3:
	var idx = self._offset_to_idx(offset)
	if lateral_offsets.size() > 0:
		var previous = _next_idx(idx, -1)
		var next = _next_idx(idx, 1)
		var previous_position := self.offset_vector_at_idx(previous, lateral_offsets, points[previous])
		var next_position := self.offset_vector_at_idx(next, lateral_offsets, points[next])
		return (next_position - previous_position).normalized()
	return self.orientations[idx].z


func calculate_lateral_offset(offset: float, global_position: Vector3) -> float:
	var idx = self._offset_to_idx(offset)
	var point = self.points[idx]
	var line_normal = self.orientations[idx].x
	var diff = global_position - point
	var lateral_x = line_normal.dot(diff)
	return lateral_x


func calculate_lateral_offset_from_shifted(offset: float, lateral_offsets: PackedFloat32Array, global_position: Vector3) -> float:
	var idx = self._offset_to_idx(offset)
	var point = self.points[idx]
	var line_normal = self.orientations[idx].x
	if lateral_offsets:
		var point_lateral_offset = lateral_offsets[idx]
		var shifted = point + line_normal * point_lateral_offset
		var diff = global_position - shifted
		var lateral_x = line_normal.dot(diff)
		return lateral_x
	return 0.0
