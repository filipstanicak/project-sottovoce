## **WHAT ONE CLIENT IS TOLD ABOUT THE CROWD.** US-0030, TDD-04 §7.2, ADR-0007.
##
## Three of US-0030's criteria have been unticked since M2 with the same note —
## "there is no crowd until M3" — and there is one now. The builder emitted no NPC
## at all until this story, which the M3 gate's `test_crowd_bandwidth.gd` asserted
## rather than assumed, so that file's guard is what says this one had to be
## written.
##
## **THE COUNTERFACTUAL IS ASSERTED BEFORE THE RULE.** "Everything beyond 70 m is
## omitted" is perfectly true of a crowd that is entirely inside 70 m, and of a
## builder that emits nothing whatsoever. Both would go green. So the first test
## requires the scenario to contain NPCs on *both* sides of the line, and requires
## the near ones to actually arrive.
extends GutTest

const MAP_DATA := "res://data/maps/map_vetraio.tres"
const SEED := 20260818

## Small and hand-placed. This file is about *which* NPCs are chosen, so a
## realistic crowd would only make the arithmetic harder to read — the bandwidth
## that a realistic crowd costs is `test_crowd_bandwidth.gd`'s subject.
const CROWD := 12

const ALICE := 4001
const BOB := 4002

var _ctx: MatchContext
var _host: PawnHost
var _builder: SnapshotBuilder
var _pool: NpcPool


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.map = load(MAP_DATA) as MapData
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_host = PawnHost.new()
	add_child_autofree(_host)
	_host.setup(_ctx)
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(CROWD)
	_pool.activate(CROWD, SEED, CrowdRoster.PLAYABLE, 6)
	_ctx.crowd = _pool
	_builder = SnapshotBuilder.new()
	add_child_autofree(_builder)
	_builder.setup(_ctx, _host, null)
	await get_tree().physics_frame


## Put a player somewhere exactly, rather than wherever the map's spawn points
## happen to be — this file's whole subject is a distance from that point.
func _player_at(peer: int, at: Vector3) -> void:
	_ctx.slots.assign(peer)
	_host.spawn(peer)
	_host.context_for(peer).position = at


## **HALF THE CROWD INSIDE THE RADIUS AND HALF OUTSIDE**, deliberately, so both
## halves of the rule have something to be true about. Positions are laid out
## along +x from the origin so the expected answer can be read off by hand.
func _straddle_the_radius(origin: Vector3) -> void:
	var reach: float = Tuning.net.npc_cull_radius
	for index: int in CROWD:
		var inside := index % 2 == 0
		var distance := (reach * 0.5) if inside else (reach + 10.0 + float(index))
		_pool.set_position(index, origin + Vector3(distance, 0.0, 0.0))


func _indices_in(snapshot: Snapshot) -> PackedInt32Array:
	var out := PackedInt32Array()
	for record: Array in snapshot.npcs:
		out.append(int(record[0]))
	return out


# ---------------------------------------------------------------------------
# The guard against vacuous success comes first.
# ---------------------------------------------------------------------------


## **EVERY ASSERTION BELOW IS TRUE OF A BUILDER THAT SENDS NO NPC AT ALL**, which
## is precisely what this one did until US-0030 — for two milestones, with three
## acceptance criteria unticked and nothing red. The scenario must contain NPCs on
## both sides of the radius, and the near ones must arrive.
func test_the_scenario_has_npcs_on_both_sides_and_the_near_ones_arrive() -> void:
	var here := Vector3(20.0, 0.0, 20.0)
	_player_at(ALICE, here)
	_straddle_the_radius(here)
	var reach: float = Tuning.net.npc_cull_radius
	var near := 0
	var far := 0
	for index: int in CROWD:
		var at := _pool.position_of(index)
		if Vector2(at.x - here.x, at.z - here.z).length() <= reach:
			near += 1
		else:
			far += 1
	assert_gt(near, 0, "no NPC is inside the radius, so 'near ones are sent' is vacuous")
	assert_gt(far, 0, "no NPC is outside the radius, so 'far ones are culled' is vacuous")

	var snapshot := _builder.build_for(ALICE)
	assert_eq(snapshot.npcs.size(), near, "the builder did not send the NPCs that are in range")


# ---------------------------------------------------------------------------
# US-0030's three culling criteria.
# ---------------------------------------------------------------------------


## `TUN-NET-NPC-CULL-RADIUS`, read rather than written down: a literal 70.0 stops
## satisfying the criterion the first time the radius is retuned, and nothing
## would say so. Same reason `SpatialHash` reads its cell size.
func test_nothing_beyond_the_cull_radius_reaches_the_client() -> void:
	var here := Vector3(20.0, 0.0, 20.0)
	_player_at(ALICE, here)
	_straddle_the_radius(here)
	var reach: float = Tuning.net.npc_cull_radius
	var snapshot := _builder.build_for(ALICE)
	assert_gt(snapshot.npcs.size(), 0, "nothing was sent at all")
	for record: Array in snapshot.npcs:
		var at := record[1] as Vector3
		var distance := Vector2(at.x - here.x, at.z - here.z).length()
		assert_lte(
			distance,
			reach,
			"an NPC %.1f m away was sent to a client whose radius is %.1f" % [distance, reach]
		)


