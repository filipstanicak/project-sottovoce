## **THE PREY WARNING FIRES FOR CARELESSNESS AND FOR NOTHING ELSE.** US-0059,
## GDD-03 §9.1.
##
## The two gates are a range and a tier, and the tier is the one the design leans
## on: **an Anonymous pursuer produces no warning at any distance**, which is what
## still leaves a competent hunter invisible after ADR-0013 made the marker
## directional. That is the reference's rule as well as ours — its threat meter
## depletes only on high-profile action, and the marker appears only once it has.
##
## **THE VACUOUS-SUCCESS GUARD IS FIRST.** Every "no warning" assertion in this
## file is satisfied by a system that never warns anybody, so the first test
## proves the fixture can produce one at all.
extends GutTest

const PREY := 51
const PURSUER := 52
const BYSTANDER := 53
const STRANGER := 54

var _system: DetectionSystem
var _ctx: MatchContext
var _seen: Array = []


func before_each() -> void:
	_system = DetectionSystem.new()
	add_child_autofree(_system)
	_ctx = MatchContext.new()
	_system.setup(_ctx)
	_seen = []
	_system.prey_warned.connect(func(p: int, b: float, d: int) -> void: _seen.append([p, b, d]))
	# **FOUR PLAYERS, BECAUSE A THREE-PLAYER RING HAS NO STRANGERS.** In a cycle of
	# three everybody is somebody's hunter and somebody's prey, so "a nearby player
	# who is neither" cannot be constructed — the corpus already recorded this once,
	# against `test_detection_system.gd`, and the first version of this file walked
	# into it again and read one warning where it expected none.
	# PURSUER -> PREY -> BYSTANDER -> STRANGER -> PURSUER.
	_place(PREY, Vector3.ZERO)
	_place(PURSUER, Vector3(0.0, 0.0, 10.0))
	_place(BYSTANDER, Vector3(60.0, 0.0, 60.0))
	_place(STRANGER, Vector3(-60.0, 0.0, -60.0))
	_ctx.announced_contracts[PURSUER] = PREY
	_ctx.announced_contracts[PREY] = BYSTANDER
	_ctx.announced_contracts[BYSTANDER] = STRANGER
	_ctx.announced_contracts[STRANGER] = PURSUER


