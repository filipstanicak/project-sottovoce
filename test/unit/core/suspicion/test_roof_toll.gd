## **THE ROOFS ARE A HIGHWAY WITH A TOLL BOOTH.** GDD-02 §6, §6.1, US-0020.
##
## `TUN-SUSPICION-GAIN-ROOF` 18/s for being up there at all, regardless of speed.
## Standing perfectly still on a roof reaches **Noticed** in 1.7 s — which is the
## single thing stopping the roofs from being strictly better than the street.
##
## §6.1 reads the cost table vertically and gets the route economy out of it:
## vertical movement costs, horizontal slow movement pays, dropping down is free.
## The correct roof play is climb, cross, drop *immediately*, and let the crowd
## absorb you. **The expensive mistake is lingering**, and this rate is what makes
## lingering expensive.
##
## **RE-AUTHORED AGAINST `SuspicionMath`, WHICH IS THE LADDER THE GAME ACTUALLY
## RUNS.** It used to live in `test/unit/pawn/states/` and drive
## `PawnState.suspicion_rate()` — a second, complete implementation of the whole
## ladder that nothing in the shipped game ever called, and that **disagreed**
## with this one: it had no `TUN-SUSPICION-GAIN-OPEN`, no
## `TUN-SUSPICION-DECAY-DELAY` and no stillness multiplier, so standing alone in
## an empty plaza *recovered* anonymity there and costs +6/s here. Every property
## below is the same; only the subject changed.
extends GutTest

const DT := 1.0 / 30.0

var _t: SuspicionTuning
var _s: SuspicionState


func before_each() -> void:
	_t = Tuning.suspicion
	_s = SuspicionState.new()
	# A crowd underfoot throughout, so `TUN-SUSPICION-GAIN-OPEN` never fires and
	# what is measured is the toll rather than the emptiness above a rooftop.
	_s.nearest_npc_distance = 0.5


## Put the reading at world height `y`, which is what `SYS-SUSPICION` reads off
## the pawn — absolute, and that only works while the street stratum is flat at
## y = 0. `TUN-SUSPICION-ROOF-HEIGHT` says so, and so does the test below.
func _at(height: float) -> void:
	_s.on_roof = height >= _t.roof_height


func _rate(state: StringName, height: float) -> float:
	_s.speed_state = state
	_at(height)
	return SuspicionMath.gain_rate(_s, _t)


## The decay a civilian state earns once `TUN-SUSPICION-DECAY-DELAY` has passed.
func _decay(state: StringName, height: float) -> float:
	_s.speed_state = state
	_at(height)
	_s.speed = 0.0
	_s.ticks_since_gain = 999
	return SuspicionMath.decay_rate(_s, _t, SuspicionMath.gain_rate(_s, _t))


func test_the_street_costs_nothing_extra() -> void:
	assert_eq(_rate(PawnStateId.STROLL, VetraioLayout.STREET_Y), 0.0, "the street charged a toll")
	assert_almost_eq(
		_decay(PawnStateId.STROLL, VetraioLayout.STREET_Y),
		_t.decay_base,
		0.001,
		"strolling the street did not recover anonymity"
	)


func test_a_balcony_is_not_the_roof() -> void:
	# 3.5 m, under the 6 m threshold. Balconies are part of the street stratum's
	# economy — a place to watch from, not a place that costs to stand on.
	assert_eq(_rate(PawnStateId.STROLL, VetraioLayout.BALCONY_Y), 0.0, "a balcony charged a toll")
	assert_almost_eq(
		_decay(PawnStateId.STROLL, VetraioLayout.BALCONY_Y),
		_t.decay_base,
		0.001,
		"a balcony stopped recovering anonymity"
	)


func test_standing_still_on_a_roof_costs_the_full_rate() -> void:
	# **REGARDLESS OF SPEED.** Idle on a roof is not free; that is the whole point.
	var rate := _rate(PawnStateId.IDLE, VetraioLayout.ROOF_Y)
	assert_almost_eq(rate, _t.gain_roof, 0.001, "the roof toll is not TUN-SUSPICION-GAIN-ROOF")
	assert_gt(rate, 0.0, "standing on a roof still recovers anonymity")


func test_decay_does_not_run_on_a_roof() -> void:
	# **NOT NETTED.** 18/s against the 8/s decay would reach Noticed in 3.0 s;
	# TUNABLES §3.2 says 1.7 s, which is 30/18 — the toll alone. A roof is not
	# somewhere you recover slowly. It is somewhere you do not recover.
	#
	# In `SuspicionMath` this is ASM-0008 rather than a special case: gain and
	# decay are mutually exclusive, and the toll is a gain.
	for state: StringName in [PawnStateId.IDLE, PawnStateId.BLEND_WALK, PawnStateId.STROLL]:
		assert_eq(
			_decay(state, VetraioLayout.ROOF_Y), 0.0, "%s recovered anonymity on a roof" % state
		)
		assert_almost_eq(
			_rate(state, VetraioLayout.ROOF_Y),
			_t.gain_roof,
			0.001,
			"%s did not pay the full toll on a roof" % state
		)


