extends RaceState

@onready var race_state_ending = $"../RaceStateEnding"


func enter():
	context.race_logic.race_finished.connect(self._on_race_finished)
	for player in context.player_container.get_children():
		player.reposition_requested.connect(
			self._on_racer_controller_reposition_requested.bind(player)
		)
	context.race_logic.set_physics_process(true)
	context.race_logic.start()
	super()


func leave():
	context.race_logic.race_finished.disconnect(self._on_race_finished)
	super()


func _on_race_finished():
	context.set_state(race_state_ending)


func _on_racer_controller_reposition_requested(player: Player):
	if !context.race_logic.reposition_allowed():
		return
	player.car.transform = context.track.get_closest_transform(player.car.global_position)
	player.car.linear_velocity = Vector3.ZERO
	player.car.angular_velocity = Vector3.ZERO


func end_race():
	context.set_state(race_state_ending)
