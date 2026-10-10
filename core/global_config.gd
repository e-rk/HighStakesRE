extends Node

@export_group("Pursuit minimap")
@export var minimap_track_color: Color = Color(0.0, 1.0, 0.0, 0.561)
@export var minimap_obstacle_color: Color = Color(0.95, 0.6, 0.1)
@export var minimap_self_color: Color = Color(0.13, 0.445, 0.5, 1.0)
@export var minimap_target_color: Color = Color(1.0, 0.15, 0.1)
@export var minimap_police_color: Color = Color(0.25, 0.4, 1.0)
@export var minimap_racer_color: Color = Color(0.75, 0.75, 0.75)


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("minimap_track_color", minimap_track_color)
