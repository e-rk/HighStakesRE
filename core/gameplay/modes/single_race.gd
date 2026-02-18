class_name SingleRace
extends BaseRaceLogic

@export var rules: SingleRaceRules

@onready var spectator = $PlayerSpectator

signal racer_finished(racer: Player)

var players_spawned := 0


func get_spawn_position(_player: Player) -> Transform3D:
	var spawn_transform = track.get_spawn_transform(self.players_spawned)
	self.players_spawned += 1
	return spawn_transform


func player_spawned(player: Player):
	var racer = Racer.new()
	racer.car = player.car
	player.add_child(racer)
	racer.add_to_group(&"Racers")
	if player.is_local():
		racer.add_to_group(&"SpectatedRacer")


func _ready():
	var waypoints = self.track.get_waypoints()
	self.spectator.set_waypoints(waypoints)
	self.spectator.race_laps = self.rules.num_laps


func _check_end_conditions(racers):
	if racers.all(func(x): return x.laps > rules.num_laps):
		self.race_finished.emit()


func _physics_process(delta):
	var racers: Array[Racer] = []
	racers.assign(get_tree().get_nodes_in_group(&"Racers"))
	for racer in racers:
		var progress = self.track.progress_along_track(racer.car.global_position)
		var prev_progress = racer.track_progress
		if prev_progress > 0.9 and progress < 0.1:
			racer.laps += 1
		elif prev_progress < 0.1 and progress > 0.9:
			racer.laps -= 1
		racer.track_progress = progress
	self._check_end_conditions(racers)
