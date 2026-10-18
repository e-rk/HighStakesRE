extends RaceState

@onready var race_state_waiting_for_players = $"../RaceStateWaitingForPlayers"


func set_config(game_config: GameConfig):
	var rules = game_config.rules
	var track = game_config.track
	var track_node = self._make_track(track)
	context.track = track_node
	context.add_child(track_node, true)
	var race_logic = rules.get_race_logic()
	context.race_logic = race_logic
	context.race_logic.track = track_node
	context.race_logic.set_physics_process(false)
	context.add_child(race_logic, true)
	context.set_state(race_state_waiting_for_players)


func _make_track(config: TrackConfig):
	var track_data = TrackDB.get_track_by_uuid(config.track_uuid)
	return load(track_data.get_path(config.weather, config.night)).instantiate()
