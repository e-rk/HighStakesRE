extends BaseRaceLogic
class_name Pursuit

@export var rules: PursuitRules

@onready var spectator = $PlayerSpectator

signal racer_finished(racer: Player)

var players_spawned := 0

const POLICE_TARGET_ACQUIRE_DISTANCE = 100
const POLICE_TARGET_LOSE_DISTANCE = 250
const POLICE_BUST_STEP = 80


func get_spawn_position(_player: Player) -> Transform3D:
	const SPAWN_DISTANCE := 10.0
	const LATERAL_OFFSET := 2.0
	var distance := -self.players_spawned * SPAWN_DISTANCE
	var direction := 1.0 if self.players_spawned % 2 == 0 else -1.0
	var position := self.track.nav_path.advance_by_distance_smooth(0.0, self.track.nav_path.points[0], distance)
	var orientation := self.track.nav_path.orientations[0]
	var shifted := position + orientation * Vector3(direction * LATERAL_OFFSET, 0, 0)
	self.players_spawned += 1
	return Transform3D(orientation, shifted)


func player_spawned(player: Player):
	if player.car.is_police():
		var police = preload("res://core/gameplay/pursuit_police.tscn").instantiate()
		player.add_child(police, true)
		police.owner = player
		player.set_meta(&"pursuit_info", police)
	else:
		var racer = preload("res://core/gameplay/pursuit_racer.tscn").instantiate()
		player.add_child(racer, true)
		racer.owner = player
		player.set_meta(&"pursuit_info", racer)
	if player.is_local():
		player.add_to_group(&"SpectatedPlayer")


func start():
	var players: Array[Player]
	players.assign(get_tree().get_nodes_in_group(&"Players"))
	for player in players:
		player.disable_steering = false
	var racers: Array[Racer]
	racers.assign(get_tree().get_nodes_in_group(&"PursuitRacers"))
	for racer in racers:
		racer.start_timer()


func _ready():
	var waypoints = self.track.get_waypoints()
	self.spectator.set_waypoints(waypoints)
	self.spectator.race_laps = self.rules.num_laps
	self.spectator.num_tickets = self.rules.num_tickets
	if self.get_multiplayer_authority() != multiplayer.get_unique_id():
		self.process_mode = Node.PROCESS_MODE_DISABLED


func _check_end_conditions():
	var racers: Array[Racer]
	racers.assign(get_tree().get_nodes_in_group(&"PursuitRacers"))
	if racers.all(func(x): return x.laps > rules.num_laps or x.arrested):
		self.race_finished.emit()


func distance_modulo(a: int, b: int, n: int) -> int:
	var ab = abs(a - b)
	return min(ab, n - ab)


func track_distance(a: Player, b: Player) -> int:
	var track_length = round(self.track.nav_path.get_track_length())
	var a_offset = round(a.position_along_track)
	var b_offset = round(b.position_along_track)
	return distance_modulo(a_offset, b_offset, track_length)


func get_distance(offset: float, x: Racer, y: Racer) -> int:
	var track_length = round(self.track.nav_path.get_track_length())
	var x_offset = round(x.player.position_along_track)
	var y_offset = round(y.player.position_along_track)
	var x_result = distance_modulo(offset, x_offset, track_length)
	var y_result = distance_modulo(offset, y_offset, track_length)
	return x_result < y_result


func _get_closest_racer(offset: float, candidates: Array[PursuitRacer]) -> Racer:
	candidates.sort_custom(func(x, y): return get_distance(offset, x, y))
	if not candidates:
		return null
	return candidates[0]


func is_valid_target(police: PursuitPolice, target: PursuitRacer) -> bool:
	var distance = self.track_distance(police.player, target.player)
	var distance_criteria = distance <= self.POLICE_TARGET_ACQUIRE_DISTANCE
	return distance_criteria


func _assign_target(police: PursuitPolice):
	if not police.player.car.is_siren_active():
		police.target = NodePath()
		return
	var candidates: Array[PursuitRacer]
	candidates.assign(get_tree().get_nodes_in_group(&"PursuitRacers"))
	candidates = candidates.filter(func(x): return x.tickets < self.rules.num_tickets)
	var closest_racer = self._get_closest_racer(police.player.position_along_track, candidates)
	if closest_racer and self.is_valid_target(police, closest_racer):
		police.target = closest_racer.get_path()
		police.state = PursuitPolice.PoliceState.IN_PURSUIT


