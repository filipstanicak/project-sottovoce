## One authoritative pawn per peer. US-0028.
##
## An integration test rather than a unit one, because the thing being asserted
## is that `pawn_server.tscn` really instantiates into something drivable: a
## state machine, probes that can see the district, and a body the map's
## collision holds up. A double for any of those would pass while the real scene
## was broken — which is trap 4, and how the boot path shipped broken twice.
extends GutTest

const MAP_COLLISION := "res://scenes/map/map_vetraio_collision.tscn"
const PEER := 11
const OTHER := 12

var _host: PawnHost
var _ctx := MatchContext.new()


func before_each() -> void:
	# **THE DISTRICT'S COLLISION, NOT ONLY ITS DATA.** `MapData` gives the host
	# spawn points; the pawn needs something to stand on. Without it every pawn
	# here falls, and "the pawn moved more than half a metre" is true of a pawn
	# dropping out of the world — trap 4, caught by this file's own probe
	# assertion on its first run.
	add_child_autofree((load(MAP_COLLISION) as PackedScene).instantiate())
	_host = PawnHost.new()
	add_child_autofree(_host)
	_ctx = MatchContext.new()
	_ctx.map = load("res://data/maps/map_vetraio.tres") as MapData
	_host.setup(_ctx)
	await get_tree().physics_frame


func test_a_peer_gets_a_pawn_and_it_is_a_real_one() -> void:
	assert_true(_host.spawn(PEER), "the pawn did not spawn")
	var ctx := _host.context_for(PEER)
	assert_not_null(ctx, "the pawn has no context")
	assert_not_null(ctx.body, "the pawn has no body")
	assert_eq(ctx.state_id, PawnStateId.IDLE, "the pawn did not spawn into Idle")


func test_it_spawns_on_a_declared_spawn_point() -> void:
	# Not the origin, which is a corner of the map and where a pawn ends up when
	# the lookup silently fails.
	_host.spawn(PEER)
	var position := _host.context_for(PEER).position
	assert_almost_eq(position.distance_to(_ctx.map.spawn_points[0]), 0.0, 0.01)


func test_two_peers_do_not_share_a_pawn() -> void:
	_host.spawn(PEER)
	_host.spawn(OTHER)
	assert_eq(_host.pawn_count(), 2)
	assert_ne(_host.context_for(PEER), _host.context_for(OTHER), "two peers share one context")
	assert_ne(
		_host.context_for(PEER).position,
		_host.context_for(OTHER).position,
		"two peers spawned on top of each other"
	)


func test_spawning_twice_is_refused() -> void:
	# A second hello from a peer that already has a pawn must not leave two
	# simulating against the same inputs — one of which nothing would ever free.
	assert_true(_host.spawn(PEER))
	assert_false(_host.spawn(PEER), "a second pawn was created for one peer")
	assert_eq(_host.pawn_count(), 1)


func test_the_context_reaches_the_match() -> void:
	# `MatchContext.pawns` is what the director walks to decide who needs a
	# substep, and what the snapshot builder will walk in US-0030.
	_host.spawn(PEER)
	assert_true(_ctx.pawns.has(PEER), "the pawn never reached the match context")
	_host.despawn(PEER)
	assert_false(_ctx.pawns.has(PEER), "a freed pawn stayed in the match context")


