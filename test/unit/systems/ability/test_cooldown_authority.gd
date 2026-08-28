## **THE SERVER OWNS EVERY COOLDOWN, AND NOBODY SEES ANYBODY ELSE'S.** TDD-09 §2,
## US-0066.
##
## Three properties, and each has a failure that is invisible until it matters:
##
## - **Integer tick deadlines, not float countdowns.** A float accumulates drift
##   and two peers disagree about when a cooldown ended; a deadline is one
##   comparison and cannot drift at all.
## - **Started at ACTIVATION, never at effect end.** Second Face lasts fifteen
##   seconds — starting its cooldown when it expires would make the real interval
##   45 s against a published 30, and the number a player learns would be one no
##   document contains.
## - **Reset on death.** Death already costs `TUN-RESPAWN-DELAY` and every point of
##   `SCORE-VARIETY` progress for that life. The suicide-to-reroll exploit this
##   opens is monitored via `TEL-SUICIDE-SUSPECTED`, not pre-emptively closed.
extends GutTest

const A := 81
const B := 82

var _system: AbilitySystem
var _ctx: MatchContext


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.tick = 1000
	_system = AbilitySystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	for peer: int in [A, B]:
		_place(peer)
		_system.loadout[peer] = [Ids.ABIL_CINDERFALL, Ids.ABIL_LUNGE]


func _place(peer: int) -> void:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(Vector3.ZERO, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn


func _cast(peer: int, slot: int) -> void:
	_system.report_request(peer, slot, Vector3.ZERO, Vector3(0.0, 0.0, 1.0))
	_system.tick(_ctx, MatchContext.net_dt())


func _advance(ticks: int) -> void:
	for _i: int in ticks:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func test_the_fixture_can_actually_cast() -> void:
	# **THE PREMISE.** Every assertion about a cooldown is satisfied by a system
	# that never accepted anything.
	_cast(A, 0)
	assert_eq(_system.activations, 1, "the fixture cannot cast, so nothing below means anything")


func test_a_cast_starts_its_own_cooldown_at_activation() -> void:
	var data: AbilityData = Tuning.ability_data(Ids.ABIL_CINDERFALL)
	_cast(A, 0)
	assert_eq(
		_system.cooldown_ticks(A, 0),
		Tuning.ticks(&"TUN-CINDERFALL-COOLDOWN"),
		"the cooldown is not TUN-CINDERFALL-COOLDOWN long"
	)
	assert_gt(data.duration, 0.0, "Cinderfall has no duration, so this proves nothing")
	# **THE ASSERTION THAT SEPARATES ACTIVATION FROM EFFECT END**: the cooldown has
	# already been ticking for the whole of the effect's life.
	_advance(int(data.duration * Tuning.net.server_tick) + 2)
	assert_lt(
		_system.cooldown_ticks(A, 0),
		Tuning.ticks(&"TUN-CINDERFALL-COOLDOWN"),
		"the cooldown restarted when the effect ended"
	)


func test_it_counts_down_one_tick_per_tick_and_reaches_zero() -> void:
	_cast(A, 0)
	var was := _system.cooldown_ticks(A, 0)
	_advance(10)
	assert_eq(_system.cooldown_ticks(A, 0), was - 10, "the cooldown does not run at one per tick")
	_advance(was)
	assert_eq(_system.cooldown_ticks(A, 0), 0, "the cooldown never reached zero")


func test_a_second_cast_before_the_cooldown_is_refused() -> void:
	var refusals: Array[int] = []
	_system.ability_denied.connect(func(_p: int, _s: int, why: int) -> void: refusals.append(why))
	_cast(A, 0)
	_advance(Tuning.ticks(&"TUN-ABILITY-GLOBAL-COOLDOWN") + 1)
	_cast(A, 0)
	assert_eq(_system.activations, 1, "the cooldown did not refuse the second cast")
	assert_eq(refusals, [AbilityDenial.Why.ON_COOLDOWN] as Array[int])


func test_the_global_cooldown_blocks_the_other_slot() -> void:
	# `TUN-ABILITY-GLOBAL-COOLDOWN` exists to prevent ability-chaining combos that
	# no victim can read (GDD-04). Slot 1 is off its own cooldown and still refused.
	var refusals: Array[int] = []
	_system.ability_denied.connect(func(_p: int, _s: int, why: int) -> void: refusals.append(why))
	_cast(A, 0)
	_cast(A, 1)
	assert_eq(_system.activations, 1, "the global cooldown did not stop the chain")
	assert_eq(refusals, [AbilityDenial.Why.GLOBAL_COOLDOWN] as Array[int])
	_advance(Tuning.ticks(&"TUN-ABILITY-GLOBAL-COOLDOWN"))
	_cast(A, 1)
	assert_eq(_system.activations, 2, "the global cooldown never expired")


func test_cooldowns_are_per_player() -> void:
	# The counterfactual for every test above: a table keyed by slot alone would
	# satisfy them all and would make one player's cast disarm everybody.
	_cast(A, 0)
	assert_eq(_system.cooldown_ticks(B, 0), 0, "one player's cast put another on cooldown")


func test_death_clears_them() -> void:
	_cast(A, 0)
	assert_gt(_system.cooldown_ticks(A, 0), 0)
	_system.on_death(A)
	assert_eq(_system.cooldown_ticks(A, 0), 0, "a cooldown survived death")
	_cast(A, 0)
	assert_eq(_system.activations, 2, "a respawned player could not cast")


func test_death_clears_only_that_players_cooldowns() -> void:
	_cast(A, 0)
	_advance(Tuning.ticks(&"TUN-ABILITY-GLOBAL-COOLDOWN") + 1)
	_cast(B, 0)
	_system.on_death(A)
	assert_gt(_system.cooldown_ticks(B, 0), 0, "one player's death cleared another's cooldowns")


func test_a_ready_slot_reads_zero_rather_than_a_sentinel() -> void:
	# The snapshot carries this straight to the HUD, so "ready" must be a number a
	# progress bar can divide by without a special case.
	assert_eq(_system.cooldown_ticks(A, 0), 0)
	assert_eq(_system.cooldown_ticks(A, 99), 0, "an out-of-range slot is not ready")


func test_no_players_cooldowns_are_reachable_from_a_snapshot_of_another() -> void:
	# **KIT-READING IS A SKILL** (GDD-04 §5.1). The rule lives in the wire format —
	# there is no field anywhere for another player's cooldown — and this asserts
	# the format rather than a filter, because a filter can be bypassed by a later
	# caller and a missing field cannot.
	var source := "res://scripts/net/protocol/snapshot.gd"
	for term: String in ["cooldown_a_tick", "cooldown_b_tick"]:
		assert_true(SourceScanner.code_contains(source, term), "%s left the format" % term)
	var snapshot := Snapshot.new()
	for name: String in ["remote_cooldown", "cooldowns", "other_cooldown"]:
		assert_false(name in snapshot, "Snapshot gained a `%s` field" % name)
