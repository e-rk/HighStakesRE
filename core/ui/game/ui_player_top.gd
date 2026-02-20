extends Control
class_name PlayerUI

@onready var rpm_meter = %RpmMeter
@onready var speed_meter = %SpeedMeter
@onready var minimap_window = %MinimapWindow


func set_rpm(rpm: float):
	rpm_meter.set_rpm(rpm)


func set_gear(gear: CarTypes.Gear):
	rpm_meter.set_gear(gear)


func set_max_gear(gear: CarTypes.Gear):
	rpm_meter.set_max_gear(gear)


func set_speed(speed: float):
	speed_meter.set_speed(speed)


func set_minimap_rotation(rotation: float):
	minimap_window.set_minimap_rotation(rotation)


func set_minimap_center(point: Vector3):
	minimap_window.set_minimap_center(point)


func set_minimap_players(players: Array):
	minimap_window.set_players(players)


func set_minimap_waypoints(waypoints: Array):
	minimap_window.set_waypoints(waypoints)


func set_laps(racer_laps: int, overall_laps: int):
	minimap_window.set_laps(racer_laps, overall_laps)
