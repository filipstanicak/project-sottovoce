## Three-process client probe plus server. Fixture awards and accelerated phase clocks.
## Exercises the real handshake, result courier, wire, snapshot bridge and client root.
## Run this scene with normal --server / --connect flags, --map sandbox --crowd 0.
extends Node

var _root: Node
var _seeded: bool = false
var _finished: bool = false


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	var config := LaunchConfig.parse(
		OS.get_cmdline_user_args(), Tuning.match_rules.max_players, Tuning.match_rules.min_players
	)
	LaunchConfig.active = config
	if config.is_server:
		get_tree().physics_interpolation = false
		if not Net.start_server(config.port, config.max_players):
			get_tree().quit(1)
			return
		_root = (load("res://scenes/server_root.tscn") as PackedScene).instantiate()
	else:
		Net.join(config.connect_host(), config.connect_port())
		_root = (load("res://scenes/client_root.tscn") as PackedScene).instantiate()
	add_child(_root)
	await get_tree().create_timer(45.0).timeout
	if not _finished:
		if not config.is_server:
			var results := _root.get_node("Results") as ResultsRoot
			print(
				(
					"RESULTS PROBE timeout: available=%s active=%s players=%d best=%d"
					% [
						results.vm.available,
						results.vm.active,
						results.vm.players.size(),
						results.vm.best_points
					]
				)
			)
		push_error("RESULTS PROBE timed out without a visible, populated result")
		get_tree().quit(1)


func _process(_delta: float) -> void:
	if _root == null or _finished:
		return
	if Net.is_server:
		_advance_fixture()
	else:
		_check_delivery()


func _advance_fixture() -> void:
	var director := _root.get_node("MatchDirector") as MatchDirector
	var clock: MatchSystem = _root.get("match_state")
	var phase := director.ctx.phase
	if phase == MatchPhase.Phase.ACTIVE and not _seeded:
		var peers := director.ctx.slots.peers()
		if peers.size() != 3:
			return
		_seeded = true
		var first := int(peers[0])
		var second := int(peers[1])
		director.ctx.score.append(
			ScoreAward.new(10, Ids.SCORE_CONTRACT, first, second, 100), Tuning.match_rules, 1
		)
		director.ctx.score.append(
			ScoreAward.new(10, Ids.SCORE_SILENT, first, second, 200), Tuning.match_rules, 1
		)
		director.ctx.score.mark_death(10, second, first, Tuning.match_rules, 1)
	if _seeded and phase in [MatchPhase.Phase.ACTIVE, MatchPhase.Phase.FINAL]:
		clock.phase_elapsed = MatchClock.duration_ticks(phase, Tuning.match_rules)
	if phase == MatchPhase.Phase.RESULTS:
		_finished = true
		print("RESULTS PROBE server reached RESULTS through MatchSystem")
		await get_tree().create_timer(30.0).timeout
		get_tree().quit()


func _check_delivery() -> void:
	var results := _root.get_node("Results") as ResultsRoot
	if not results.visible or not results.vm.available:
		return
	_finished = true
	var vm := results.vm
	var valid := vm.players.size() == 3 and vm.best_points == 300
	valid = valid and vm.selected == GameState.local_peer_id
	valid = valid and not (_root.get_node("Hud") as CanvasLayer).visible
	valid = valid and not (_root.get_node("InputSampler") as InputSampler).mouse_captured()
	if not valid:
		push_error("RESULTS PROBE delivered an incorrect screen")
		get_tree().quit(1)
		return
	print(
		(
			"RESULTS PROBE PASS slot=%d players=%d best=%d"
			% [vm.selected, vm.players.size(), vm.best_points]
		)
	)
	await _check_expiry(results)


func _check_expiry(results: ResultsRoot) -> void:
	var natural := "--natural-expiry" in OS.get_cmdline_user_args()
	if not natural:
		await get_tree().create_timer(float(GameState.local_peer_id) * 0.7).timeout
		if not results.visible:
			push_error("RESULTS PROBE closed before everybody voted")
			get_tree().quit(1)
			return
		_press_skip(results.screen)
		if not results.vm.requested:
			push_error("RESULTS PROBE button did not send its vote")
			get_tree().quit(1)
			return
	var waited := 0.0
	while not results.vm.finished and waited < 30.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	var valid := results.vm.finished and not results.visible and results.vm.active
	valid = valid and not (_root.get_node("Hud") as CanvasLayer).visible
	valid = valid and results.vm.seconds_left == 0
	if natural:
		valid = valid and waited >= 24.0
	else:
		valid = valid and waited < 5.0
	if not valid:
		push_error("RESULTS PROBE expiry did not follow the authoritative clock")
		get_tree().quit(1)
		return
	print("RESULTS PROBE EXPIRY PASS natural=%s waited=%.1f" % [natural, waited])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _press_skip(screen: ResultsScreen) -> void:
	var button := screen.find_child("SkipResults", true, false) as Button
	if button == null or button.disabled:
		push_error("RESULTS PROBE skip button is unavailable")
		get_tree().quit(1)
		return
	button.pressed.emit()
