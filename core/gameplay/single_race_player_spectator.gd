extends "res://core/gameplay/player_spectator.gd"

@export var race_laps: int = 2

@onready var lap_timer = $PlayerUI/HSplitContainer/LapTimer


func _update_ui(player: Player):
	var racer = player.get_node("Racer") as Racer
	ui.set_laps(racer.laps, self.race_laps)
	lap_timer.set_current_time(racer.current_lap_time())
	lap_timer.set_last_time(racer.get_best_lap_time())
	
