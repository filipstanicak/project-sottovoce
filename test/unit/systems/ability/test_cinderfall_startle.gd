## **THE CLOUD HIDES YOU AND PAINTS AN ARROW AT YOUR POSITION.** GDD-04 §3.1,
## TUNABLES §8.1, US-0067.
##
## `TUN-CINDERFALL-STARTLE-RADIUS` 9.0 m is the ability's **honest cost**, and the
## GDD says so in as many words: *"the cloud hides you and simultaneously paints a
## fleeing-crowd arrow at your position for everyone in the district."* Design law
## 2 — the crowd is a mechanic, not a backdrop — is what makes that a real price
## rather than a flourish: a startle wave is readable at 30 m, so the counterplay
## is to walk toward the people running away.
##
## **THE SYSTEM RAISES IT, NOT THE EFFECT.** `startle_radius` is `AbilityData`'s and
## Lunge carries one too, so it sits beside the suspicion cost in the pipeline.
## An effect reaching `ctx.crowd` would put crowd knowledge in
## `scripts/systems/ability/` to express a rule two abilities share.
extends GutTest

const CASTER := 51

var _ctx: MatchContext
var _system: AbilitySystem
var _waves: Array = []


func before_each() -> void:
	_waves = []
	_ctx = MatchContext.new()
	_ctx.tick = 500
	_system = AbilitySystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	var pawn := PawnContext.new()
	pawn.peer_id = CASTER
	pawn.reset_for_spawn(Vector3.ZERO, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[CASTER] = pawn
	_system.loadout[CASTER] = [Ids.ABIL_CINDERFALL, Ids.ABIL_LUNGE]
	_system.ability_startled.connect(
		func(at: Vector3, radius: float) -> void: _waves.append([at, radius])
	)


func _advance(ticks: int) -> void:
	for _i: int in ticks:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


func _throw() -> void:
	_system.report_request(CASTER, 0, Vector3.ZERO, Vector3.ZERO)
	_system.tick(_ctx, MatchContext.net_dt())


func test_a_landed_pot_scares_the_crowd() -> void:
	_throw()
	_advance(Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME") + 1)
	assert_eq(_waves.size(), 1, "the burst startled nobody")


func test_it_uses_the_abilitys_own_radius_and_not_the_violence_default() -> void:
	# `CrowdDirector.startle_at` falls back to `TUN-CROWD-STARTLE-RADIUS-VIOLENCE`
	# 12 m when handed a non-positive radius, so passing the wrong one is silent —
	# a Cinderfall would scare a third more crowd than the GDD prices it at.
	_throw()
	_advance(Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME") + 1)
	var expected: float = Tuning.ability_data(Ids.ABIL_CINDERFALL).startle_radius
	assert_almost_eq(float(_waves[0][1]), expected, 0.001)
	assert_ne(expected, Tuning.crowd.startle_radius_violence, "the two radii are the same value")


func test_it_scares_them_at_the_burst_and_not_at_the_press() -> void:
	# **THE THROW AND THE CRACK ARE SEPARATE TELL CHANNELS** (GDD-04 §3.1): the
	# 0.45 s underarm animation is the wind-up, the crack and the scattering crowd
	# are the impact. A wave at the press would tell the district where somebody was
	# before the pot had left their hand.
	_throw()
	assert_eq(_waves.size(), 0, "the crowd scattered during the wind-up")
	_advance(Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME") + 1)
	assert_eq(_waves.size(), 1)


func test_the_wave_is_centred_on_the_cloud_rather_than_on_the_caster() -> void:
	# Thrown eight metres ahead, the arrow points at the **pot**. That is the
	# aggressive use GDD-04 §3.1 names — deny a chaser's line — and it is also the
	# only thing that makes the throw range worth having: a wave that always fired
	# at the caster's feet would announce them however far they threw.
	_system.report_request(CASTER, 0, Vector3.ZERO, Vector3(0.0, 0.0, 40.0))
	_system.tick(_ctx, MatchContext.net_dt())
	_advance(Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME") + 1)
	var reach: float = Tuning.ability_data(Ids.ABIL_CINDERFALL).throw_range
	assert_almost_eq((_waves[0][0] as Vector3).z, reach, 0.001)


func test_a_cancelled_cast_scares_nobody() -> void:
	_throw()
	_system.on_death(CASTER)
	_advance(Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME") + 2)
	assert_eq(_waves.size(), 0, "a pot that was never thrown still scattered the crowd")


func test_an_ability_with_no_startle_radius_raises_nothing() -> void:
	# The counterfactual: a pipeline that startled on every cast would satisfy every
	# assertion above and would make Second Face as loud as an explosion.
	_system.loadout[CASTER] = [Ids.ABIL_SECONDFACE]
	var data: AbilityData = Tuning.ability_data(Ids.ABIL_SECONDFACE)
	assert_eq(data.startle_radius, 0.0, "Second Face gained a startle radius; rewrite this test")
	_throw()
	_advance(Tuning.ticks(&"TUN-SECONDFACE-CAST-TIME") + 2)
	assert_eq(_system.activations, 1, "the fixture could not cast Second Face")
	assert_eq(_waves.size(), 0, "an ability with no startle radius scattered the crowd")
