## **`SYS-SUSPICION` DRIVES THE INTEGRATOR AGAINST THE REAL WORLD.** US-0052,
## TDD-07 §1–§2.
##
## `SuspicionMath` is pure and exhaustively tested by US-0051. What this file
## tests is everything *around* it: that the world is read from this tick's
## spatial hash rather than a physics query, that the value written to the wire is
## the one the integrator produced, that a tier change is announced once, and that
## a departed peer leaves nothing behind for whoever inherits their id.
##
## **THE SPATIAL HASH IS REAL, NOT A STUB.** The one thing that cannot be faked
## here is the crowd query — `TUN-SUSPICION-GAIN-OPEN` is the source that decides
## whether standing still is safe, and a fake answering 0.5 m forever would make
## every assertion below true of a system that never asked.
extends GutTest

const PEER := 4
const OTHER := 5
const ROOF_Y := 7.0

var _sys: SuspicionSystem
var _ctx: MatchContext
var _pawn: PawnContext
var _t: SuspicionTuning


func before_each() -> void:
	_t = Tuning.suspicion
	_sys = SuspicionSystem.new()
	add_child_autofree(_sys)
	_ctx = MatchContext.new()
	_ctx.crowd_hash.setup(AABB(Vector3(-10, -10, -10), Vector3(160, 40, 160)), 16)
	_pawn = _spawn(PEER, Vector3.ZERO)
	_crowd_at(PackedVector3Array())


func _spawn(peer: int, at: Vector3) -> PawnContext:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn
	return pawn


## Index the crowd exactly as `CrowdDirector` does at the top of the `crowd`
## stage, so what the system reads is a real query over real positions.
func _crowd_at(positions: PackedVector3Array) -> void:
	_ctx.crowd_hash.rebuild(positions, [], positions.size())


func _tick(times: int) -> void:
	for _i: int in times:
		_ctx.tick += 1
		_sys.tick(_ctx, MatchContext.net_dt())


func test_the_stage_is_after_the_crowd_and_before_detection() -> void:
	# **THE ORDERING THIS SYSTEM'S CORRECTNESS RESTS ON**, asserted against the
	# declaration rather than against the scene: a system in the tree that named a
	# different stage would run at the wrong moment with nothing to see.
	assert_eq(_sys.stage(), &"suspicion", "SYS-SUSPICION does not occupy the suspicion stage")
	var here := SystemOrder.position_of(&"suspicion")
	assert_gt(here, SystemOrder.position_of(&"crowd"), "suspicion runs before the crowd resolves")
	assert_lt(here, SystemOrder.position_of(&"detection"), "detection runs before suspicion")


func test_standing_alone_accrues_and_standing_in_a_crowd_does_not() -> void:
	# **THE MECHANIC THAT MAKES AN EMPTY PLAZA DANGEROUS**, end to end: the pawn is
	# doing nothing at all, and the only thing that changes is who is standing near
	# it.
	_tick(30)
	var alone := _pawn.suspicion
	assert_almost_eq(
		alone, _t.gain_open, 0.2, "a second alone did not cost TUN-SUSPICION-GAIN-OPEN"
	)

	_crowd_at(PackedVector3Array([Vector3(1.0, 0.0, 0.0)]))
	_tick(Tuning.ticks(&"TUN-SUSPICION-DECAY-DELAY") + 30)
	assert_lt(_pawn.suspicion, alone, "company did not stop the accrual")


func test_the_crowd_is_asked_through_the_shared_hash_and_not_a_physics_query() -> void:
	# US-0052's second criterion. The evidence is behavioural: an NPC that exists
	# **only** in the hash suppresses the alone gain, so the answer cannot have come
	# from anywhere else — there is no physics world in this test at all.
	_crowd_at(PackedVector3Array([Vector3(_t.open_radius - 0.1, 0.0, 0.0)]))
	_tick(30)
	assert_eq(_pawn.suspicion, 0.0, "a hash-only NPC did not suppress TUN-SUSPICION-GAIN-OPEN")
	assert_eq(_pawn.active_sources, SuspicionSources.NONE, "a sourceless tick listed a source")


