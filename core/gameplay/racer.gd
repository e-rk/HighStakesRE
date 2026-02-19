class_name Racer
extends Node

@export var laps: int = 0
@export var max_laps: int = 1
@export var best_lap_time: float = INF
@export var track_progress := 0.80
@export var lap_start_timestamp: int = 0


@onready var player: Player = $".."


func start_timer():
	self.lap_start_timestamp = Time.get_ticks_msec()


func capture_time():
	var lap_time = self.current_lap_time()
	self.best_lap_time = min(self.best_lap_time, lap_time)
	self.lap_start_timestamp = Time.get_ticks_msec()


func get_best_lap_time():
	if is_inf(self.best_lap_time):
		return 0.0
	return self.best_lap_time


func current_lap_time() -> float:
	var current_ticks = Time.get_ticks_msec()
	return (current_ticks - self.lap_start_timestamp) / 1000.0
