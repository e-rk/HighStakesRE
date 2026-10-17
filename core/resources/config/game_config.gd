class_name GameConfig
extends Resource

enum OpponentClass { ANY, AAA, AA, A, B }

@export var track: TrackConfig
@export var rules: RaceRules
@export var num_opponents: int
@export var opponent_class := OpponentClass.ANY
