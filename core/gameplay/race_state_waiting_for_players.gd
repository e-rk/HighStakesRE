extends RaceState

@onready var race_state_start_countdown = $"../RaceStateStartCountdown"
@onready var spawner = $MultiplayerSpawner

const player_scene = preload("res://core/gameplay/player/player.tscn")


func spawn_player(player_id, player_config: PlayerConfig):
	var player = player_scene.instantiate()
	player.car_uuid = player_config.car_uuid
	player.primary_color = player_config.color_primary
	player.secondary_color = player_config.color_secondary
	player.interior_color = player_config.color_interior
	player.driver_color = player_config.color_driver
	player.player_name = player_config.player_name
	player.initial_transform = context.race_logic.get_spawn_position(player)
	player.name = str(player_id)
	player.ready.connect(self._on_player_spawned.bind(player))
	context.player_container.add_child(player)


func start_race():
	context.set_state(race_state_start_countdown)


func _on_player_spawned(node: Player):
	context.race_logic.player_spawned(node)