func _bust_score(police_car: Car, racer_car: Car) -> float:
	var relative_velocity = police_car.linear_velocity - racer_car.linear_velocity
	var relative_speed_sq = relative_velocity.length()
	var distance = police_car.global_position.distance_to(racer_car.global_position)
	var baseline = 100 - remap(distance, 0, 20, -50, 100)
	var speed_factor = remap(relative_speed_sq, 0, 20, 0, 70)
	var score = clampi(baseline - speed_factor, 0, 100)
	return score


func _process_pursuit(police: PursuitPolice, delta: float):
	var target = self.get_node(police.target) as PursuitRacer
	if not target:
		police.state = PursuitPolice.PoliceState.IDLE
		return
	var score = self._bust_score(police.player.car, target.player.car)
	var new_score: float = move_toward(target.bust_score, score, delta * self.POLICE_BUST_STEP)
	target.bust_score = new_score
	var distance = self.track_distance(police.player, target.player)
	if not police.player.car.is_siren_active() or distance >= self.POLICE_TARGET_LOSE_DISTANCE:
		police.target = NodePath()
		target.bust_score = 0.0
		target.player.disable_steering = false
		police.state = PursuitPolice.PoliceState.IDLE
	elif is_equal_approx(new_score, 100):
		target.player.disable_steering = true
		police.player.disable_steering = true
		police.state = PursuitPolice.PoliceState.STOPPING


func _process_stop(police: PursuitPolice, _delta: float):
	var target = self.get_node(police.target) as PursuitRacer
	if not target:
		police.state = PursuitPolice.PoliceState.IDLE
		police.player.disable_steering = false
		return
	if target.player.car.linear_velocity.length() <= 0.5:
		police.state = PursuitPolice.PoliceState.TICKETING
		target.busted = true
		target.arrested = target.tickets >= (self.rules.num_tickets - 1)
		target.busted_timestamp = Time.get_ticks_msec()


func _process_busted(_delta: float):
	var racers: Array[PursuitRacer]
	racers.assign(get_tree().get_nodes_in_group(&"PursuitRacers"))
	var police: Array[PursuitPolice]
	police.assign(get_tree().get_nodes_in_group(&"Police"))
	var current_time = Time.get_ticks_msec()
	var grouped_by_targets = {}
	for pol in police:
		var target = pol.get_target()
		if target and target.busted:
			var prev = grouped_by_targets.get(target, [])
			prev.append(pol)
			grouped_by_targets[target] = prev
	for racer in grouped_by_targets:
		var ticket_elapsed = (current_time - racer.busted_timestamp) <= 5000
		if ticket_elapsed:
			continue
		for pol in grouped_by_targets[racer]:
			pol.state = PursuitPolice.PoliceState.IDLE
			pol.player.disable_steering = false
			pol.target = NodePath()
		if not racer.arrested:
			racer.player.disable_steering = false
		racer.bust_score = 0
		racer.busted = false
		racer.tickets += 1


func _process_racers(_delta: float):
	var racers: Array[Racer]
	racers.assign(get_tree().get_nodes_in_group(&"PursuitRacers"))
	for racer in racers:
		var progress = racer.player.position_along_track / self.track.nav_path.get_track_length()
		var prev_progress = racer.track_progress
		if prev_progress > 0.9 and progress < 0.1:
			racer.laps += 1
		elif prev_progress < 0.1 and progress > 0.9:
			racer.laps -= 1
		racer.track_progress = progress


func _process_police(delta: float):
	var police: Array[PursuitPolice]
	police.assign(get_tree().get_nodes_in_group(&"Police"))
	for pol in police:
		match pol.state:
			PursuitPolice.PoliceState.IDLE:
				self._assign_target(pol)
			PursuitPolice.PoliceState.IN_PURSUIT:
				self._process_pursuit(pol, delta)
			PursuitPolice.PoliceState.STOPPING:
				self._process_stop(pol, delta)
			PursuitPolice.PoliceState.TICKETING:
				pass


func _physics_process(delta):
	super(delta)
	self._process_racers(delta)
	self._process_police(delta)
	self._process_busted(delta)
	self._check_end_conditions()
