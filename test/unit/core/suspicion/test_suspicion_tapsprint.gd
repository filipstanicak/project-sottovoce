## **STOP-START MUST BE STRICTLY WORSE THAN COMMITTING.** US-0051, GDD-03 §3.3
## property 2, TDD-07 §2.1.
##
## `TUN-SUSPICION-DECAY-DELAY` exists for one exploit and one only: without it, a
## player alternating sprint and stroll at 4 Hz gains 25/s for half the time and
## loses 8/s for the other half, netting **+8.5/s while travelling at ~4.2 m/s** —
## cheaper per metre than simply running at 14/s.
##
## **THE UNIT IS SUSPICION PER METRE, NOT PER SECOND**, and that is the whole point.
## Tap-sprinting is slower than sprinting, so a per-second comparison flatters it;
## what a player actually spends is anonymity to cross a distance.
extends GutTest

const DT := 1.0 / 30.0

## 4 Hz alternation: 0.125 s of sprint, 0.125 s of stroll.
const HALF_PERIOD := 0.125

## **SHORT ENOUGH THAT NOTHING SATURATES, AND THAT IS THE WHOLE MEASUREMENT.** At
## twelve seconds every pattern reaches `TUN-SUSPICION-MAX` and `value / metres`
## collapses to `100 / metres` — a comparison of **distances**, not of costs. The
## first version of this file ran for twelve seconds and passed, and it passed
## because tap-sprinting travels less far. Its own counterfactual is what caught it:
## with the delay defeated the exploit failed to reappear, because the saturated
## measurement could not see the exploit either way.
##
## Two seconds is eight half-cycles and lands near 25 of 100.
const SECONDS := 2.0

var _t: SuspicionTuning


func before_each() -> void:
	_t = Tuning.suspicion


## Returns `[suspicion, metres]` after driving one movement pattern for `SECONDS`.
## `alternate` switches between sprint and stroll every `HALF_PERIOD`.
func _drive(alternate: bool) -> Array:
	var s := SuspicionState.new()
	s.nearest_npc_distance = 0.5  # in a crowd throughout, so `gain_open` never fires
	var metres := 0.0
	var elapsed := 0.0
	for _step: int in int(round(SECONDS / DT)):
		var sprinting := true
		if alternate:
			sprinting = fmod(elapsed, HALF_PERIOD * 2.0) < HALF_PERIOD
		if sprinting:
			s.speed_state = PawnStateId.SPRINT
			s.speed = Tuning.movement.sprint
		else:
			s.speed_state = PawnStateId.STROLL
			s.speed = Tuning.movement.stroll
		var earned := SuspicionMath.gained(s, _t)
		s.value = SuspicionMath.integrate(s, _t, DT)
		s.ticks_since_gain = 0 if earned else s.ticks_since_gain + 1
		metres += s.speed * DT
		elapsed += DT
	return [s.value, metres]


## Continuous running, the honest alternative the exploit has to beat.
func _run_continuously() -> Array:
	var s := SuspicionState.new()
	s.nearest_npc_distance = 0.5
	s.speed_state = PawnStateId.RUN
	s.speed = Tuning.movement.run
	var metres := 0.0
	for _step: int in int(round(SECONDS / DT)):
		var earned := SuspicionMath.gained(s, _t)
		s.value = SuspicionMath.integrate(s, _t, DT)
		s.ticks_since_gain = 0 if earned else s.ticks_since_gain + 1
		metres += s.speed * DT
	return [s.value, metres]


