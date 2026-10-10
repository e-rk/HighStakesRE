extends Node
class_name Optimizer

class OptimizerContext:
	var path_offset_buffer: RID
	var curvature_buffer: RID
	var obstacle_buffer: RID
	var uniform_set: RID
	var curvature_uniform_set: RID
	var momentum_buffer: RID

class OptimizerParams:
	var context: OptimizerContext
	var obstacles: Array[ObstacleData]
	var radius: float
	var optimize_iterations := 120
	var obstacle_scale := 40.0
	var distance_scale := 3.0
	var curvature_scale := 8.0
	var wall_scale := 0.3
	var obstacle_separation := 0.5
	var wall_separation := 3.0
	var beta := 0.85;
	var callback: Callable


class ObstacleData:
	var position: Vector3
	var velocity: Vector3
	var offset: int
	var lateral_x: float
	var dimensions: Vector3

const OBSTACLE_ELEM_SIZE = 12
const MAX_OBSTACLES = 32

var device: RenderingDevice
var register_queue: Array[OptimizerContext]
var unregister_queue: Array[OptimizerContext]
var submit_queue: Array[OptimizerParams]
var exit: bool = false
var waypoints: NavPath
var wp_clear: bool = false
var reload: bool = false

var waypoint_buffer: RID
var offset_buffer: RID
var left_wall_buffer: RID
var right_wall_buffer: RID
var normal_buffer: RID
var optimizer_shader: RID
var optimizer_pipeline: RID
var curvature_shader: RID
var curvature_pipeline: RID
var global_uniform_set: RID
var workgroups: int = 0
var num_points: int = 0
var current_waypoints: NavPath

var registered_contexts: Array[OptimizerContext]

var thread: Thread = Thread.new()
var optimizer_mtx: Mutex = Mutex.new()
var kick_signal: Semaphore = Semaphore.new()

func _ready() -> void:
	self.thread.start(self._main)


func _exit_tree() -> void:
	self.exit = true
	self.kick_signal.post()
	self.thread.wait_to_finish()


func _load_shader(path: String) -> RID:
	var source := load(path) as RDShaderFile
	var spirv := source.get_spirv()
	var err: String = spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if err:
		push_error("Shader compile error in %s [compute stage]:\n%s" % [path, err])
	return device.shader_create_from_spirv(spirv)


func _init_context(context: OptimizerContext):
	var zero := PackedFloat32Array()
	zero.resize(self.workgroups * 64)
	zero.fill(0.0)
	var zero_bytes := zero.to_byte_array()
	var zero_obstacles := PackedByteArray()
	zero_obstacles.resize(OBSTACLE_ELEM_SIZE * MAX_OBSTACLES)
	zero_obstacles.fill(0)
	context.path_offset_buffer = self.device.storage_buffer_create(zero_bytes.size(), zero_bytes)
	context.curvature_buffer = self.device.storage_buffer_create(zero_bytes.size(), zero_bytes)
	context.momentum_buffer = self.device.storage_buffer_create(zero_bytes.size(), zero_bytes)
	context.obstacle_buffer = self.device.storage_buffer_create(zero_obstacles.size(), zero_obstacles)


func _register(context: OptimizerContext) -> void:
	self._init_context(context)
	self.registered_contexts.append(context)


func _run_register() -> void:
	if not self.global_uniform_set.is_valid():
		return
	optimizer_mtx.lock()
	var queue = register_queue.duplicate()
	register_queue.clear()
	optimizer_mtx.unlock()
	for context in queue:
		self._register(context)


func _clear_context(context: OptimizerContext):
	self._safe_free(context.uniform_set)
	self._safe_free(context.curvature_uniform_set)
	self._safe_free(context.path_offset_buffer)
	self._safe_free(context.curvature_buffer)
	self._safe_free(context.momentum_buffer)
	self._safe_free(context.obstacle_buffer)
	context.uniform_set = RID()
	context.curvature_uniform_set = RID()
	context.path_offset_buffer = RID()
	context.curvature_buffer = RID()
	context.obstacle_buffer = RID()
	context.momentum_buffer = RID()


func _unregister(context: OptimizerContext) -> void:
	self._clear_context(context)
	var idx = self.registered_contexts.find(context)
	self.registered_contexts.remove_at(idx)


