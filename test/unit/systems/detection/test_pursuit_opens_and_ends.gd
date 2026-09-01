## **A CHASE OPENS ON CARELESSNESS AND ENDS BY NOT LOOKING.** ADR-0014, US-0097.
##
## `PursuitBoard` proves the timer; this proves the two conditions the world
## supplies — **what opens a chase** and **what counts as sight** — driven through
## the real `DetectionSystem` pass, because both are computed from the same pair
## loop that already answers them for the Compass.
extends GutTest

const PURSUER := 41
const PREY := 42
const BYSTANDER := 43
const STRANGER := 44

var _system: DetectionSystem
var _ctx: MatchContext
var _escapes: Array = []


func before_each() -> void:
	_system = DetectionSystem.new()
	add_child_autofree(_system)
	_ctx = MatchContext.new()
	_ctx.tick = 100
	_system.setup(_ctx)
	_escapes = []
	_system.chase.escaped.connect(func(h: int, p: int, c: bool) -> void: _escapes.append([h, p, c]))
	# **FOUR PLAYERS, BECAUSE A THREE-PLAYER RING HAS NO STRANGERS.** The corpus has
	# recorded this twice already; a cycle of three makes everybody somebody's
	# hunter and somebody's prey.
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


## The pursuer `metres` up +Z from the prey, at `tier`, facing back down -Z at them.
func _pursuer_at(metres: float, tier: int, facing_them: bool = true) -> void:
	var them := _ctx.pawn_contexts[PURSUER] as PawnContext
	them.position = Vector3(0.0, 0.0, metres)
	them.tier = tier
	them.suspicion = 0.0 if tier == SuspicionMath.Tier.ANONYMOUS else Tuning.suspicion.tier_noticed
	# This game's yaw 0 faces +Z, so looking back at the origin is a half turn.
	them.yaw = PI if facing_them else 0.0


func _run(ticks: int = 1) -> void:
	for _i: int in ticks:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func test_carelessness_inside_the_warn_radius_opens_a_chase() -> void:
	# **THE PREMISE, AND IT IS ALSO §1'S WHOLE CLAIM**: no new trigger. The chase
	# opens on exactly the condition US-0059 already computes, which is what makes
	# the prey warning load-bearing rather than a piece of feedback.
	_pursuer_at(10.0, SuspicionMath.Tier.NOTICED)
	_run()
	assert_true(_ctx.pursuit.is_chasing(PURSUER), "a careless pursuer inside 15 m opened no chase")
	assert_eq(_ctx.pursuit.prey_of(PURSUER), PREY)


func test_an_anonymous_pursuer_never_opens_one_at_any_range() -> void:
	# The counterfactual — and **it cannot falsify the tier gate itself, which is
	# US-0059's finding arriving a second time.** Planting `careless` out of the
	# opening condition leaves this green, because `_resolve_pair`'s first rung
	# already drops every Anonymous subject and `_consider_warning` is never
	# reached. Invariant 8 pins `TUN-COMPASS-WARN-MIN-TIER` equal to
	# `TUN-SUSPICION-TIER-NOTICED`, so no profile `Tuning.adopt()` accepts can
	# separate the two.
	#
	# What this therefore asserts is the **property** — a competent hunter never
	# loses a contract — rather than the line that delivers it. The gate is kept
	# anyway for the reason US-0059 kept its own: the rung above it is an early-out
	# **for cost**, and resting a rule's correctness on a performance optimisation
	# means widening the ladder later would start taking contracts away from
	# Anonymous hunters with nothing failing.
	for metres: float in [1.0, 5.0, 14.0]:
		_pursuer_at(metres, SuspicionMath.Tier.ANONYMOUS)
		_run()
		assert_false(_ctx.pursuit.is_chasing(PURSUER), "a chase opened at %.0f m" % metres)


func test_a_careless_pursuer_outside_the_radius_opens_none() -> void:
	_pursuer_at(Tuning.compass.warn_radius + 5.0, SuspicionMath.Tier.NOTICED)
	_run()
	assert_false(_ctx.pursuit.is_chasing(PURSUER))


func test_nobody_else_is_chasing() -> void:
	# One incoming edge per player: a Hamiltonian cycle cannot produce two pursuers,
	# and a chase opened against a bystander would be a rule reading the wrong pair.
	_pursuer_at(10.0, SuspicionMath.Tier.NOTICED)
	_run()
	assert_eq(_ctx.pursuit.count(), 1, "more than one chase opened from one careless pursuer")


func test_looking_at_the_prey_holds_the_chase_open() -> void:
	# **THE REFRESH CONDITION IS SIGHT, NOT PROXIMITY.** The pursuer stays inside
	# the warn radius throughout, so a rule that refreshed on the opening condition
	# would pass this and fail the next one.
	_pursuer_at(10.0, SuspicionMath.Tier.NOTICED)
	_run(Tuning.ticks(&"TUN-PURSUIT-DURATION") + 20)
	assert_eq(_escapes.size(), 0, "a pursuer watching their prey lost the contract")
	assert_true(_ctx.pursuit.is_chasing(PURSUER))


func test_turning_away_drains_it_and_the_contract_is_lost() -> void:
	_pursuer_at(10.0, SuspicionMath.Tier.NOTICED)
	_run()
	_pursuer_at(10.0, SuspicionMath.Tier.NOTICED, false)
	_run(Tuning.ticks(&"TUN-PURSUIT-DURATION") + 2)
	assert_eq(_escapes.size(), 1, "a pursuer who never looked kept the contract")
	assert_eq(int(_escapes[0][0]), PURSUER)
	assert_eq(int(_escapes[0][1]), PREY)


func test_the_close_call_is_measured_at_the_last_sighting() -> void:
	# By definition the hunter has not seen their prey for the whole window, so the
	# distance when the bar empties is one nobody observed. What the bonus prices is
	# escaping **under pressure**.
	_pursuer_at(2.0, SuspicionMath.Tier.NOTICED)
	_run(2)
	_pursuer_at(2.0, SuspicionMath.Tier.NOTICED, false)
	_run(Tuning.ticks(&"TUN-PURSUIT-DURATION") + 2)
	assert_eq(_escapes.size(), 1)
	assert_true(bool(_escapes[0][2]), "an escape from two metres was not a close call")


func test_a_distant_escape_is_not_a_close_call() -> void:
	_pursuer_at(12.0, SuspicionMath.Tier.NOTICED)
	_run(2)
	_pursuer_at(12.0, SuspicionMath.Tier.NOTICED, false)
	_run(Tuning.ticks(&"TUN-PURSUIT-DURATION") + 2)
	assert_eq(_escapes.size(), 1)
	assert_false(bool(_escapes[0][2]), "an escape from twelve metres was a close call")


func test_a_chase_survives_the_hunter_calming_down() -> void:
	# §6: once you have been seen you must close or lose them. A hunter who could
	# cancel a chase by standing still would have alerted their prey for free.
	_pursuer_at(10.0, SuspicionMath.Tier.NOTICED)
	_run()
	_pursuer_at(10.0, SuspicionMath.Tier.ANONYMOUS)
	_run(3)
	assert_true(_ctx.pursuit.is_chasing(PURSUER), "the chase ended because the hunter calmed down")
