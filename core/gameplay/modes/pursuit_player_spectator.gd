extends "res://core/gameplay/player_spectator.gd"

@export var race_laps: int = 2
@export var num_tickets: int = 3

@onready var lap_timer = $PlayerUI/HSplitContainer/LapTimer
@onready var ticketed_message: Control = $PlayerUI/MarginContainer/TicketedMessage
@onready var arrested_message: Control = $PlayerUI/MarginContainer/ArrestedMessage
@onready var pursuit_map: PursuitMinimapWindow = $PlayerUI/PursuitMinimapWindow

@onready var race_leaderboard: RaceLeaderboard = $PlayerUI/RaceLeaderboard
@onready var ticket_status: PursuitTicketStatus = $PlayerUI/PursuitTicketStatus


var player_positions: Array[RaceLeaderboard.PlayerPosition]
var racer_statuses: Array[PursuitTicketStatus.RacerStatus]


func _pursuit_map_others(police_player: Player, target_player: Player) -> Array[Car]:
	var cars: Array[Car] = []
	for node in get_tree().get_nodes_in_group(&"Players"):
		var player := node as Player
		if player == null or player == police_player or player == target_player:
			continue
		if player.car != null:
			cars.append(player.car)
	return cars


func show_busted_meter(racer: PursuitRacer):
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
	var target := police.get_target()
	for racer in racers:
		if racer.bust_score > 5 or racer == target:
			self.show_busted_meter(racer)
		else:
			racer.busted_meter.hide()
	if target != null and police.state != PursuitPolice.PoliceState.IDLE:
		self.pursuit_map.update_state(police.player.car, target.player.car,
				self._pursuit_map_others(police.player, target.player))
	else:
		self.pursuit_map.hide()

func _update_ui(spectated_player: Player):
	var player_data = spectated_player.get_meta(&"pursuit_info")
	if player_data is PursuitRacer:
		self.pursuit_map.hide()
		ui.set_laps(min(player_data.laps, race_laps), self.race_laps)
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
		self.ticketed_message.hide()
		self.arrested_message.hide()
		self.update_police_ui(player_data)
	var racers: Array[PursuitRacer]
	racers.assign(get_tree().get_nodes_in_group(&"PursuitRacers"))
	for racer in racers:
		if racer == player_data:
			racer.racer_info.hide()
			continue
		self.position_player_info(racer)
		if player_data is PursuitRacer:
			racer.busted_meter.hide()


func _racer_distance(racer: Racer) -> float:
	var track = get_tree().get_first_node_in_group(&"Track")
	return racer.laps * track.nav_path.get_track_length() + racer.player.position_along_track


func _update_player_positions(current_racer: Racer) -> int:
	var racers: Array[Racer]
	racers.assign(get_tree().get_nodes_in_group(&"PursuitRacers"))
	if player_positions.size() != racers.size():
		player_positions.clear()
		for _p in racers:
			player_positions.append(RaceLeaderboard.PlayerPosition.new())
	racers.sort_custom(func (a: Racer, b: Racer) -> bool: return _racer_distance(a) > _racer_distance(b))
	for i in racers.size():
		var racer := racers[i]
		var data := player_positions[i]
		var distance := _racer_distance(racer) - _racer_distance(current_racer)
		data.name = racer.player.player_name
		data.distance = distance / current_racer.average_speed
		data.color = racer.player.car.color.primary
	return racers.find(current_racer) + 1


func _update_ticket_status() -> void:
	var racers: Array[PursuitRacer]
	racers.assign(get_tree().get_nodes_in_group(&"PursuitRacers"))
	if racer_statuses.size() != racers.size():
		racer_statuses.clear()
		for _r in racers:
			racer_statuses.append(PursuitTicketStatus.RacerStatus.new())
	for i in racers.size():
		var racer := racers[i]
		var status := racer_statuses[i]
		status.name = racer.player.player_name
		status.color = racer.player.car.color.primary
		status.tickets = racer.tickets
		status.speed_kph = roundi(racer.player.car.linear_velocity.length() * 3.6)
		status.laps = racer.laps


func _on_status_update_timer_timeout() -> void:
	if spectated_player == null or not spectated_player.has_meta(&"pursuit_info"):
		return
	var info = spectated_player.get_meta(&"pursuit_info")
	if info is PursuitRacer:
		self.ticket_status.hide()
		self.race_leaderboard.show()
		var position = self._update_player_positions(info)
		self.race_leaderboard.update(player_positions, position)
	elif info is PursuitPolice:
		self.race_leaderboard.hide()
		self.ticket_status.show()
		self._update_ticket_status()
		self.ticket_status.update(racer_statuses, self.num_tickets, self.race_laps)
