extends StateMachine

const race_scene = preload("res://core/gameplay/race.tscn")

@onready var disconnect_button = %Disconnect
@onready var host_dialog = %HostDialog
@onready var join_dialog = %JoinDialog
@onready var game_config = %GameConfig
@onready var start_race_button = %StartRace
@onready var ready_button = %Ready
@onready var lobby_window = %LobbyWindow
@onready var player_container = %PlayerDataContainer
@onready var lobby_button = %ShowLobby
@onready var lobby_status = %LobbyStatus
@onready var player_config = %PlayerConfig
@onready var player_data_container = $PlayerDataContainer
@onready var lobby_ui = $Interface
@onready var car_viewer = %CarViewer

@onready var lobby_state_joined = $"LobbyStateJoined"
@onready var lobby_state_hosting = $"LobbyStateHosting"
@onready var lobby_state_disconnected = $"LobbyStateDisconnected"

var race: RaceInterface


func _ready():
	multiplayer.connected_to_server.connect(self.joined)
	multiplayer.server_disconnected.connect(self.disconnected)
	multiplayer.peer_connected.connect(self.peer_connected)
	multiplayer.peer_disconnected.connect(self.peer_disconnected)
	super()


func disconnected():
	self.current_state.disconnected()


func joined():
	self.current_state.joined()


func hosting():
	self.current_state.hosting()


func join(address: String, port: int):
	self.current_state.join(address, port)


func disconnect_from_game():
	self.current_state.disconnect_from_game()


func host(lobby_name: String, port: int):
	self.current_state.host(lobby_name, port)


func peer_connected(id: int):
	self.current_state.peer_connected(id)


func peer_disconnected(id: int):
	self.current_state.peer_disconnected(id)
	if self.race:
		self.race.despawn_player(id)


func game_started():
	self.current_state.game_started()


func game_ended():
	self.current_state.game_ended()


func start_game():
	self.current_state.start_game()


func _input(event):
	if event.is_action_pressed("go_back"):
		self._on_end_race()


func _on_race_finished(race):
	self._set_local_status(Constants.PlayerStatus.IN_LOBBY)
	self.back_to_menu()
	multiplayer.multiplayer_peer.refuse_new_connections = false


func back_to_menu():
	if race:
		race.queue_free()
		race = null
	self.lobby_ui.show()


func _on_race_standby(node):
	node.race_finished.connect(self._on_race_finished.bind(node))
	node.race_waiting_for_players.connect(self._on_waiting_for_players)
	node.set_config(game_config.config)
	self.race = node
	self.lobby_ui.hide()


func _on_waiting_for_players():
	self._set_local_status(Constants.PlayerStatus.IN_GAME_STANDBY)


@rpc("authority", "call_local", "reliable")
func start_race():
	self.race.start_race()
	self.lobby_window.hide()


func _on_end_race():
	if race:
		self.race.end_race()


func _set_local_status(status: Constants.PlayerStatus):
	var local_data = player_data_container.get_local_player_data()
	local_data.player_status = status


func _on_ready_toggled(toggled_on):
	if toggled_on:
		self._set_local_status(Constants.PlayerStatus.IN_LOBBY_READY)
	else:
		self._set_local_status(Constants.PlayerStatus.IN_LOBBY)


func _on_player_config_player_config_changed():
	var local_data = player_data_container.get_local_player_data()
	var player = player_config.player
	local_data.set_config(player)


func _on_player_config_player_car_changed() -> void:
	var player = player_config.player
	var car_data := CarDB.get_car_by_uuid(player.car_uuid)
	if car_data:
		var car = load(car_data.path)
		self.car_viewer.car = car
		var color_list = load(car_data.color_list) as CarColorList
		self.player_config.color_picker.colors = color_list.colors


func _on_player_config_player_color_changed() -> void:
	var player = player_config.player
	var color_set = player.get_color_set()
	self.car_viewer.color_set = color_set
	self.player_config.color_picker.selected_color_set = color_set


func _on_player_data_container_local_player_data_created(node):
	node.set_config(player_config.player)
	self._set_local_status(Constants.PlayerStatus.IN_LOBBY)
	self.lobby_status.set_player_data(node)


func _on_show_lobby_toggled(toggled_on):
	lobby_window.visible = toggled_on


func _on_game_start_requested():
	multiplayer.multiplayer_peer.refuse_new_connections = true
	var instance = race_scene.instantiate()
	instance.ready.connect(self._on_race_standby.bind(instance))
	race = instance
	self.add_child(instance, true)


func _on_player_data_container_data_created(node: PlayerData):
	self.lobby_status.set_player_data(node)


func _on_player_data_container_player_data_removed(node: PlayerData):
	self.lobby_status.remove_player_data(node)

var rng := RandomNumberGenerator.new()

func _rand_elem(arr: Array, default: Variant = null) -> Variant:
	if arr.size() == 0:
		return default
	var idx = rng.randi_range(0, arr.size() - 1)
	return arr[idx]

func _make_ai_player(personality: AiPersonality) -> PlayerConfig:
	var ai_config = PlayerConfig.new()
	var car_data: CarDatabase.CarData = _rand_elem(CarDB.cars.values())
	var color_list = load(car_data.color_list) as CarColorList
	ai_config.car_uuid = car_data.uuid
	ai_config.player_name = personality.name
	var preferred_color := rng.randf() <= personality.preferred_color_probability
	var color_set: CarColorSet = _rand_elem(color_list.colors)
	if color_set:
		if preferred_color:
			color_set.primary = _rand_elem(personality.preferred_primary_colors)
		ai_config.set_color_set(color_set)
	var hair_color: Color = _rand_elem(personality.hair_colors, ai_config.color_driver)
	if hair_color:
		ai_config.color_driver = hair_color
	return ai_config


func _on_player_data_container_all_players_standby():
	var ai_personalities: AiPersonalities = load("res://core/resources/config/ai_default_personalities.tres")
	var personalities := ai_personalities.personalities.duplicate()
	personalities.shuffle()
	for i in game_config.config.num_opponents:
		var player_config = self._make_ai_player(personalities[i])
		self.race.spawn_ai_player(player_config)
	for player in self.player_container.get_players():
		self.race.spawn_player(player.get_player_id(), player.get_config())
	self.start_race.rpc()
