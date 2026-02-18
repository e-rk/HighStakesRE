class_name PursuitRules
extends SingleRaceRules

@export var num_tickets: int


static func mode_uuid() -> StringName:
	return &"632ba996-3b01-49b2-a8e6-103a67ca8100"


static func mode_display_name() -> StringName:
	return &"Pursuit"


static func get_namespace() -> String:
	return "pursuit"


static func get_config_interface() -> Control:
	return preload("res://core/ui/config/modes/pursuit_configurator.tscn").instantiate()


func get_race_logic() -> Node:
	var node = preload("res://core/gameplay/modes/pursuit.tscn").instantiate()
	node.rules = self
	return node
