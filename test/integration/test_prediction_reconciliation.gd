## **THE SIMULATION SNAPS; THE VISUAL BLENDS.** TDD-04 §4.2, US-0032, US-0033.
##
## The chapter calls that its most important sentence, so it is the first thing
## asserted here — and separately, because the two halves fail differently. A
## simulation that blended would run every later prediction from a position the
## server never had and the error would **compound**; a visual that snapped would
## be a pop the player sees on every packet.
##
## The server is real: a `PawnHost` driving `pawn_server.tscn` against the real
## map, fed the client's own sampled commands, exactly as `NET-C2S-INPUT` would.
## The **latency** is what is synthetic — snapshots are held for a chosen number
## of frames and delivered late, which is the one thing a single process cannot
## get for free.
extends GutTest

const CLIENT_ROOT := "res://scenes/client_root.tscn"
const PEER := 1

var _root: Node
var _driver: LocalPawnDriver
var _reconciler: Reconciler
var _host: PawnHost
var _builder: SnapshotBuilder
var _ctx := MatchContext.new()
var _in_flight: Array = []


func before_each() -> void:
	_release_everything()
	_in_flight = []
	_root = add_child_autofree((load(CLIENT_ROOT) as PackedScene).instantiate())
	_driver = _root.get_node("LocalPawnDriver")
	_reconciler = _root.get_node("ClientNet/Reconciler")

	_ctx = MatchContext.new()
	_ctx.map = load("res://data/maps/map_vetraio.tres") as MapData
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_host = PawnHost.new()
	add_child_autofree(_host)
	_host.setup(_ctx)
	_builder = SnapshotBuilder.new()
	add_child_autofree(_builder)
	_builder.setup(_ctx, _host, null)
	await get_tree().physics_frame


func after_each() -> void:
	_release_everything()


func _release_everything() -> void:
	for id: StringName in InputActions.ids():
		for name: StringName in InputActions.action_names(id):
			if InputMap.has_action(name):
				Input.action_release(name)


## Stand a server pawn up where the client's is, and feed it the client's own
## commands. `latency_frames` snapshots are held in flight before delivery.
func _mirror(latency_frames: int) -> void:
	_ctx.slots.assign(PEER)
	_host.spawn(PEER)
	var server := _host.context_for(PEER)
	server.reset_for_spawn(_driver.ctx.position, _driver.ctx.yaw)
	(server.body as CharacterBody3D).global_position = server.position

	_driver.command_sampled.connect(
		func(command: InputCommand) -> void:
			_host.apply_input(PEER, command, MatchContext.step_dt())
			_send_late(command.seq, latency_frames)
	)


## Build a snapshot for this moment and hold it for `frames` before the client
## sees it. The ack is the command just applied, which is what the server's
## sequence gate would have recorded.
func _send_late(acked_seq: int, frames: int) -> void:
	var snapshot := _builder.build_for(PEER)
	snapshot.last_acked_seq = acked_seq
	_in_flight.append([frames, snapshot])


## Advance every held snapshot by one frame and deliver the ones that landed.
func _deliver() -> void:
	var still: Array = []
	for entry: Array in _in_flight:
		if int(entry[0]) <= 0:
			_reconciler._on_snapshot_received(entry[1] as Snapshot)
		else:
			still.append([int(entry[0]) - 1, entry[1]])
	_in_flight = still


func _run(frames: int) -> void:
	for _i: int in frames:
		_deliver()
		await get_tree().physics_frame


## Run until the reconciler actually corrects, or give up. **EVENT-DRIVEN, NOT
## FRAME-COUNTED**: the snapshot carrying a shove is built on the NEXT sampled
## command and then held for its latency, so "three frames later" is a guess that
## silently reads the moment before the correction — which is how the first
## version of the visual test measured an offset of zero and called it a defect.
func _run_until_replay(limit: int) -> bool:
	for _i: int in limit:
		_deliver()
		await get_tree().physics_frame
		if _reconciler.replays > 0:
			return true
	return false


func _divergence() -> float:
	return _driver.ctx.position.distance_to(_host.context_for(PEER).position)


