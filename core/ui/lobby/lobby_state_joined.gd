extends State

@onready var disconnected_popup = $DisconnectedPopup


func enter():
	context.player_container.clear()
	context.start_race_button.disabled = true
	context.game_config.disable()
	context.lobby_window.show()
	super()


func leave():
	super()


func disconnected():
	self.disconnected_popup.show()
	context.set_state(context.lobby_state_disconnected)


func joined():
	assert(false, "Joined in invalid state")


func hosting():
	assert(false, "Started hosting in invalid state")


func join(address: String, port: int):
	pass


func disconnect_from_game():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	context.set_state(context.lobby_state_disconnected)


func peer_connected(id: int):
	pass


func peer_disconnected(id: int):
	pass


func game_started():
	context.lobby_window.hide()


func game_ended():
	context.lobby_window.show()


func start_game():
	pass
