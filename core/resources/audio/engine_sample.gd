extends Resource
class_name EngineSample

@export var sample: AudioStreamWAV
@export var rear: bool
@export var volume_tables: Array
@export var pitch_tables: Array
@export var is_load_table: Array[bool]
@export var pitch_unknown0: int
@export var pitch_unknown1: int
@export var pitch_unknown2: int

func get_volume_for_idx(idx: int) -> Array:
	return self.volume_tables.map(func(x): return linear_to_db(remap(x[idx], 0.0, 127.0, 0.0, 1.0)))

func get_pitch_for_idx(idx: int) -> Array:
	return self.pitch_tables.map(func(x): return remap(x[idx], 0.0, 127.0, 0.8, 1.3))