func _run_unregister() -> void:
	optimizer_mtx.lock()
	var queue = unregister_queue.duplicate()
	unregister_queue.clear()
	optimizer_mtx.unlock()
	for context in queue:
		self._unregister(context)


func _encode_obstacle(bytes: PackedByteArray, offset: int, obstacle: ObstacleData) -> int:
	bytes.encode_u32(offset, obstacle.offset)
	offset += 4
	bytes.encode_float(offset, obstacle.lateral_x)
	offset += 4
	bytes.encode_float(offset, obstacle.dimensions.length())
	offset += 4
	return offset


func _submit(compute_list: int, params: OptimizerParams) -> void:
	if not params.context.uniform_set.is_valid():
		var path_offset_uniform := RDUniform.new()
		path_offset_uniform.binding = 0
		path_offset_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		path_offset_uniform.add_id(params.context.path_offset_buffer)
		var obstacle_uniform := RDUniform.new()
		obstacle_uniform.binding = 1
		obstacle_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		obstacle_uniform.add_id(params.context.obstacle_buffer)
		var momentum_buffer := RDUniform.new()
		momentum_buffer.binding = 2
		momentum_buffer.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		momentum_buffer.add_id(params.context.momentum_buffer)
		params.context.uniform_set = self.device.uniform_set_create(
			[
				path_offset_uniform,
				obstacle_uniform,
				momentum_buffer,
			],
			self.optimizer_shader,
			1
		)

	if not params.context.curvature_uniform_set.is_valid():
		var uniform = RDUniform.new()
		uniform.binding = 0
		uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		uniform.add_id(params.context.curvature_buffer)
		params.context.curvature_uniform_set = self.device.uniform_set_create([uniform], self.curvature_shader, 2)

	var _alpha = 1.0 / (16.0 * params.curvature_scale + 2.0 * params.distance_scale)
	var gradient_pc := PackedByteArray()
	gradient_pc.resize(48)
	gradient_pc.encode_u32(0, self.num_points)
	gradient_pc.encode_u32(4, params.obstacles.size())
	gradient_pc.encode_float(8, params.distance_scale)
	gradient_pc.encode_float(12, params.obstacle_scale)
	gradient_pc.encode_float(16, params.curvature_scale)
	gradient_pc.encode_float(20, params.wall_scale)
	gradient_pc.encode_float(24, params.obstacle_separation)
	gradient_pc.encode_float(28, params.wall_separation)
	gradient_pc.encode_float(32, _alpha)
	gradient_pc.encode_float(36, params.beta)
	gradient_pc.encode_float(40, params.radius)

	for i in params.optimize_iterations:
		var iteration_pc = gradient_pc.duplicate()
		iteration_pc.encode_u32(44, i)

		self.device.compute_list_bind_compute_pipeline(compute_list, self.optimizer_pipeline)
		self.device.compute_list_bind_uniform_set(compute_list, self.global_uniform_set, 0)
		self.device.compute_list_bind_uniform_set(compute_list, params.context.uniform_set, 1)
		self.device.compute_list_set_push_constant(compute_list, iteration_pc, iteration_pc.size())
		self.device.compute_list_dispatch(compute_list, self.workgroups, 1, 1)

		self.device.compute_list_add_barrier(compute_list)

	var curvature_pc := PackedByteArray()
	curvature_pc.resize(4)
	curvature_pc.encode_u32(0, self.num_points)

	self.device.compute_list_bind_compute_pipeline(compute_list, self.curvature_pipeline)
	self.device.compute_list_bind_uniform_set(compute_list, self.global_uniform_set, 0)
	self.device.compute_list_bind_uniform_set(compute_list, params.context.uniform_set, 1)
	self.device.compute_list_bind_uniform_set(compute_list, params.context.curvature_uniform_set, 2)
	self.device.compute_list_set_push_constant(compute_list, curvature_pc, curvature_pc.size())
	self.device.compute_list_dispatch(compute_list, self.workgroups, 1, 1)

	self.device.compute_list_add_barrier(compute_list)

	self.device.compute_list_bind_uniform_set(compute_list, self.global_uniform_set, 0)
	self.device.compute_list_bind_uniform_set(compute_list, params.context.curvature_uniform_set, 2)
	self.device.compute_list_set_push_constant(compute_list, curvature_pc, curvature_pc.size())
	self.device.compute_list_dispatch(compute_list, self.workgroups, 1, 1)


