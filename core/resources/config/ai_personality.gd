extends Resource
class_name AiPersonality

@export var name: String
@export var preferred_primary_colors: Array[Color]
@export_range(0.0, 1.0, 0.01) var preferred_color_probability: float
@export var hair_colors: Array[Color]