func test_the_source_bitfield_reaches_the_pawn_beside_the_value() -> void:
	_pawn.state_id = PawnStateId.SPRINT
	_pawn.position = Vector3(0.0, ROOF_Y, 0.0)
	_tick(1)
	var bits := _pawn.active_sources
	for bit: int in [SuspicionSources.SPRINT, SuspicionSources.ROOF, SuspicionSources.OPEN]:
		assert_true((bits & bit) != 0, "bit %d was not published" % bit)
	assert_gt(_pawn.suspicion, 0.0, "the sources were published without the value they explain")


func test_a_tier_change_is_announced_once_and_carries_its_sources() -> void:
	watch_signals(_sys)
	_pawn.state_id = PawnStateId.SPRINT
	# Two seconds of sprinting alone: 31/s, so Noticed at ~1.0 s and Exposed at
	# ~2.3 s. One crossing inside the window, announced exactly once.
	_tick(45)
	assert_signal_emit_count(_sys, "tier_changed", 1, "a single crossing was not announced once")
	var payload: Array = get_signal_parameters(_sys, "tier_changed", 0)
	assert_eq(payload[0], PEER, "the announcement named the wrong peer")
	assert_eq(payload[1], SuspicionMath.Tier.NOTICED, "the announced tier is not the pawn's")
	assert_true(
		(int(payload[2]) & SuspicionSources.SPRINT) != 0,
		"the announcement did not carry the source that caused it"
	)
	assert_eq(_pawn.tier, SuspicionMath.Tier.NOTICED, "the pawn's tier disagrees with the event")


func test_an_impulse_lands_before_the_integrator_and_re_arms_the_delay() -> void:
	# A player standing in a crowd with the decay long since armed. The impulse must
	# be visible in full on the tick after it is owed — not partly refunded by the
	# decay that was already running.
	_crowd_at(PackedVector3Array([Vector3(1.0, 0.0, 0.0)]))
	_pawn.suspicion = 40.0
	_tick(Tuning.ticks(&"TUN-SUSPICION-DECAY-DELAY") + 5)
	var settled := _pawn.suspicion
	assert_lt(settled, 40.0, "decay never armed, so this proves nothing about re-arming")

	_sys.impulses.queue(PEER, _t.gain_npc_bump)
	_tick(1)
	assert_almost_eq(
		_pawn.suspicion, settled + _t.gain_npc_bump, 0.001, "the impulse was partly refunded"
	)
	# And the delay is re-armed: the next tick must not decay either.
	var after := _pawn.suspicion
	_tick(1)
	assert_eq(_pawn.suspicion, after, "decay resumed the tick after an impulse")


func test_a_bump_is_debounced_through_the_system() -> void:
	# The rule is `SuspicionImpulses`'; what this asserts is that the system hands it
	# `ctx.tick` and not a frame count or a wall clock.
	assert_true(_sys.report_npc_bump(PEER, _ctx), "the first bump was refused")
	assert_false(_sys.report_npc_bump(PEER, _ctx), "a second bump on the same tick landed")
	_ctx.tick += Tuning.ticks(&"TUN-SUSPICION-GAIN-NPC-BUMP-COOLDOWN")
	assert_true(_sys.report_npc_bump(PEER, _ctx), "a bump past the cooldown was refused")


