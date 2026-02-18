extends Racer
class_name PursuitRacer

@export var tickets: int = 0
@export var bust_score: float = 0.0
@export var busted_timestamp: int = 0
@export var busted: bool = false
@export var arrested: bool = false

@onready var player_name: Label = $RacerInfo/PlayerName
@onready var busted_meter: ProgressBar = $RacerInfo/BustedMeter
@onready var racer_info: Control = $RacerInfo

func _ready() -> void:
	self.player_name.text = self.player.player_name