func test_the_roof_toll_reaches_noticed_in_under_two_seconds() -> void:
	# TUNABLES §3.2 says 1.7 s. Asserted against the tier threshold rather than
	# against 1.7, so a retune of either moves the claim honestly.
	var rate := _rate(PawnStateId.IDLE, VetraioLayout.ROOF_Y)
	assert_lt(_t.tier_noticed / rate, 2.0, "a roof no longer costs anything much")
	# And the same claim driven through the integrator, which is what the server
	# runs: a rate is only a promise until something integrates it.
	_s.speed_state = PawnStateId.IDLE
	_at(VetraioLayout.ROOF_Y)
	var seconds := 0.0
	while _s.value < _t.tier_noticed and seconds < 5.0:
		_s.value = SuspicionMath.integrate(_s, _t, DT)
		seconds += DT
	assert_lt(seconds, 2.0, "standing on a roof took %.2f s to reach Noticed" % seconds)


func test_the_toll_is_added_to_the_speed_cost_not_swapped_for_it() -> void:
	# Sprinting across a roof costs both. "Regardless of speed" means it applies
	# whatever you are doing, not that it replaces what you are doing.
	var sprint := _rate(PawnStateId.SPRINT, VetraioLayout.ROOF_Y)
	assert_almost_eq(sprint, _t.gain_sprint + _t.gain_roof, 0.001, "the toll replaced the rung")
	assert_gt(
		sprint, _rate(PawnStateId.IDLE, VetraioLayout.ROOF_Y), "speed stopped costing on a roof"
	)


func test_the_threshold_sits_between_the_two_strata() -> void:
	# A tunable that drifted above the roof or below the balcony would silently
	# make the toll free or make balconies expensive.
	assert_gt(_t.roof_height, VetraioLayout.BALCONY_Y, "the toll threshold is below the balconies")
	assert_lt(_t.roof_height, VetraioLayout.ROOF_Y, "the toll threshold is above the roofs")


func test_every_locomotion_state_pays_it() -> void:
	# One rule, every rung. A rung that forgot the surcharge would be the cheap way
	# to loiter on a roof, and nobody would find it except by playing.
	var missing: PackedStringArray = []
	for state: StringName in PawnStateId.LOCOMOTION:
		if _rate(state, VetraioLayout.ROOF_Y) < _t.gain_roof - 0.001:
			missing.append(String(state))
	assert_eq(missing.size(), 0, "these states are cheap on a roof: " + ", ".join(missing))
	assert_gt(PawnStateId.LOCOMOTION.size(), 3, "the locomotion ladder shrank — check this sweep")


func test_dropping_down_is_free_and_climbing_up_is_not() -> void:
	# §6.1's route economy read vertically: vertical movement costs, slow
	# horizontal movement pays, **dropping down is free**. Gravity is not an
	# athletic display and every civilian is subject to it.
	#
	# **THE DROP IS FREE; THE ROOF YOU DROP FROM IS NOT.** Measured against `IDLE`
	# at the same height rather than against zero — the first version of this
	# assertion read 18.0 and looked like a defect, because a pawn falling from
	# `ROOF_Y` is still above `TUN-SUSPICION-ROOF-HEIGHT` for most of the fall and
	# is still paying the toll. What must be zero is what the *manoeuvre* adds.
	for height: float in [VetraioLayout.STREET_Y, VetraioLayout.ROOF_Y - 1.0]:
		assert_eq(
			_rate(PawnStateId.DROP, height),
			_rate(PawnStateId.IDLE, height),
			"falling charged more than standing there"
		)
		assert_eq(
			_rate(PawnStateId.VAULT, height),
			_rate(PawnStateId.IDLE, height),
			"vaulting charged more than standing there"
		)
	# And climbing *up* is the expensive half of the same pair.
	assert_gt(_rate(PawnStateId.CLIMB, VetraioLayout.STREET_Y), 0.0, "climbing became free")


func test_a_mantle_is_the_one_traverse_that_costs() -> void:
	# GDD-02 §6.1 prices a mantle at "+11.4 (climb rate × duration)" and a vault at
	# nothing, and `PawnStateId.VAULT` is both — so the state alone cannot say which.
	_s.speed_state = PawnStateId.VAULT
	_at(VetraioLayout.STREET_Y)
	_s.mantling = true
	assert_almost_eq(
		SuspicionMath.gain_rate(_s, _t), _t.gain_climb, 0.001, "a mantle stopped costing the climb"
	)
	_s.mantling = false
	assert_eq(SuspicionMath.gain_rate(_s, _t), 0.0, "a vault charged suspicion")
