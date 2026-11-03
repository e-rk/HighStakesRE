class_name GameConfig
extends Resource

enum OpponentClass { Any, AAA, AA, A, B, None, SameAsMe }

@export var track: TrackConfig
@export var rules: RaceRules
@export var num_opponents: int
@export var opponent_class := OpponentClass.Any