func _run_submit() -> void:
	if not self.global_uniform_set.is_valid():
		return

	optimizer_mtx.lock()
	var queue = submit_queue.duplicate()
	submit_queue.clear()
	optimizer_mtx.unlock()

	for params in queue:
		var obstacle_data := PackedByteArray()
		var offset := 0
		var obstacle_count = mini(params.obstacles.size(), MAX_OBSTACLES)
		obstacle_data.resize(OBSTACLE_ELEM_SIZE * obstacle_count)
		for i in obstacle_count:
			var obstacle = params.obstacles[i]
			offset = self._encode_obstacle(obstacle_data, offset, obstacle)
		self.device.buffer_update(params.context.obstacle_buffer, 0, obstacle_data.size(), obstacle_data)

	var compute_list := self.device.compute_list_begin()

	for params in queue:
		self._submit(compute_list, params)

	self.device.compute_list_end()

	self.device.submit()
	self.device.sync()

	for params in queue:
		var offsets = self.device.buffer_get_data(params.context.path_offset_buffer).to_float32_array()
		var curvatures = self.device.buffer_get_data(params.context.curvature_buffer).to_float32_array()
		params.callback.call(offsets, curvatures)


func _safe_free(rid: RID):
	if rid.is_valid():
		self.device.free_rid(rid)


func _create_global_uniform_set():
	var wp = self.current_waypoints

	self.num_points = wp.points.size()
	self.workgroups = (self.num_points + 63) / 64
	var buffer_size = self.workgroups * 64

	var points = wp.points.duplicate()
	points.resize(buffer_size)
	for i in (points.size() - self.num_points):
		points[self.num_points + i] = Vector3.ZERO

	var points_bytes = points.to_byte_array()
	self.waypoint_buffer = self.device.storage_buffer_create(points_bytes.size(), points_bytes)

	var offsets = wp.racing_line_offset.duplicate()

	offsets.resize(buffer_size)
	for i in (offsets.size() - self.num_points):
		offsets[self.num_points + i] = 0.0

	var offset_bytes = offsets.to_byte_array()
	self.offset_buffer = self.device.storage_buffer_create(offset_bytes.size(), offset_bytes)

	var left_walls = wp.left_walls.duplicate()
	left_walls.resize(buffer_size)
	for i in (left_walls.size() - self.num_points):
		left_walls[self.num_points + i] = 0.0
	var left_walls_bytes = left_walls.to_byte_array()
	self.left_wall_buffer = self.device.storage_buffer_create(left_walls_bytes.size(), left_walls_bytes)

	var right_walls = wp.right_walls.duplicate()
	right_walls.resize(buffer_size)
	for i in (right_walls.size() - self.num_points):
		right_walls[self.num_points + i] = 0.0
	var right_walls_bytes = right_walls.to_byte_array()
	self.right_wall_buffer = self.device.storage_buffer_create(right_walls_bytes.size(), right_walls_bytes)

	var normals = PackedVector3Array()
	normals.resize(buffer_size)
	normals.fill(Vector3.RIGHT)
	for i in wp.orientations.size():
		normals[i] = wp.orientations[i].x
	var normals_bytes = normals.to_byte_array()
	self.normal_buffer = self.device.storage_buffer_create(normals_bytes.size(), normals_bytes)

	var uniform_points := RDUniform.new()
	uniform_points.binding = 0
	uniform_points.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_points.add_id(self.waypoint_buffer)
	var uniform_offsets := RDUniform.new()
	uniform_offsets.binding = 1
	uniform_offsets.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_offsets.add_id(self.offset_buffer)
	var uniform_left_wall := RDUniform.new()
	uniform_left_wall.binding = 2
	uniform_left_wall.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_left_wall.add_id(self.left_wall_buffer)
	var uniform_right_wall := RDUniform.new()
	uniform_right_wall.binding = 3
	uniform_right_wall.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_right_wall.add_id(self.right_wall_buffer)
	var uniform_normal := RDUniform.new()
	uniform_normal.binding = 4
	uniform_normal.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_normal.add_id(self.normal_buffer)
	self.global_uniform_set = self.device.uniform_set_create(
		[
			uniform_points,
			uniform_offsets,
			uniform_left_wall,
			uniform_right_wall,
			uniform_normal,
		],
		self.optimizer_shader, 0
	)


