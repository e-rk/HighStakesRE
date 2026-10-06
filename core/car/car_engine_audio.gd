extends AudioStreamPlayer3D

@export_range(0, 511) var index: int

@onready var car: Car = $".."

var ids: Dictionary = {}
var voices: Array[Voice] = []


class Voice:
	var sample: EngineSample
	var id: int
	var cents: int
	var volume: int


func _ready() -> void:
	var playback := self.get_stream_playback() as AudioStreamPlaybackPolyphonic
	var engine_stream := self.stream as EngineAudio
	for sample: EngineSample in engine_stream.samples:
		var voice := Voice.new()
		voice.sample = sample
		voice.id = playback.play_stream(sample.sample)
		voice.cents = sample.play_detune(EngineSample.NOTE, randi())
		voice.volume = sample.play_volume(EngineSample.VELOCITY, randi())
		self.voices.append(voice)


func get_idx() -> int:
	var rpm: float = car.current_rpm
	var performance: CarPerformance = car.performance
	var engine_redline_rpm: int = performance.engine_redline_rpm
	var engine_min_rpm: int = performance.engine_min_rpm()
	var div: int = ((engine_redline_rpm >> 1) + engine_redline_rpm) * 100
	var factor: int = 0x73
	var rpmfact: float = (rpm - (engine_min_rpm >> 1)) * 0x200
	var idx: int = roundi(factor * rpmfact / div)
	return clampi(idx, 0, 511)


func get_front_rear_mix() -> int:
	var camera_offset: Vector3 = car.global_position - get_viewport().get_camera_3d().global_position
	var forward: int = roundi(camera_offset.dot(car.global_basis.z) * 65536.0)
	var distance: int = roundi(camera_offset.length())
	return EngineSample.front_rear_mix(forward, distance)


func _physics_process(_delta: float) -> void:
	var playback := self.get_stream_playback() as AudioStreamPlaybackPolyphonic
	var idx: int = self.get_idx()
	var gas: int = EngineSample.gas_from_throttle(car.current_throttle)
	var mix: int = self.get_front_rear_mix()
	for voice: Voice in self.voices:
		var pitch: float = voice.sample.get_pitch_for_idx(idx, voice.cents)
		var volume: float = voice.sample.get_volume_for_idx(idx, gas, mix, voice.volume)
		playback.set_stream_volume(voice.id, volume)
		playback.set_stream_pitch_scale(voice.id, pitch)
