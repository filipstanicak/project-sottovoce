## `SYS-MATCH` - the phase machine. US-0079.
##
## **THE ONE THAT MATTERS IS `test_the_phase_opens_where_the_points_double`.** The
## corpus's standing instruction for this story was that the phase must *read* the
## Final Contract boundary scoring already owns rather than derive it again, "or the
## phase the HUD announces and the phase the points are paid at will drift". That
## drift needs both halves visible at once to be seen, so it is asserted here by
## driving the real machine to the tick it opens `FINAL` and asking `ScoreEvent` what
## a kill on that tick is worth.
extends GutTest

## A short match, so the machine can be driven end to end in a few hundred ticks.
## Every duration below is a whole number of seconds at 30 Hz, so nothing rounds.
const WARMUP_S := 2.0
const MATCH_S := 20.0
const FINAL_S := 5.0
const WARNING_S := 1.0
const RESULTS_S := 3.0

var _sys: MatchSystem
var _ctx: MatchContext
var _rules: MatchTuning


func before_each() -> void:
	_rules = _short_match()
	_ctx = MatchContext.new()
	_sys = MatchSystem.new()
	_sys.setup(_ctx, _rules)


func _short_match() -> MatchTuning:
	var r := MatchTuning.new()
	r.tick_rate = 30.0
	r.min_players = 4
	r.max_players = 6
	r.lobby_countdown = WARMUP_S
	r.duration = MATCH_S
	r.finalphase_duration = FINAL_S
	r.finalphase_warning = WARNING_S
	r.finalphase_mult = 2.0
	r.results_duration = RESULTS_S
	return r


## One net tick, exactly as `MatchDirector._net_tick` runs it: the tick advances,
## then the phase is asked, and only then would the stages run.
func _tick() -> void:
	_ctx.tick += 1
	_sys.advance(_ctx)


func _tick_until(phase: int, limit: int) -> int:
	for i: int in limit:
		_tick()
		if _ctx.phase == phase:
			return i + 1
	return -1


func _fill_the_lobby() -> void:
	_sys.players = _rules.min_players
	_ctx.pawns = {10: null, 11: null, 12: null, 13: null}


func test_the_lobby_waits_for_the_floor_and_then_counts_down() -> void:
	_sys.players = _rules.min_players - 1
	for _i: int in 200:
		_tick()
	assert_eq(_ctx.phase, MatchPhase.Phase.LOBBY, "the countdown began one player short")
	_sys.players = _rules.min_players
	_tick()
	assert_eq(_ctx.phase, MatchPhase.Phase.WARMUP, "the floor was reached and nothing happened")


## **THE CYCLE IS DEALT AT THE COUNTDOWN, NOT AT THE FIRST TICK OF PLAY.** US-0079's
## eighth criterion, and the signal is what `ContractSystem.open` finally hangs off.
func test_the_countdown_deals_the_cycle_once_and_names_the_peers() -> void:
	var deals: Array = []
	_sys.countdown_opened.connect(
		func(peers: PackedInt32Array, _c: MatchContext) -> void: deals.append(peers)
	)
	_fill_the_lobby()
	for _i: int in 400:
		_tick()
	assert_eq(deals.size(), 1, "the cycle was dealt %d times" % deals.size())
	assert_eq(Array(deals[0] as PackedInt32Array).size(), 4, "the deal did not carry the lobby")


func test_the_countdown_lasts_exactly_the_lobby_countdown() -> void:
	_fill_the_lobby()
	_tick()
	assert_eq(_ctx.phase, MatchPhase.Phase.WARMUP, "the countdown never began")
	var ticks := _tick_until(MatchPhase.Phase.ACTIVE, 400)
	assert_eq(ticks, MatchClock.ticks_of(WARMUP_S, _rules), "the countdown was the wrong length")


func test_play_begins_at_a_known_tick_and_the_score_origin_is_that_tick() -> void:
	_fill_the_lobby()
	assert_eq(_ctx.active_started_at, MatchContext.NO_MATCH, "a match not started has an origin")
	assert_true(_tick_until(MatchPhase.Phase.ACTIVE, 400) > 0, "play never began")
	assert_eq(_ctx.active_started_at, _ctx.tick, "the score origin is not the first tick of play")
	assert_eq(_ctx.match_tick(), 0, "the first tick of play is not match tick zero")


## **THE ASSERTION THIS FILE EXISTS FOR.** Two independent derivations of one
## instant, asked at the same moment.
func test_the_phase_opens_where_the_points_double() -> void:
	_fill_the_lobby()
	assert_true(_tick_until(MatchPhase.Phase.ACTIVE, 400) > 0, "play never began")
	var before := -1.0
	while _ctx.phase == MatchPhase.Phase.ACTIVE:
		before = ScoreEvent.multiplier_at(_ctx.match_tick(), _rules)
		_tick()
	assert_eq(_ctx.phase, MatchPhase.Phase.FINAL, "the Final Contract never opened")
	assert_eq(before, 1.0, "the tick before the Final Contract already paid double")
	assert_eq(
		ScoreEvent.multiplier_at(_ctx.match_tick(), _rules),
		_rules.finalphase_mult,
		"the phase opened the Final Contract on a tick that still pays a single score"
	)