func test_the_two_pawn_dictionaries_never_disagree() -> void:
	# **`pawns` HOLDS BODIES AND `pawn_contexts` HOLDS STATE** (US-0052), written
	# and erased on adjacent lines here. Two dictionaries keyed the same way is a
	# drift risk, and the drift is silent in the worst direction: `SYS-SUSPICION`
	# walks the contexts, so a peer present in one and not the other is a player
	# whose suspicion never moves while everything else about them works.
	_host.spawn(PEER)
	assert_eq(
		_ctx.pawns.keys(),
		_ctx.pawn_contexts.keys(),
		"the two pawn dictionaries hold different peers"
	)
	assert_same(
		_ctx.pawn_contexts[PEER],
		_host.context_for(PEER),
		"MatchContext holds a different context object from the one PawnHost simulates"
	)
	# **`peer_id` WAS DECLARED IN M1 AND NEVER WRITTEN UNTIL US-0053.** Nothing read
	# it, so nothing was wrong — and the first thing that would have, `SYS-BLEND`
	# asking which formation slot this player holds, would have asked about peer
	# **zero**. `CrowdFormations.group_of_peer(0)` answers with the first *unclaimed*
	# group, so a player who never joined one would have read as standing in its
	# slot: a confidently wrong answer rather than an empty one.
	assert_eq(
		_host.context_for(PEER).peer_id, PEER, "the pawn context does not know whose pawn it is"
	)
	_host.despawn(PEER)
	assert_eq(_ctx.pawns.keys(), _ctx.pawn_contexts.keys(), "a freed pawn left one dictionary only")
	assert_false(_ctx.pawn_contexts.has(PEER), "a freed pawn stayed in pawn_contexts")


func test_a_peer_that_leaves_takes_its_pawn_with_it() -> void:
	_host.spawn(PEER)
	_host.despawn(PEER)
	assert_eq(_host.pawn_count(), 0)
	assert_null(_host.context_for(PEER), "a freed pawn still has a context")
	assert_false(_host.has_pawn(PEER))


func test_despawning_an_unknown_peer_is_harmless() -> void:
	# Disconnect arrives for peers that never completed a handshake, so this is
	# the ordinary case rather than the defensive one.
	_host.despawn(9999)
	assert_eq(_host.pawn_count(), 0)


func test_input_moves_the_authoritative_pawn() -> void:
	# **THE ASSERTION THE FILE IS FOR.** Everything else could pass on a pawn that
	# exists and never simulates.
	_host.spawn(PEER)
	var ctx := _host.context_for(PEER)
	var start := ctx.position
	var command := InputCommand.empty(1)
	command.move = Vector2(0.0, 1.0)
	for _i: int in 60:
		_host.apply_input(PEER, command, 1.0 / Tuning.net.client_input_rate)
		await get_tree().physics_frame
	# **HORIZONTALLY, AND STILL ON THE GROUND.** A pawn falling through the world
	# also travels more than half a metre, which is the exact assertion that hid
	# three defects in US-0019 (trap 4).
	var travelled := Vector2(ctx.position.x - start.x, ctx.position.z - start.z)
	assert_gt(travelled.length(), 0.5, "the server pawn did not walk anywhere")
	assert_almost_eq(ctx.position.y, start.y, 0.05, "the server pawn left the ground")
	assert_true(ctx.grounded, "the server pawn is not standing on anything")


func test_input_for_a_peer_with_no_pawn_does_nothing() -> void:
	# The router refuses this case too, and both refusals are wanted: the
	# authority check is a rule, and this is the last line of it.
	_host.apply_input(9999, InputCommand.empty(1), 1.0 / Tuning.net.client_input_rate)
	assert_eq(_host.pawn_count(), 0)


func test_the_probes_see_the_district_from_the_server_pawn() -> void:
	# Criterion: traversal probes run server-side against the same WORLD layer.
	# A server whose probes saw nothing would refuse every vault the client
	# predicted — and the correction would drag the player back through the wall.
	_host.spawn(PEER)
	var ctx := _host.context_for(PEER)
	_host.apply_input(PEER, InputCommand.empty(1), 1.0 / Tuning.net.client_input_rate)
	await get_tree().physics_frame
	_host.apply_input(PEER, InputCommand.empty(2), 1.0 / Tuning.net.client_input_rate)
	assert_true(ctx.probe_result.valid, "the server's probes never ran")
	assert_true(
		ctx.probe_result.ground_ahead, "the server's probes cannot see the floor it stands on"
	)