## **THE CULL IS A DISTANCE, NOT A VIEW.** Turning the observer through 180° must
## change nothing — otherwise an NPC pops into existence when a player turns their
## head, and a player can infer from the popping that they have just been handed a
## fresh piece of the district. Facing is a fact about the player; the district is
## not.
func test_culling_is_positional_and_not_visual() -> void:
	var here := Vector3(20.0, 0.0, 20.0)
	_player_at(ALICE, here)
	_straddle_the_radius(here)
	var looking_east := _indices_in(_builder.build_for(ALICE))
	_host.context_for(ALICE).yaw = PI
	var looking_west := _indices_in(_builder.build_for(ALICE))
	assert_gt(looking_east.size(), 0, "nothing was sent, so turning round proves nothing")
	assert_eq(
		Array(looking_east),
		Array(looking_west),
		"the set of NPCs changed when the observer turned round — the cull is visual"
	)


## **PER OBSERVER, WHICH IS THE WHOLE REASON THIS IS NOT A BROADCAST.** Two
## players standing apart must be told about different crowds; if they are not,
## the per-client loop is costing six times the work for one answer.
func test_two_players_standing_apart_are_told_about_different_crowds() -> void:
	var here := Vector3(20.0, 0.0, 20.0)
	_player_at(ALICE, here)
	_straddle_the_radius(here)
	var reach: float = Tuning.net.npc_cull_radius
	_player_at(BOB, here + Vector3(reach * 2.0, 0.0, 0.0))
	var alice := Array(_indices_in(_builder.build_for(ALICE)))
	var bob := Array(_indices_in(_builder.build_for(BOB)))
	assert_gt(alice.size(), 0, "the near observer was sent nothing")
	assert_ne(alice, bob, "both observers were told about the same crowd from different places")


## **THE INDEX IS THE POOL'S OWN.** A client that received "the third NPC near me"
## could not tell the same NPC apart between two ticks, and interpolating a crowd
## is exactly the act of telling one apart between two ticks. Culling reorders
## nothing and renumbers nothing.
func test_the_index_survives_culling_so_a_client_can_follow_one_npc() -> void:
	var here := Vector3(20.0, 0.0, 20.0)
	_player_at(ALICE, here)
	_straddle_the_radius(here)
	var before := _indices_in(_builder.build_for(ALICE))
	assert_gt(before.size(), 1, "one NPC cannot demonstrate that indices are preserved")
	# Move the nearest NPC further out, still inside the radius. Its index must be
	# the same number in the next snapshot, not its new place in the ordering.
	var moved: int = before[0]
	var reach: float = Tuning.net.npc_cull_radius
	_pool.set_position(moved, here + Vector3(reach * 0.9, 0.0, 0.0))
	var after := _indices_in(_builder.build_for(ALICE))
	assert_true(Array(after).has(moved), "an NPC that only moved was renumbered or dropped")
	assert_eq(Array(before), Array(after), "culling changed the set when nobody crossed the line")


## An NPC exactly on the line is **inside**. Stated because the two sides of a
## boundary are decided by an inequality nobody reads twice, and a client and a
## server disagreeing about one entity is a bug that surfaces as flicker.
##
## **SAMPLED OVER A WHOLE STRIDE, BECAUSE "SENT" AND "SENT THIS TICK" STOPPED
## MEANING THE SAME THING.** The cull radius is past `TUN-NET-NPC-RATE-LOD-RADIUS`,
## so an NPC on the boundary is in the slowed band and appears on one tick in
## `stride`. This test asserted a single tick and went red the moment rate LOD
## landed — correctly: it was measuring a rate and calling it a cull.
func test_the_boundary_itself_is_inside() -> void:
	var here := Vector3(20.0, 0.0, 20.0)
	_player_at(ALICE, here)
	var reach: float = Tuning.net.npc_cull_radius
	for index: int in CROWD:
		_pool.set_position(index, here + Vector3(reach, 0.0, 0.0))
	var ever := {}
	for tick: int in _builder.rate_lod_stride():
		_ctx.tick = tick
		for index: int in _indices_in(_builder.build_for(ALICE)):
			ever[index] = true
	assert_eq(ever.size(), CROWD, "an NPC at exactly the cull radius was never sent at all")


## The builder must survive a match with no crowd at all — the integration harness
## has none, and neither does any M2 test. A `null` pool is the ordinary case for
## every one of them, not an error.
func test_a_match_with_no_crowd_still_builds() -> void:
	_ctx.crowd = null
	_player_at(ALICE, Vector3(20.0, 0.0, 20.0))
	var snapshot := _builder.build_for(ALICE)
	assert_not_null(snapshot, "a crowdless match failed to build a snapshot")
	assert_eq(snapshot.npcs.size(), 0, "NPCs arrived from a pool that does not exist")
