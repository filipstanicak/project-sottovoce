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
extends GutTest

var _ctx: PawnContext


func before_each() -> void:
	_ctx = PawnContext.new()


func _at(height: float) -> void:
	_ctx.position = Vector3(0.0, height, 0.0)


func test_the_street_costs_nothing_extra() -> void:
	_at(VetraioLayout.STREET_Y)
	assert_eq(StrollState.new().suspicion_rate(_ctx), -Tuning.suspicion.decay_base)


func test_a_balcony_is_not_the_roof() -> void:
	# 3.5 m, under the 6 m threshold. Balconies are part of the street stratum's
	# economy — a place to watch from, not a place that costs to stand on.
	_at(VetraioLayout.BALCONY_Y)
	assert_eq(StrollState.new().suspicion_rate(_ctx), -Tuning.suspicion.decay_base)


func test_standing_still_on_a_roof_costs_the_full_rate() -> void:
	# **REGARDLESS OF SPEED.** Idle on a roof is not free; that is the whole point.
	_at(VetraioLayout.ROOF_Y)
	var rate: float = IdleState.new().suspicion_rate(_ctx)
	assert_almost_eq(rate, Tuning.suspicion.gain_roof, 0.001)
	assert_gt(rate, 0.0, "standing on a roof still recovers anonymity")


func test_decay_does_not_run_on_a_roof() -> void:
	# **NOT NETTED.** 18/s against the 8/s decay would reach Noticed in 3.0 s;
	# TUNABLES §3.2 says 1.7 s, which is 30/18 — the toll alone. A roof is not
	# somewhere you recover slowly. It is somewhere you do not recover.
	_at(VetraioLayout.ROOF_Y)
	for script: GDScript in [IdleState, BlendWalkState, StrollState]:
		var state: PawnState = script.new()
		assert_almost_eq(
			state.suspicion_rate(_ctx),
			Tuning.suspicion.gain_roof,
			0.001,
			"%s recovered anonymity on a roof" % state.id()
		)


func test_the_roof_toll_reaches_noticed_in_under_two_seconds() -> void:
	# TUNABLES §3.2 says 1.7 s. Asserted against the tier threshold rather than
	# against 1.7, so a retune of either moves the claim honestly.
	_at(VetraioLayout.ROOF_Y)
	var rate: float = IdleState.new().suspicion_rate(_ctx)
	assert_lt(Tuning.suspicion.tier_noticed / rate, 2.0, "a roof no longer costs anything much")


func test_the_toll_is_added_to_the_speed_cost_not_swapped_for_it() -> void:
	# Sprinting across a roof costs both. "Regardless of speed" means it applies
	# whatever you are doing, not that it replaces what you are doing.
	_at(VetraioLayout.ROOF_Y)
	var sprint: float = SprintState.new().suspicion_rate(_ctx)
	assert_almost_eq(sprint, Tuning.suspicion.gain_sprint + Tuning.suspicion.gain_roof, 0.001)
	assert_gt(sprint, IdleState.new().suspicion_rate(_ctx), "speed stopped costing on a roof")


func test_the_threshold_sits_between_the_two_strata() -> void:
	# A tunable that drifted above the roof or below the balcony would silently
	# make the toll free or make balconies expensive.
	assert_gt(Tuning.suspicion.roof_height, VetraioLayout.BALCONY_Y)
	assert_lt(Tuning.suspicion.roof_height, VetraioLayout.ROOF_Y)


func test_every_locomotion_state_pays_it() -> void:
	# Six states, one rule. A rung that forgot the surcharge would be the cheap
	# way to loiter on a roof, and nobody would find it except by playing.
	_at(VetraioLayout.ROOF_Y)
	var missing: PackedStringArray = []
	for script: GDScript in PawnStateMachine.REGISTERED:
		var state: PawnState = script.new()
		if not PawnStateId.is_locomotion(state.id()):
			continue
		_at(VetraioLayout.ROOF_Y)
		if state.suspicion_rate(_ctx) < Tuning.suspicion.gain_roof - 0.001:
			missing.append(String(state.id()))
	assert_eq(missing.size(), 0, "these states are cheap on a roof: " + ", ".join(missing))
