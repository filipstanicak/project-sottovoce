## **A CAST CLOUD BLOCKS SIGHT, THE LOCK AND `SCORE-FOCUS` AT ONCE.** GDD-04 §3.1,
## TUNABLES §8.1, US-0067.
##
## `TUN-CINDERFALL-BLOCKS-LOS` is one switch over one query, and that is the whole
## reason the three cannot disagree: `DetectionSystem.has_los` is **the only
## line-of-sight query in the project**, so the detection tint, the Compass lock's
## 1.6 s arc and Focus accumulation all ask the same question of the same list.
##
## **THIS FILE DRIVES A REAL CAST RATHER THAN CALLING `add()`.** `CinderfallVolumes`
## has been unit-tested since US-0056 with **no caller at all**; what US-0067 adds
## is the caller, so what is worth asserting is that pressing the button reaches it.
extends GutTest

const CASTER := 61

var _ctx: MatchContext
var _system: AbilitySystem


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.tick = 400
	_system = AbilitySystem.new()
	add_child_autofree(_system)
	_system.setup(_ctx)
	var pawn := PawnContext.new()
	pawn.peer_id = CASTER
	pawn.reset_for_spawn(Vector3.ZERO, 0.0)
	pawn.state_id = PawnStateId.IDLE
	_ctx.pawn_contexts[CASTER] = pawn
	_system.loadout[CASTER] = [Ids.ABIL_CINDERFALL, Ids.ABIL_LUNGE]


func _advance(ticks: int) -> void:
	for _i: int in ticks:
		_ctx.tick += 1
		_system.tick(_ctx, MatchContext.net_dt())


## Throw down the +Z axis and let it land. **The vector is the aim POINT, not a
## unit direction** — `AbilityRules.aim` leaves anything inside the reach alone, so
## asking for 40 m is what exercises the clamp to `TUN-CINDERFALL-THROW-RANGE`.
## My first version passed `(0, 0, 1)` and put the cloud one metre away.
func _throw_ahead() -> void:
	_system.report_request(CASTER, 0, Vector3.ZERO, Vector3(0.0, 0.0, 40.0))
	_system.tick(_ctx, MatchContext.net_dt())
	_advance(Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME") + 1)


func test_the_cloud_lands_where_it_was_thrown() -> void:
	# **THE PREMISE**, and it also asserts the clamp: `TUN-CINDERFALL-THROW-RANGE`
	# 8.0 m is what a unit direction produces, not the 1 m it was multiplied by.
	_throw_ahead()
	var reach: float = Tuning.ability_data(Ids.ABIL_CINDERFALL).throw_range
	assert_true(
		_ctx.cinderfall.contains_at(Vector3(0.0, 0.0, reach), _ctx.tick),
		"the cloud is not at TUN-CINDERFALL-THROW-RANGE ahead of the caster"
	)


func test_it_blocks_a_line_drawn_through_it() -> void:
	_throw_ahead()
	var reach: float = Tuning.ability_data(Ids.ABIL_CINDERFALL).throw_range
	assert_true(
		_ctx.cinderfall.blocks(Vector3.ZERO, Vector3(0.0, 0.0, reach * 2.0), _ctx.tick),
		"a line straight through the cloud is not blocked"
	)


func test_it_does_not_block_a_line_that_misses_it() -> void:
	# The counterfactual. A `blocks` that answered true unconditionally would
	# satisfy the test above and would end every hunt in the district.
	_throw_ahead()
	assert_false(
		_ctx.cinderfall.blocks(Vector3(60.0, 0.0, 0.0), Vector3(60.0, 0.0, 30.0), _ctx.tick),
		"a line two streets away is blocked"
	)


func test_the_wind_up_blocks_nothing() -> void:
	# **THE 0.45 s IS THE TELL, AND A TELL FOR SOMETHING THAT HAS ALREADY HAPPENED
	# IS A NOTIFICATION.** The pot is in the air for `TUN-CINDERFALL-CAST-TIME` and
	# there is no cloud until it lands, which is what gives a victim the window
	# design law 3 requires.
	_system.report_request(CASTER, 0, Vector3.ZERO, Vector3(0.0, 0.0, 40.0))
	_system.tick(_ctx, MatchContext.net_dt())
	assert_eq(_system.activations, 1, "the cast was refused, so this proves nothing")
	assert_eq(_ctx.cinderfall.count_at(_ctx.tick), 0, "the cloud existed during the wind-up")
	assert_true(_system.is_casting(CASTER, Ids.ABIL_CINDERFALL))
	assert_false(
		_system.is_effect_active(CASTER, Ids.ABIL_CINDERFALL),
		"a cast mid-wind-up reports as an active effect"
	)


func test_the_cloud_appears_when_the_wind_up_ends() -> void:
	_throw_ahead()
	assert_eq(_ctx.cinderfall.count_at(_ctx.tick), 1, "the cloud never landed")
	assert_true(_system.is_effect_active(CASTER, Ids.ABIL_CINDERFALL))
	assert_false(_system.is_casting(CASTER, Ids.ABIL_CINDERFALL))


func test_the_duration_runs_from_the_burst_and_not_from_the_press() -> void:
	# **A 0.45 s THROW FOLLOWED BY A 4.0 s CLOUD IS 4.0 s OF CLOUD.** Counted from
	# the press it would be 3.55, and the counterplay GDD-04 §3.1 prices — *wait at
	# its edge, it lasts 4 s* — would be priced against a number the game does not
	# have.
	_throw_ahead()
	_advance(Tuning.ticks(&"TUN-CINDERFALL-DURATION") - 2)
	assert_eq(_ctx.cinderfall.count_at(_ctx.tick), 1, "the cloud went out early")
	# **THE EFFECT AND THE VOLUME MUST AGREE, AND THEY KEEP TWO CLOCKS.**
	# `CinderfallVolumes` expires on its own tick arithmetic and `AbilitySystem`
	# holds `LiveAbility.ends_at`; a deadline measured from the press rather than
	# from the burst leaves the effect dead for the last 0.45 s of its own cloud,
	# which nothing about the cloud would reveal. **This assertion is here because
	# planting exactly that defect left the test above green.**
	assert_true(
		_system.is_effect_active(CASTER, Ids.ABIL_CINDERFALL),
		"the effect ended while its cloud was still up"
	)
	_advance(3)
	assert_eq(_ctx.cinderfall.count_at(_ctx.tick), 0, "the cloud outlived its duration")


func test_a_caster_killed_mid_throw_drops_no_cloud() -> void:
	# **THE VICTIM WHO READ THE TELL IS PAID FOR READING IT.** There is nobody left
	# to throw the pot; the cooldown and the +40 suspicion were spent at the press
	# and stay spent, which is what makes the wind-up a real risk rather than a
	# formality.
	_system.report_request(CASTER, 0, Vector3.ZERO, Vector3(0.0, 0.0, 40.0))
	_system.tick(_ctx, MatchContext.net_dt())
	_system.on_death(CASTER)
	_advance(Tuning.ticks(&"TUN-CINDERFALL-CAST-TIME") + 2)
	assert_eq(_ctx.cinderfall.count_at(_ctx.tick), 0, "a dead caster still threw the pot")
