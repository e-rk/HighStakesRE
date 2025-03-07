@tool
extends AudioStreamPolyphonic
class_name EngineAudio

@export var samples: Array[EngineSample]

func get_front_samples() -> Array[EngineSample]:
	return self.samples.filter(func(x): return not x.rear)

func get_rear_samples() -> Array[EngineSample]:
	return self.samples.filter(func(x): return x.rear)