func test_the_speed_read_is_horizontal_so_a_floor_snap_cannot_disable_stillness() -> void:
	# **THE SILENT ONE.** A grounded `CharacterBody3D` carries a small downward
	# velocity from its floor snap. Taken in three axes that is above
	# `TUN-PASV-STILLNESS-SPEED-CEILING` 0.15, so every standing player in the game
	# would lose the passive they equipped, permanently, with nothing to see.
	#
	# **THE TWO HALVES RUN SIDE BY SIDE, IN ONE PASS, AND THAT IS NOT TIDINESS.**
	# Run in sequence on one pawn this compares 42.00 against 37.20 and fails —
	# because `ticks_since_gain` survives the reset, so the second half decays for
	# the eighteen ticks the first spent arming the delay. 4.8 points is exactly
	# `TUN-SUSPICION-DECAY-BASE` over `TUN-SUSPICION-DECAY-DELAY`, and it reads like
	# a finding about the axis under test. It was the harness.
	_crowd_at(PackedVector3Array([Vector3(1.0, 0.0, 0.0)]))
	var still := _spawn(OTHER, Vector3(1.0, 0.0, 0.0))
	for pawn: PawnContext in [_pawn, still]:
		pawn.suspicion = 50.0
	_pawn.velocity = Vector3(0.0, -_t.stillness_speed_ceiling * 4.0, 0.0)
	still.velocity = Vector3.ZERO
	_tick(Tuning.ticks(&"TUN-SUSPICION-DECAY-DELAY") + 30)
	assert_lt(still.suspicion, 50.0, "neither pawn decayed, so the comparison is empty")
	assert_almost_eq(
		_pawn.suspicion,
		still.suspicion,
		0.001,
		"a vertical floor snap changed how a still player decays"
	)


func test_horizontal_motion_is_still_read_as_motion() -> void:
	# The other side of the same rule: reading *nothing* would satisfy the test
	# above just as well. Above `TUN-SUSPICION-DECAY-SPEED-CEILING`, decay stops.
	_crowd_at(PackedVector3Array([Vector3(1.0, 0.0, 0.0)]))
	_pawn.suspicion = 50.0
	_pawn.velocity = Vector3(_t.decay_speed_ceiling + 1.0, 0.0, 0.0)
	_tick(Tuning.ticks(&"TUN-SUSPICION-DECAY-DELAY") + 30)
	assert_eq(_pawn.suspicion, 50.0, "a pawn above the speed ceiling decayed")


func test_a_pawn_that_is_not_in_the_world_accrues_nothing() -> void:
	# A corpse on empty ground would otherwise accrue TUN-SUSPICION-GAIN-OPEN for
	# the whole respawn timer, and arrive back at Noticed for having been dead.
	for state: StringName in [PawnStateId.DEAD, PawnStateId.RESPAWNING]:
		_pawn.suspicion = 0.0
		_pawn.state_id = state
		_tick(30)
		assert_eq(_pawn.suspicion, 0.0, "a pawn in %s accrued suspicion" % state)


func test_a_departed_peer_leaves_nothing_for_whoever_inherits_the_id() -> void:
	# **ENET REUSES PEER IDS** — US-0037. The state is keyed by the context's
	# identity rather than by the id, so a rejoin cannot resume somebody else's
	# accrual even inside a single tick.
	_pawn.state_id = PawnStateId.SPRINT
	_tick(30)
	assert_gt(_pawn.suspicion, 0.0, "the departing player never accrued anything")
	_sys.impulses.queue(PEER, _t.gain_loud_ability)

	_ctx.pawn_contexts.erase(PEER)
	var reborn := _spawn(PEER, Vector3.ZERO)
	_tick(1)
	assert_lt(
		reborn.suspicion,
		_t.gain_loud_ability,
		"a rejoining peer inherited the previous holder's owed impulse"
	)


func test_two_players_are_judged_separately() -> void:
	# The pass is per pawn. A shared reading would make one player's sprint cost
	# their neighbour, which is the least debuggable failure this system could have.
	var other := _spawn(OTHER, Vector3(40.0, 0.0, 0.0))
	_crowd_at(PackedVector3Array([Vector3(40.5, 0.0, 0.0)]))
	_pawn.state_id = PawnStateId.SPRINT
	_tick(30)
	assert_gt(_pawn.suspicion, 0.0, "the sprinting player did not accrue")
	assert_eq(other.suspicion, 0.0, "a player standing in a crowd paid for somebody else's sprint")
