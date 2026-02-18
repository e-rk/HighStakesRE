extends "res://core/gameplay/player_spectator.gd"

@export var race_laps: int = 2

@onready var lap_timer = $PlayerUI/HSplitContainer/LapTimer
@onready var ticketed_message: Control = $PlayerUI/MarginContainer/TicketedMessage
@onready var arrested_message: Control = $PlayerUI/MarginContainer/ArrestedMessage


func show_busted_meter(racer: PursuitRacer):
	if not racer:
		return
	racer.busted_meter.show()
	racer.busted_meter.value = racer.bust_score

func position_player_info(racer: PursuitRacer):
	var player = racer.player
	var car = player.car 
	var camera = get_viewport().get_camera_3d()
	var unprojected = camera.unproject_position(car.global_position + 1.3 * Vector3.UP * car.dimensions().y)
	unprojected -= racer.racer_info.size / 2
	racer.racer_info.position = unprojected
	racer.racer_info.visible = not camera.is_position_behind(car.global_transform.origin)

func update_police_ui(police: PursuitPolice):
	var racers: Array[PursuitRacer]
	racers.assign(get_tree().get_nodes_in_group(&"PursuitRacers"))
	var target = null
	if police.target:
		target = self.get_node(police.target) as PursuitRacer
	for racer in racers:
		if racer.bust_score > 5 or racer == target:
			self.show_busted_meter(racer)
		else:
			racer.busted_meter.hide()

func _update_ui(spectated_player: Player):
	var player_data = spectated_player.get_meta(&"pursuit_info")
	if player_data is PursuitRacer:
		ui.set_laps(player_data.laps, self.race_laps)
		lap_timer.show()
		lap_timer.set_current_time(player_data.current_lap_time())
		lap_timer.set_last_time(player_data.get_best_lap_time())
		if player_data.arrested:
			self.arrested_message.show()
		elif player_data.busted:
			self.ticketed_message.show()
		else:
			self.ticketed_message.hide()
			self.arrested_message.hide()
	elif player_data is PursuitPolice:
		lap_timer.hide()
		self.update_police_ui(player_data)
	var racers: Array[PursuitRacer]
	racers.assign(get_tree().get_nodes_in_group(&"PursuitRacers"))
	for racer in racers:
		if racer == player_data:
			racer.racer_info.hide()
			continue
		self.position_player_info(racer)
