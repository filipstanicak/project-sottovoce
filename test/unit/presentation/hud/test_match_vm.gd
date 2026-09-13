## **THE TIMER'S ARITHMETIC, AGAINST THE SERVER'S OWN.** US-0073.
##
## The bar fills through the last `TUN-MATCH-FINALPHASE-WARNING` before the Final
## Contract, derived from the authoritative `ticks_remaining` and the same two
## tunables `MatchClock.warning_at` reads. The assertion that matters is the last
## one: the tick the bar reaches full is the tick the server opens `FINAL` — two
## derivations of one instant, from `MatchClock` and from the view model, which
## agree until either moves.
extends GutTest

var _vm: MatchVm
var _changes: int = 0


func before_each() -> void:
	_vm = MatchVm.new()
	_changes = 0
	_vm.changed.connect(func() -> void: _changes += 1)


func _play(ticks: int, phase: int = MatchPhase.Phase.ACTIVE) -> void:
	_vm.apply_phase(
		phase, 1.0 if phase != MatchPhase.Phase.FINAL else Tuning.match_rules.finalphase_mult
	)
	_vm.apply_ticks(ticks)


func test_nothing_is_shown_until_a_clock_has_arrived() -> void:
	_vm.apply_phase(MatchPhase.Phase.ACTIVE, 1.0)
	assert_false(_vm.is_shown(), "shown with no ticks ever received")
	_vm.apply_ticks(300)
	assert_true(_vm.is_shown())


func test_the_timer_is_absent_outside_play() -> void:
	for phase: int in [MatchPhase.Phase.LOBBY, MatchPhase.Phase.WARMUP, MatchPhase.Phase.RESULTS]:
		_play(300, phase)
		assert_false(_vm.is_shown(), "the timer showed in phase %d" % phase)
	for phase: int in [MatchPhase.Phase.ACTIVE, MatchPhase.Phase.FINAL]:
		_play(300, phase)
		assert_true(_vm.is_shown(), "the timer hid in phase %d" % phase)


## `0:01` on the last tick, never `0:00` while the server is still simulating one.
func test_the_seconds_round_up() -> void:
	var rate := int(Tuning.match_rules.tick_rate)
	_play(1)
	assert_eq(_vm.seconds_left(), 1)
	_play(rate)
	assert_eq(_vm.seconds_left(), 1)
	_play(rate + 1)
	assert_eq(_vm.seconds_left(), 2)
	_play(0)
	assert_eq(_vm.seconds_left(), 0)


func test_minutes_and_seconds_split_a_whole_match() -> void:
	var rate := int(Tuning.match_rules.tick_rate)
	_play(278 * rate)
	assert_eq(_vm.minutes(), 4)
	assert_eq(_vm.seconds(), 38)


func test_the_bar_is_empty_before_the_warning_window() -> void:
	var final_ticks := Tuning.ticks(&"TUN-MATCH-FINALPHASE-DURATION")
	var warning := Tuning.ticks(&"TUN-MATCH-FINALPHASE-WARNING")
	_play(final_ticks + warning + 1)
	assert_eq(_vm.warning_fraction(), 0.0, "the bar began before the warning window")
	_play(final_ticks + warning)
	assert_eq(_vm.warning_fraction(), 0.0, "the bar is not empty at the window's first tick")


func test_the_bar_fills_linearly_across_the_warning() -> void:
	var final_ticks := Tuning.ticks(&"TUN-MATCH-FINALPHASE-DURATION")
	var warning := Tuning.ticks(&"TUN-MATCH-FINALPHASE-WARNING")
	_play(final_ticks + warning / 2)
	assert_almost_eq(
		_vm.warning_fraction(), 0.5, 1.0 / float(warning), "half the window is not half a bar"
	)


## **THE TICK THE BAR IS FULL IS THE TICK `FINAL` OPENS**, by the server's own
## arithmetic: `MatchClock.remaining` in `ACTIVE` is what is left of `ACTIVE` plus
## the whole of `FINAL`, so a remainder equal to `FINAL`'s length is the boundary.
func test_the_bar_is_full_exactly_when_the_final_contract_opens() -> void:
	var rules := Tuning.match_rules
	var boundary := MatchClock.remaining(
		MatchPhase.Phase.ACTIVE, MatchClock.final_opens_at(rules), rules
	)
	_play(boundary)
	assert_eq(_vm.warning_fraction(), 1.0, "the bar was not full on the boundary tick")
	_play(boundary + 1)
	assert_lt(_vm.warning_fraction(), 1.0, "the bar was full a tick early")


func test_the_bar_stays_full_through_the_final_contract() -> void:
	_play(10, MatchPhase.Phase.FINAL)
	assert_eq(_vm.warning_fraction(), 1.0)
	assert_true(_vm.is_final())


## The marker names the number scoring pays, and a trailing `.0` on the shipped
## value would read as a decimal that matters.
func test_the_marker_is_the_multiplier_without_a_spurious_decimal() -> void:
	_vm.apply_phase(MatchPhase.Phase.FINAL, 2.0)
	assert_eq(_vm.multiplier_label(), "2")
	_vm.apply_phase(MatchPhase.Phase.FINAL, 1.5)
	assert_eq(_vm.multiplier_label(), "1.5")


## A snapshot lands thirty times a second; the widget redraws on change only.
func test_an_unchanged_clock_is_not_announced_twice() -> void:
	_play(300)
	var after_first := _changes
	_vm.apply_ticks(300)
	assert_eq(_changes, after_first, "the same remainder was announced again")
	_vm.apply_ticks(299)
	assert_eq(_changes, after_first + 1)