## The same instant, against the profile the game actually ships.
func test_the_shipped_profile_agrees_about_the_boundary() -> void:
	var rules := Tuning.match_rules
	var opens := MatchClock.final_opens_at(rules)
	assert_eq(ScoreEvent.multiplier_at(opens, rules), rules.finalphase_mult, "shipped: opens late")
	assert_eq(ScoreEvent.multiplier_at(opens - 1, rules), 1.0, "shipped: opens early")


## **`multiplier:u8` CANNOT CARRY A FRACTION, AND THIS IS WHERE THAT STOPS BEING
## SURVIVABLE.** `SnapshotBuilder` rounds the multiplier onto a whole-number wire
## field. At the shipped 2.0 that is exact; `TUN-MATCH-FINALPHASE-MULT` is
## `@export_range(1.5, 3.0, 0.1)`, so a re-pricing to 1.5 would announce **2** to
## every HUD while scoring paid 1.5 - a screen that disagrees with the points.
## This goes red on the day the value changes rather than on the day somebody looks.
func test_the_announced_multiplier_is_the_one_that_pays() -> void:
	var mult := Tuning.match_rules.finalphase_mult
	assert_eq(
		float(int(round(mult))),
		mult,
		(
			(
				"TUN-MATCH-FINALPHASE-MULT is %.2f and the wire carries a u8: widen "
				+ "Snapshot.multiplier before shipping this value"
			)
			% mult
		)
	)


func test_the_warning_fires_once_and_changes_no_phase() -> void:
	var warned: Array = []
	_sys.final_warning_announced.connect(func(_c: MatchContext) -> void: warned.append(_ctx.phase))
	_fill_the_lobby()
	assert_true(_tick_until(MatchPhase.Phase.ACTIVE, 400) > 0, "play never began")
	var at := -1
	while _ctx.phase == MatchPhase.Phase.ACTIVE:
		if warned.size() == 1 and at < 0:
			at = _sys.phase_elapsed
		_tick()
	assert_eq(warned.size(), 1, "the warning fired %d times" % warned.size())
	assert_eq(int(warned[0]), MatchPhase.Phase.ACTIVE, "the warning arrived after the phase moved")
	assert_eq(at, MatchClock.warning_at(_rules), "the warning was not the tunable early")


func test_the_final_contract_ends_in_results_and_results_end_nowhere() -> void:
	_fill_the_lobby()
	assert_true(_tick_until(MatchPhase.Phase.FINAL, 2000) > 0, "the Final Contract never opened")
	var ticks := _tick_until(MatchPhase.Phase.RESULTS, 2000)
	assert_eq(
		ticks, MatchClock.ticks_of(FINAL_S, _rules), "the Final Contract was the wrong length"
	)
	for _i: int in 400:
		_tick()
	assert_eq(_ctx.phase, MatchPhase.Phase.RESULTS, "the results screen restarted the match")


## **THE MATCH TIMER MUST NEVER GAIN TIME**, which is the whole reason `ACTIVE` and
## `FINAL` share one countdown rather than each answering its own clock.
func test_the_clock_never_runs_backwards_across_the_boundary() -> void:
	_fill_the_lobby()
	assert_true(_tick_until(MatchPhase.Phase.ACTIVE, 400) > 0, "play never began")
	var total := MatchClock.ticks_of(MATCH_S, _rules)
	var checked := 0
	while _ctx.phase == MatchPhase.Phase.ACTIVE or _ctx.phase == MatchPhase.Phase.FINAL:
		# One tick of the match is one tick off the clock, across the boundary and
		# through it. A per-phase clock reads 600 down to 151 and then **jumps back
		# up to 150**, which is what this arithmetic refuses.
		assert_eq(
			_sys.remaining(_ctx), total - checked, "the match timer jumped at tick %d" % _ctx.tick
		)
		checked += 1
		_tick()
	assert_eq(
		checked,
		total,
		"the sweep did not cover the whole match - an empty loop agrees with everything"
	)


func test_falling_below_the_floor_ends_the_match_with_results() -> void:
	var gave_up: Array = []
	_sys.abandoned.connect(func(n: int, _c: MatchContext) -> void: gave_up.append(n))
	_fill_the_lobby()
	assert_true(_tick_until(MatchPhase.Phase.ACTIVE, 400) > 0, "play never began")
	_sys.players = _rules.min_players - 1
	_tick()
	assert_eq(_ctx.phase, MatchPhase.Phase.RESULTS, "the match continued below the floor")
	assert_eq(gave_up.size(), 1, "nothing said why the match ended")


## **A PHASE SOMEBODY ELSE ASSIGNED IS A FIXTURE, NOT A MATCH IN PROGRESS.** Half
## the probes in `tools/` set `ctx.phase` by hand with one synthetic peer; ending
## their match for want of players would leave every one of them simulating nothing,
## with no error at all.
func test_a_phase_this_system_did_not_start_is_not_abandoned() -> void:
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_sys.players = 0
	for _i: int in 100:
		_tick()
	assert_eq(
		_ctx.phase, MatchPhase.Phase.ACTIVE, "a probe's fixture was ended for want of players"
	)
