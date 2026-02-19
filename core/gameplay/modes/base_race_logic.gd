class_name BaseRaceLogic
extends Node

@export var track: RaceTrack

signal race_finished


func get_spawn_position(player: Player) -> Transform3D:
	return Transform3D.IDENTITY


func player_spawned(player: Player):
	pass


func start():
	pass


func reposition_allowed() -> bool:
	return true