## One latency profile, walked for 90 frames. **A SEPARATE TEST PER PROFILE**,
## not a loop: calling `before_each()` by hand stands up a second client and a
## second server without freeing the first, and every one of them keeps being
## driven — the first version of this file did exactly that and reported a
## divergence that grew with latency because three pawns were sharing one input.
func _walk_at_latency(frames: int) -> void:
	await _mirror(frames)
	Input.action_press(&"input_move_forward")
	await _run(90)
	assert_lt(
		_divergence(),
		Tuning.net.reconcile_threshold,
		"at %d frames of latency the client left the server behind" % frames
	)


func test_it_converges_on_a_lan() -> void:
	await _walk_at_latency(1)


func test_it_converges_at_fifty_milliseconds() -> void:
	await _walk_at_latency(3)


func test_it_converges_at_a_hundred_milliseconds() -> void:
	await _walk_at_latency(6)


func test_it_converges_on_a_bad_connection() -> void:
	# **CONVERGES, NEVER COMPOUNDS.** The design claim is that reconciliation does
	# not get worse with distance, only busier.
	await _walk_at_latency(11)


func test_a_forced_divergence_snaps_the_simulation_exactly() -> void:
	# **EXACTLY**, not within a threshold. If the simulation only got close, the
	# next prediction would run from somewhere the server never was.
	await _mirror(2)
	Input.action_press(&"input_move_forward")
	await _run(20)

	# Shove the server pawn sideways — a correction no prediction could have made.
	var server := _host.context_for(PEER)
	server.position += Vector3(2.0, 0.0, 0.0)
	(server.body as CharacterBody3D).global_position = server.position
	await _run(20)

	assert_gt(_reconciler.replays, 0, "a two-metre disagreement did not replay")
	assert_lt(_divergence(), Tuning.net.reconcile_threshold, "the correction did not converge")


func test_the_visual_blends_while_the_simulation_has_already_moved() -> void:
	# The other half of the sentence. After a snap the drawn pawn is behind the
	# simulated one, and closes over `TUN-NET-RECONCILE-SMOOTH-TIME` rather than
	# arriving with it.
	await _mirror(2)
	Input.action_press(&"input_move_forward")
	await _run(20)
	var server := _host.context_for(PEER)
	server.position += Vector3(2.0, 0.0, 0.0)
	(server.body as CharacterBody3D).global_position = server.position

	assert_true(await _run_until_replay(30), "the shove never produced a correction")
	var immediately := _reconciler.visual_offset().length()
	assert_gt(
		immediately, 0.0, "the correction was applied with no visual offset — the player saw a pop"
	)
	await _run(20)
	assert_lt(_reconciler.visual_offset().length(), immediately, "the offset is not decaying")


func test_the_visual_offset_is_gone_within_the_smoothing_time() -> void:
	await _mirror(2)
	Input.action_press(&"input_move_forward")
	await _run(20)
	var server := _host.context_for(PEER)
	server.position += Vector3(2.0, 0.0, 0.0)
	(server.body as CharacterBody3D).global_position = server.position

	assert_true(await _run_until_replay(30), "the shove never produced a correction")
	# Generously more than TUN-NET-RECONCILE-SMOOTH-TIME's 0.12 s at 60 Hz.
	await _run(60)
	assert_almost_eq(
		_reconciler.visual_offset().length(), 0.0, 0.01, "the offset never finished decaying"
	)


func test_an_agreeing_server_never_replays() -> void:
	# **THE COMMON CASE MUST BE FREE.** The client and the server run the same
	# code from the same commands, so an ordinary walk produces no correction at
	# all — and a reconciler that replayed anyway would be doing 32 steps of
	# physics per snapshot for nothing.
	await _mirror(2)
	Input.action_press(&"input_move_forward")
	await _run(90)
	assert_eq(_reconciler.replays, 0, "an agreeing server still forced a replay")


func test_the_buffer_never_grows_past_its_bound() -> void:
	# `TUN-NET-INPUT-BUFFER-SIZE` covers ~530 ms of unacked input at 60 Hz. Past
	# that the oldest is dropped, loudly enough to count.
	await _mirror(40)
	Input.action_press(&"input_move_forward")
	await _run(90)
	assert_lte(
		_driver.history.size(),
		_driver.history.capacity(),
		"the reconciliation buffer grew past its cap"
	)
	assert_gt(_driver.history.overflowed, 0, "a 40-frame stall did not overflow the buffer")
