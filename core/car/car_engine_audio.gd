extends AudioStreamPlayer3D

@export_range(0, 511) var index: int

@onready var car = $".."

var ids = {}
var played_streams = {}

func _ready() -> void:
	var playback = self.get_stream_playback() as AudioStreamPlaybackPolyphonic
	var stream = self.stream as EngineAudio
	for sample in stream.samples:
		var id = playback.play_stream(sample.sample)
		self.played_streams[sample] = id


func get_idx() -> int:
	var rpm = car.current_rpm
	var performance = car.performance
	var engine_redline_rpm = performance.engine_redline_rpm()
	var engine_min_rpm = performance.engine_min_rpm()
	var div = ((engine_redline_rpm / 2) + engine_redline_rpm) * 100
	var factor = 0x73
	var rpmfact = (rpm - engine_min_rpm / 2) * 0x200
	var idx = round(factor * rpmfact / div)
	return clampi(idx, 0, 511)


func _physics_process(delta: float) -> void:
	var playback = self.get_stream_playback() as AudioStreamPlaybackPolyphonic
	var idx = self.get_idx()
	var local_camera_position = self.to_local(get_viewport().get_camera_3d().global_position)
	var basis_forward = self.basis.tdotz(local_camera_position)
	var angle = Vector3.MODEL_FRONT.angle_to(local_camera_position)
	var distance = local_camera_position.length()
	var throttle = car.current_throttle
	var rear_fron_factor = basis_forward / distance
	for stream in self.played_streams:
		var id = self.played_streams[stream]
		var pitch = stream.get_pitch_for_idx(idx)
		var volume = stream.get_volume_for_idx(idx, throttle, rear_fron_factor)
		playback.set_stream_volume(id, volume)
		playback.set_stream_pitch_scale(id, pitch)