func _set_waypoints():
	optimizer_mtx.lock()
	var wp = self.waypoints
	self.waypoints = null
	optimizer_mtx.unlock()
	self._clear_waypoints()
	self.current_waypoints = wp
	if self.current_waypoints:
		self._create_global_uniform_set()


func _clear_global_uniform_set():
	self._safe_free(self.global_uniform_set)
	self._safe_free(self.normal_buffer)
	self._safe_free(self.right_wall_buffer)
	self._safe_free(self.left_wall_buffer)
	self._safe_free(self.offset_buffer)
	self._safe_free(self.waypoint_buffer)
	self.global_uniform_set = RID()
	self.normal_buffer = RID()
	self.right_wall_buffer = RID()
	self.left_wall_buffer = RID()
	self.offset_buffer = RID()
	self.waypoint_buffer = RID()

func _clear_waypoints():
	optimizer_mtx.lock()
	self.wp_clear = false
	optimizer_mtx.unlock()
	if not current_waypoints:
		return
	self._clear_global_uniform_set()
	self.current_waypoints = null


func _load_all_shaders():
	self.optimizer_shader = _load_shader("res://core/ai/compute/ai_optimize.glsl")
	self.optimizer_pipeline = device.compute_pipeline_create(self.optimizer_shader)
	self.curvature_shader = _load_shader("res://core/ai/compute/ai_curvature.glsl")
	self.curvature_pipeline = device.compute_pipeline_create(self.curvature_shader)


func _reload_shaders():
	optimizer_mtx.lock()
	self.reload = false
	optimizer_mtx.unlock()
	for context in registered_contexts:
		self._clear_context(context)
	self._clear_global_uniform_set()
	self._safe_free(self.optimizer_pipeline)
	self._safe_free(self.optimizer_shader)
	self._safe_free(self.curvature_pipeline)
	self._safe_free(self.curvature_shader)
	self._load_all_shaders()
	if current_waypoints:
		self._create_global_uniform_set()
	for context in registered_contexts:
		self._init_context(context)


func _main() -> void:
	self.device = RenderingServer.create_local_rendering_device()
	self._load_all_shaders()

	while true:
		kick_signal.wait()
		optimizer_mtx.lock()
		var reload_req = self.reload
		var waypoints_req = self.waypoints != null
		var clear_req = self.wp_clear
		var register_req = self.register_queue.size() > 0
		var submit_req = self.submit_queue.size() > 0
		var unregister_req = self.unregister_queue.size() > 0
		optimizer_mtx.unlock()
		if exit:
			break
		if reload_req:
			self._reload_shaders()
		if waypoints_req:
			self._set_waypoints()
		if clear_req:
			self._clear_waypoints()
		if register_req:
			self._run_register()
		if submit_req:
			self._run_submit()
		if unregister_req:
			self._run_unregister()
	self._clear_global_uniform_set()
	self._safe_free(optimizer_pipeline)
	self._safe_free(optimizer_shader)
	self._safe_free(curvature_pipeline)
	self._safe_free(curvature_shader)
	self.device.free()

func register(context: OptimizerContext) -> void:
	optimizer_mtx.lock()
	register_queue.push_back(context)
	optimizer_mtx.unlock()
	kick_signal.post()


func unregister(context: OptimizerContext) -> void:
	optimizer_mtx.lock()
	unregister_queue.push_back(context)
	optimizer_mtx.unlock()
	kick_signal.post()

func submit_work(params: OptimizerParams) -> void:
	optimizer_mtx.lock()
	submit_queue.push_back(params)
	optimizer_mtx.unlock()
	kick_signal.post()


func set_waypoints(wp: NavPath):
	optimizer_mtx.lock()
	self.waypoints = wp
	optimizer_mtx.unlock()
	kick_signal.post()


func clear_waypoints():
	optimizer_mtx.lock()
	self.wp_clear = true
	optimizer_mtx.unlock()
	kick_signal.post()


func reload_shaders():
	optimizer_mtx.lock()
	self.reload = true
	optimizer_mtx.unlock()
	kick_signal.post()
