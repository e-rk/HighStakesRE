extends Node
class_name PursuitPolice

enum PoliceState {
	IDLE,
	IN_PURSUIT,
	STOPPING,
	TICKETING,
}

@export var target: NodePath
@export var tickets_given: int = 0
@export var state: PoliceState = PoliceState.IDLE

@onready var player = $".."

func get_target() -> PursuitRacer:
	if not self.target:
		return null
	return self.get_node(self.target) as PursuitRacer