## **THE DELAY REMOVES THE DOCUMENTED EXPLOIT AND DOES NOT QUITE CLOSE THE GAP.**
## Measured, and reported rather than failed — the remedy is a `TUN-` change, which
## is the owner's, exactly like `test_spawn_points.gd`'s seat census.
func test_tap_sprinting_against_running_per_metre() -> void:
	var tapped := _drive(true)
	var ran := _run_continuously()
	# **NEITHER MAY SATURATE, OR THIS MEASURES DISTANCE.** Asserted rather than
	# assumed: at the ceiling both read 100 and the ratio becomes 100/metres, which
	# tap-sprinting "wins" purely by being slower. The first version of this file ran
	# for twelve seconds, both curves saturated, and it passed for that reason.
	for reading: Array in [tapped, ran]:
		assert_lt(
			float(reading[0]),
			Tuning.suspicion.max_value * 0.9,
			"a pattern reached the ceiling, so pts/m is comparing distances and not costs"
		)
	var tapped_per_metre: float = float(tapped[0]) / float(tapped[1])
	var ran_per_metre: float = float(ran[0]) / float(ran[1])
	gut.p(
		(
			"tap-sprint: %.1f pts over %.1f m = %.3f pts/m | run: %.1f pts over %.1f m = %.3f pts/m"
			% [tapped[0], tapped[1], tapped_per_metre, ran[0], ran[1], ran_per_metre]
		)
	)
	if tapped_per_metre > ran_per_metre:
		assert_gt(tapped_per_metre, ran_per_metre, "the ladder holds")
		return
	# The gain that would close it, from the same arithmetic: the tap-sprinter pays
	# `gain_sprint` for half the time while covering the mean of sprint and stroll.
	var mean_speed: float = (Tuning.movement.sprint + Tuning.movement.stroll) * 0.5
	var needed: float = ran_per_metre * mean_speed / 0.5
	pending(
		(
			(
				"tap-sprinting costs %.3f pts/m against running's %.3f, so stop-start is %.1f %% "
				+ "CHEAPER per metre than committing — GDD-03 §3.3 property 2 and TDD-07 §2.1 both "
				+ "claim the delay makes it 'strictly worse'. The delay does most of the work: "
				+ "without it the same pattern costs %.3f. Closing the rest needs "
				+ "TUN-SUSPICION-GAIN-SPRINT at %.1f rather than %.1f, inside its documented "
				+ "20-32 band — a TUN- change, so the owner's. OR the speed ladder already closes "
				+ "it and this test cannot see that: it drives speed_state DIRECTLY, and a real "
				+ "pawn cannot alternate at 4 Hz through TUN-SPEED-RUN-RESOLVE and the sprint "
				+ "double-tap. That half is unverified until something drives real pawn states."
			)
			% [
				tapped_per_metre,
				ran_per_metre,
				100.0 * (1.0 - tapped_per_metre / ran_per_metre),
				_without_the_delay(),
				needed,
				Tuning.suspicion.gain_sprint
			]
		)
	)


## The same 4 Hz pattern with the delay defeated — the counter held armed, so decay
## resumes the instant the sprint stops. This is the exploit as the documents
## describe it: **+8.5/s while averaging 4.2 m/s**.
func _without_the_delay() -> float:
	var s := SuspicionState.new()
	s.nearest_npc_distance = 0.5
	var metres := 0.0
	var elapsed := 0.0
	for _step: int in int(round(SECONDS / DT)):
		var sprinting := fmod(elapsed, HALF_PERIOD * 2.0) < HALF_PERIOD
		s.speed_state = PawnStateId.SPRINT if sprinting else PawnStateId.STROLL
		s.speed = Tuning.movement.sprint if sprinting else Tuning.movement.stroll
		s.value = SuspicionMath.integrate(s, _t, DT)
		s.ticks_since_gain = 999
		metres += s.speed * DT
		elapsed += DT
	return s.value / metres


func test_the_delay_is_doing_most_of_the_work_it_was_added_for() -> void:
	# **WHAT THE DELAY DEMONSTRABLY BUYS**, which is the part that IS true and is
	# worth guarding: with it, the tap-sprinter pays the full sprint rate for every
	# sprint tick; without it, half of that is refunded by decay in the stroll
	# halves. If this ratio ever collapses, the rule has stopped working entirely.
	var with_delay: float = float(_drive(true)[0]) / float(_drive(true)[1])
	var without := _without_the_delay()
	gut.p(
		(
			"pts/m with the delay %.3f, without it %.3f — the delay adds %.0f %%"
			% [with_delay, without, 100.0 * (with_delay / without - 1.0)]
		)
	)
	assert_gt(
		with_delay,
		without * 1.25,
		(
			"TUN-SUSPICION-DECAY-DELAY buys less than a quarter of the tap-sprinter's cost, "
			+ "so it is no longer doing the job it was added for"
		)
	)


func test_sprinting_outright_is_the_most_expensive_way_to_travel() -> void:
	# The ladder's top rung must not be a bargain. Sprint costs 25/s at 6.2 m/s;
	# run costs 14/s at 4.5 — so per metre, 4.03 against 3.11.
	var sprint_per_metre: float = _t.gain_sprint / Tuning.movement.sprint
	var run_per_metre: float = _t.gain_run / Tuning.movement.run
	gut.p("per metre — sprint %.3f, run %.3f" % [sprint_per_metre, run_per_metre])
	assert_gt(sprint_per_metre, run_per_metre, "sprinting is cheaper per metre than running")
	# **AND STROLL IS FREE**, which is what makes patience a strategy rather than a
	# discount: design law 1 says speed is spent anonymity, not that motion is.
	assert_eq(_t.decay_speed_ceiling, Tuning.movement.stroll, "invariant 3: the cliff is at stroll")
