## **THE KILL-BLOCK, NOW A SWITCH THAT IS OFF.** GDD-04 §3.1, TDD-10 §3, US-0067,
## ADR-0023.
##
## Until 2026-09-25 this block, applied to the caster too, *was* the ability: *"without
## it, the dominant play would be 'cloud, then kill inside it'."* **In the reference
## that is exactly the dominant play**, and the owner took the reference's
## (ADR-0023). `TUN-CINDERFALL-BLOCKS-KILL` is false in the shipped profile,
## neutralised rather than removed, so this file checks both halves: the shipped
## cloud forbids nothing, and **with the switch back on the block still covers the
## caster**, so restoring the number restores the rule in one edit. The switch is
## turned on in `before_each` for that half, and `after_each` puts it back.
extends GutTest

const CASTER := 71
const VICTIM := 72

var _ctx: MatchContext
var _system: AbilitySystem
var _shipped_blocks_kill: bool


func before_each() -> void:
	_shipped_blocks_kill = _data().blocks_kill
	_data().blocks_kill = true
	_ctx = MatchContext.new()
	_ctx.tick = 300
	_system = AbilitySystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	for peer: int in [CASTER, VICTIM]:
		_place(peer)
	_system.loadout[CASTER] = [Ids.ABIL_CINDERFALL, Ids.ABIL_LUNGE]


func after_each() -> void:
	_data().blocks_kill = _shipped_blocks_kill


func _place(peer: int) -> void:
	var pawn := PawnContext.new()
	pawn.peer_id = peer
	pawn.reset_for_spawn(Vector3.ZERO, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[peer] = pawn


func _data() -> AbilityData:
	return Tuning.ability_data(Ids.ABIL_CINDERFALL)


func _advance(ticks: int) -> void:
	for _i: int in ticks:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


## Throw at the caster's own feet and let the pot land.
func _throw_and_land() -> void:
	_system.report_request(CASTER, 0, Vector3.ZERO, Vector3.ZERO)
	_system.tick(_ctx, MatchContext.net_dt())
	_advance(Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME") + 1)


func test_the_cast_is_accepted_at_all() -> void:
	# **THE PREMISE.** Every assertion below about a cloud is satisfied by a system
	# that refused the request.
	_throw_and_land()
	assert_eq(_system.activations, 1, "the fixture could not cast Cinderfall")
	assert_eq(_ctx.cinderfall.count_at(_ctx.tick), 1, "no cloud was placed")


func test_the_shipped_cloud_forbids_no_kill() -> void:
	# ADR-0023: the caster, and everybody else, may kill inside it.
	assert_false(_shipped_blocks_kill, "TUN-CINDERFALL-BLOCKS-KILL is not the shipped false")
	_data().blocks_kill = _shipped_blocks_kill
	_throw_and_land()
	assert_false(
		_ctx.cinderfall.contains_at(Vector3.ZERO, _ctx.tick),
		"the shipped cloud still forbids a kill at the caster's feet"
	)


func test_with_the_switch_on_a_kill_cannot_be_initiated_inside_the_cloud() -> void:
	_throw_and_land()
	assert_true(
		_ctx.cinderfall.contains_at(Vector3.ZERO, _ctx.tick),
		"the caster's own position is not inside the cloud they dropped at their feet"
	)


func test_the_caster_is_not_exempt() -> void:
	# The whole story. `contains_at` takes a point and knows nothing about who is
	# standing on it, which is what makes the exemption impossible to write by
	# accident — asserted here so that adding a caster argument later is a
	# deliberate act that reads this file first.
	_throw_and_land()
	for who: Vector3 in [Vector3.ZERO, Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, -3.0)]:
		assert_true(_ctx.cinderfall.contains_at(who, _ctx.tick), "%s escaped the block" % who)


func test_the_block_stops_at_the_radius() -> void:
	# The counterfactual: a cloud that blocked everywhere would satisfy every
	# assertion above and would end the match.
	_throw_and_land()
	var beyond := _data().radius + 1.0
	assert_false(
		_ctx.cinderfall.contains_at(Vector3(beyond, 0.0, 0.0), _ctx.tick),
		"the cloud blocks kills outside TUN-CINDERFALL-RADIUS"
	)


func test_the_radius_is_at_least_twice_the_kill_range() -> void:
	# Invariant 12, restated beside the cloud it measures: since ADR-0023 the reason
	# is that the cloud must reach somebody standing at kill range from its caster.
	assert_gte(_data().radius, 2.0 * Tuning.combat.kill_range)


func test_the_block_ends_with_the_cloud() -> void:
	_throw_and_land()
	_advance(Tuning.ticks(&"TUN-CINDERFALL-DURATION") + 1)
	assert_false(
		_ctx.cinderfall.contains_at(Vector3.ZERO, _ctx.tick),
		"the cloud still forbids kills after TUN-CINDERFALL-DURATION"
	)


## **THE CLOUD BURSTS ON THE CASTER, HOWEVER FAR THEY AIMED.** Amended 2026-09-03
## (ADR-0013): `TUN-CINDERFALL-THROW-RANGE` is **0.0**, because the reference
## deploys this ability at the player's own feet and only its *sequel* added a
## throw. `AbilityRules.aim` clamps the requested distance to the ability's reach,
## so a client aiming 40 m — which `InputSender` does on every cast, deliberately,
## so the server's clamp decides — still lands it underfoot.
##
## **AIMED LONG, NOT AT ZERO**, which is the half that matters: a fixture throwing
## `Vector3.ZERO` proves the aim is unusable rather than that it is clamped, and
## `AbilityRules._usable` falls back to the caster's facing for exactly that input.
func test_the_cloud_bursts_on_the_caster_however_far_they_aimed() -> void:
	_system.report_request(CASTER, 0, Vector3.ZERO, Vector3(0.0, 0.0, 40.0))
	_system.tick(_ctx, MatchContext.net_dt())
	_advance(Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME") + 1)
	assert_eq(
		_ctx.cinderfall.count_at(_ctx.tick), 1, "the long aim was refused rather than clamped"
	)
	assert_true(
		_ctx.cinderfall.catches(Vector3.ZERO, -1, _ctx.tick),
		"the caster is outside their own cloud, so it was thrown rather than dropped"
	)
	# The far end of where a throw used to reach must now be clear, or the clamp
	# moved the centre without removing the throw.
	assert_false(
		_ctx.cinderfall.catches(Vector3(0.0, 0.0, 8.0), -1, _ctx.tick),
		"the cloud still covers the old throw range, so it did not land on the caster"
	)


## **AND THE REACH IS ZERO RATHER THAN THE FIELD BEING IGNORED.**
## `AbilityRules.reach_of` falls through to `distance` when `throw_range` is zero,
## and Cinderfall populates neither — so this asserts the fall-through lands on
## nothing rather than on Lunge's 6 m by accident.
func test_cinderfall_reaches_nowhere() -> void:
	assert_eq(AbilityRules.reach_of(_data()), 0.0, "Cinderfall can still be aimed away from you")
	assert_eq(_data().throw_range, 0.0, "TUN-CINDERFALL-THROW-RANGE is not the shipped 0.0")
