class_name SingleRace
extends BaseRaceLogic

@export var rules: SingleRaceRules

@onready var spectator = $PlayerSpectator

signal racer_finished(racer: Player)

var players_spawned := 0

const SLOT_SPACING_BLOCKS := 3
const RACER_LANE_MARGIN := 0.5

func racer_block(slot: int) -> int:
	var block := -slot * SLOT_SPACING_BLOCKS - 1
	return posmod(block, self.track.nav_path.points.size())


func racer_lateral_offset(slot: int) -> float:
	var block := self.racer_block(slot)
	if slot % 2 == 0:
		return -(RACER_LANE_MARGIN + 0.5 * self.track.nav_path.left_lane_widths[block])
	return RACER_LANE_MARGIN + 0.5 * self.track.nav_path.right_lane_widths[block]


func _transform_on_block(block: int, lateral_offset: float) -> Transform3D:
	var basis := self.track.nav_path.orientations[block]
	var position := self.track.nav_path.points[block] - basis.x * lateral_offset
	return Transform3D(basis, position)


func racer_transform(slot: int) -> Transform3D:
	return self._transform_on_block(self.racer_block(slot), self.racer_lateral_offset(slot))


func get_spawn_position(player: Player) -> Transform3D:
	var transform := self.racer_transform(self.players_spawned)
	self.players_spawned += 1
	return transform


func player_spawned(player: Player):
	var racer = preload("res://core/gameplay/racer.tscn").instantiate()
	player.add_child(racer, true)
	racer.owner = player
	if player.is_local():
		player.add_to_group(&"SpectatedPlayer")


func start():
	var players: Array[Player]
	players.assign(get_tree().get_nodes_in_group(&"Players"))
	for player in players:
		player.disable_steering = false
	var racers: Array[Racer]
	racers.assign(get_tree().get_nodes_in_group(&"Racers"))
	for racer in racers:
		racer.start_timer()


func _ready():
	super()
	var waypoints = self.track.get_waypoints()
	self.spectator.set_waypoints(waypoints)
	self.spectator.race_laps = self.rules.num_laps
	if self.get_multiplayer_authority() != multiplayer.get_unique_id():
		self.set_physics_process(false)


func _check_end_conditions(racers):
	if racers.all(func(x): return x.laps > rules.num_laps):
		self.race_finished.emit()


func _physics_process(delta):
	super(delta)
	var racers: Array[Racer] = []
	racers.assign(get_tree().get_nodes_in_group(&"Racers"))
	for racer in racers:
		var progress = racer.player.position_along_track / self.track.nav_path.get_track_length()
		var prev_progress = racer.track_progress
		if prev_progress > 0.9 and progress < 0.1:
			racer.laps += 1
			if racer.laps > racer.max_laps:
				racer.capture_time()
			racer.max_laps = max(racer.laps, racer.max_laps)
		elif prev_progress < 0.1 and progress > 0.9:
			racer.laps -= 1
		racer.track_progress = progress
	self._check_end_conditions(racers)
