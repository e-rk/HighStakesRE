class_name Constants
extends Node

enum CollisionLayer {
	TRACK_ROAD = 0,
	TRACK_WALLS = 1,
	TRACK_CEILING = 2,
	RACERS = 3,
	TRAFFIC = 4,
	POLICE = 5,
	OBJECTS = 6,
}

enum VisualLayer {
	TRACK = 0,
	OPPONENTS = 1,
	PLAYER = 2,
	PLAYER_INTERIOR = 3,
}

enum PlayerStatus { UNKNOWN, IN_LOBBY, IN_LOBBY_READY, IN_GAME_STANDBY, IN_GAME_PLAYING }


static func collision_layer_to_mask(layers: Array[CollisionLayer]) -> int:
	var mask = 0
	for layer in layers:
		mask |= 1 << layer
	return mask

static func visual_layer_to_mask(layers: Array[VisualLayer]) -> int:
	var mask = 0
	for layer in layers:
		mask |= 1 << layer
	return mask

static func player_status_to_str(status: PlayerStatus) -> String:
	match status:
		PlayerStatus.UNKNOWN:
			return "Unknown"
		PlayerStatus.IN_LOBBY:
			return "Connected"
		PlayerStatus.IN_LOBBY_READY:
			return "Ready"
		PlayerStatus.IN_GAME_STANDBY:
			return "In-game (standing-by)"
		PlayerStatus.IN_GAME_PLAYING:
			return "In-game"
		_:
			return ""