func _place(peer: int, at: Vector3) -> PawnContext:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(at, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn
	return pawn


## Put the pursuer at `metres` from the prey, on +Z, at `tier`.
func _pursuer_at(metres: float, tier: int) -> void:
	var them := _ctx.pawn_contexts[PURSUER] as PawnContext
	them.position = Vector3(0.0, 0.0, metres)
	them.tier = tier
	them.suspicion = 0.0 if tier == SuspicionMath.Tier.ANONYMOUS else Tuning.suspicion.tier_noticed


## How many warnings this player has received across the whole fixture.
##
## **COUNTED PER RECIPIENT RATHER THAN IN TOTAL**, because a four-player ring has
## three other live relationships and an assertion on `_seen.size()` would be
## about whichever of them happened to fire.
func _warnings_for(peer: int) -> int:
	var n := 0
	for row: Array in _seen:
		if int(row[0]) == peer:
			n += 1
	return n


func _resolve() -> void:
	_ctx.tick += 1
	_system.tick(_ctx, MatchContext.net_dt())


func test_a_noticed_pursuer_inside_the_radius_warns_the_prey() -> void:
	# The guard the rest of this file rests on.
	_pursuer_at(Tuning.compass.warn_radius - 1.0, SuspicionMath.Tier.NOTICED)
	_resolve()
	assert_eq(_seen.size(), 1, "a careless pursuer at 14 m produced no warning at all")


func test_an_anonymous_pursuer_warns_nobody_at_any_range() -> void:
	# **Swept rather than sampled**, because a single range cannot tell a tier gate
	# from a range gate that happens to be tighter than the sample.
	for metres: float in [0.5, 2.0, 5.0, 10.0, 14.9]:
		_pursuer_at(metres, SuspicionMath.Tier.ANONYMOUS)
		_resolve()
	assert_eq(_seen.size(), 0, "an Anonymous pursuer warned the prey — patience buys nothing")


func test_a_pursuer_outside_the_radius_warns_nobody() -> void:
	_pursuer_at(Tuning.compass.warn_radius + 0.5, SuspicionMath.Tier.EXPOSED)
	_resolve()
	assert_eq(_seen.size(), 0, "warned about a pursuer beyond TUN-COMPASS-WARN-RADIUS")


func test_the_warn_floor_and_the_early_out_are_the_same_condition() -> void:
	# **AND THIS FILE CANNOT TELL THEM APART, WHICH IS WORTH SAYING OUT LOUD.**
	# Invariant 8 pins `TUN-COMPASS-WARN-MIN-TIER` to `TUN-SUSPICION-TIER-NOTICED`,
	# so no profile `Tuning.adopt()` would accept can make the warn floor differ
	# from `_resolve_pair`'s Anonymous early-out. Planting `>= ANONYMOUS` into the
	# gate leaves every test in this file green — measured while falsifying, not
	# assumed — so what the sweep above really proves is the *ladder*.
	#
	# The gate is kept regardless (see `_consider_warning`), and this assertion is
	# the tripwire: the day invariant 8 changes, it goes red and somebody re-reads
	# both rules together instead of discovering the coupling from a playtest.
	var floor_tier := SuspicionMath.evaluate_tier(
		Tuning.compass.warn_min_tier, SuspicionMath.Tier.ANONYMOUS, Tuning.suspicion
	)
	assert_eq(
		floor_tier,
		SuspicionMath.Tier.NOTICED,
		"TUN-COMPASS-WARN-MIN-TIER no longer resolves to Noticed; the gate must follow it"
	)
	assert_almost_eq(
		Tuning.compass.warn_min_tier,
		Tuning.suspicion.tier_noticed,
		0.001,
		"the warn threshold and the Noticed threshold have drifted apart"
	)


func test_it_warns_the_prey_and_never_the_pursuer() -> void:
	# Getting `hunted_by`'s direction backwards would tell a hunter that their own
	# victim was near — a free confirmation that the Compass is pointing at a
	# player rather than at a clone.
	_pursuer_at(8.0, SuspicionMath.Tier.EXPOSED)
	_resolve()
	assert_eq(_seen.size(), 1, "no warning to check the recipient of")
	assert_eq(int(_seen[0][0]), PREY, "the warning went to the wrong player")


func test_a_nearby_stranger_warns_nobody() -> void:
	# **PROXIMITY IS NOT THE GATE; THE RELATIONSHIP IS.** A player standing on top
	# of you, at the loudest tier in the game, produces no warning at all unless
	# they are the one hunting you — which is what stops the warning degenerating
	# into a radar for everybody who is currently sprinting.
	var stranger := _ctx.pawn_contexts[STRANGER] as PawnContext
	stranger.position = Vector3(1.0, 0.0, 1.0)
	stranger.tier = SuspicionMath.Tier.EXPOSED
	_pursuer_at(8.0, SuspicionMath.Tier.ANONYMOUS)
	_resolve()
	assert_eq(_warnings_for(PREY), 0, "a nearby stranger warned the prey")


func test_the_bearing_points_at_the_pursuer_within_the_wobble() -> void:
	# The marker's whole job is to say which way to run. The wobble is bounded by
	# `TUN-COMPASS-CONE-WOBBLE` and must not exceed it — an unbounded lie would be
	# noise, which design law 6 refuses.
	_pursuer_at(9.0, SuspicionMath.Tier.NOTICED)
	_resolve()
	assert_eq(_seen.size(), 1, "no warning to read a bearing from")
	var truth := CompassMath.bearing_to(Vector3.ZERO, Vector3(0.0, 0.0, 9.0))
	var error := absf(CompassMath.angle_between(truth, float(_seen[0][1])))
	assert_lte(
		error,
		deg_to_rad(Tuning.compass.cone_wobble) + 0.001,
		"the warning bearing drifts further than TUN-COMPASS-CONE-WOBBLE allows"
	)


func test_the_distance_is_a_bucket_and_never_the_metres() -> void:
	# GDD-03 §8.5's rule, applied to the other end of the same ring: *nearer*,
	# never *how far*.
	_pursuer_at(9.3, SuspicionMath.Tier.NOTICED)
	_resolve()
	assert_eq(_seen.size(), 1, "no warning to read a distance from")
	assert_eq(int(_seen[0][2]), Quantise.distance_to_bucket(9.3), "the bucket is not the bucket")
	assert_ne(float(_seen[0][2]), 9.3, "the exact metres reached the payload")


func test_a_held_chase_does_not_strobe() -> void:
	# Three seconds of an unbroken approach. Warning every tick would be ninety
	# stings, which is the failure `TUN-COMPASS-WARN-COOLDOWN` exists to prevent.
	for _i: int in int(round(3.0 * Tuning.net.server_tick)):
		_pursuer_at(6.0, SuspicionMath.Tier.EXPOSED)
		_resolve()
	assert_between(_seen.size(), 1, 3, "%d warnings in three seconds" % _seen.size())


func test_nothing_is_warned_about_itself() -> void:
	# A cycle has no fixed point, but a pass that compared a peer with itself would
	# find range 0 and the player's own tier — and warn everybody, always.
	_pursuer_at(6.0, SuspicionMath.Tier.EXPOSED)
	var prey := _ctx.pawn_contexts[PREY] as PawnContext
	prey.tier = SuspicionMath.Tier.EXPOSED
	_resolve()
	for row: Array in _seen:
		assert_ne(int(row[0]), PURSUER, "the pursuer was warned about themselves")
