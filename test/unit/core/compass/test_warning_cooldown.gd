## **THE RE-TRIGGER COOLDOWN, AND THE ONE CASE THAT MUST DEFEAT IT.** US-0059,
## GDD-03 §9.1, `TUN-COMPASS-WARN-COOLDOWN`.
##
## `PreyWarning` is pure, so the interesting property — that a **new pursuer**
## re-arms the cooldown — can be exercised here without a district, a contract
## cycle or a repair. That is the whole reason it is not a dictionary inside
## `SYS-DETECTION`.
extends GutTest

const PREY := 41
const PURSUER := 42
const OTHER := 43

var _w: PreyWarning
var _cooldown_ticks: int


func before_each() -> void:
	_w = PreyWarning.new()
	_cooldown_ticks = PreyWarning.cooldown_ticks()


func test_the_first_warning_is_immediate() -> void:
	# A prey with no history has never been warned, which is not the same state as
	# one whose cooldown has elapsed — and only the first exists at match start.
	assert_true(_w.consider(PREY, PURSUER, true, true, 0), "the first warning was suppressed")


func test_a_second_warning_waits_the_whole_cooldown() -> void:
	assert_true(_w.consider(PREY, PURSUER, true, true, 100), "the first warning was suppressed")
	assert_false(
		_w.consider(PREY, PURSUER, true, true, 100 + _cooldown_ticks - 1),
		"a warning arrived one tick early — the strobe this cooldown exists to stop"
	)
	assert_true(
		_w.consider(PREY, PURSUER, true, true, 100 + _cooldown_ticks),
		"the cooldown never elapsed; a prey would be warned once and then never again"
	)


func test_holding_the_condition_does_not_warn_every_tick() -> void:
	# **THE COUNTERFACTUAL FOR THE TEST ABOVE.** A pair of single-call assertions
	# passes just as happily against a gate that warns on every other tick. What a
	# player would actually experience is a condition held for seconds, so that is
	# what is measured: five seconds of an unbroken chase at 30 Hz.
	var sent := 0
	var ticks := int(round(5.0 * Tuning.net.server_tick))
	for tick: int in range(ticks):
		if _w.consider(PREY, PURSUER, true, true, tick):
			sent += 1
	var expected := 1 + int(floor(float(ticks - 1) / float(_cooldown_ticks)))
	assert_eq(sent, expected, "%d warnings in 5 s, expected %d" % [sent, expected])
	assert_lt(sent, ticks, "the gate warned on every tick — the cooldown is not applied at all")


func test_a_new_pursuer_defeats_the_cooldown() -> void:
	# **THE DEFECT THIS EXISTS TO REFUSE.** A repair hands the prey a different
	# pursuer. Keyed on the prey alone with no pursuer check, the old cooldown
	# would silence the new one for up to `TUN-COMPASS-WARN-COOLDOWN` — 2.5 s of
	# the prey's only warning, suppressed by a relationship that no longer exists.
	assert_true(_w.consider(PREY, PURSUER, true, true, 200), "the first warning was suppressed")
	assert_false(_w.consider(PREY, PURSUER, true, true, 201), "the cooldown is not applied")
	assert_true(
		_w.consider(PREY, OTHER, true, true, 201),
		"a brand-new pursuer was silenced by the previous pursuer's cooldown"
	)


func test_the_cooldown_then_belongs_to_the_new_pursuer() -> void:
	# And the re-arm must not become a second exploit: alternating between two
	# pursuers cannot produce a warning every tick.
	_w.consider(PREY, PURSUER, true, true, 300)
	_w.consider(PREY, OTHER, true, true, 301)
	assert_false(_w.consider(PREY, OTHER, true, true, 302), "the new pursuer got no cooldown")
	assert_eq(_w.warned_about(PREY), OTHER, "the record still names the previous pursuer")


func test_neither_gate_alone_is_enough() -> void:
	assert_false(_w.consider(PREY, PURSUER, false, true, 0), "warned about a pursuer out of range")
	assert_false(_w.consider(PREY, PURSUER, true, false, 0), "warned about an Anonymous pursuer")
	# And neither refusal armed anything, or a pursuer who closed the distance
	# would find the prey already on cooldown for a warning never delivered.
	assert_eq(_w.last_warned(PREY), -1, "a refused warning armed the cooldown anyway")


func test_a_departing_peer_leaves_nothing_behind() -> void:
	# ENet reuses peer ids (US-0037). An inherited cooldown would silence the
	# joiner's first warning about a pursuer they have never seen.
	_w.consider(PREY, PURSUER, true, true, 400)
	_w.forget(PREY)
	assert_eq(_w.last_warned(PREY), -1, "a departed peer's cooldown survived them")
	assert_true(_w.consider(PREY, PURSUER, true, true, 401), "the inherited cooldown still bites")


func test_the_cooldown_is_read_from_the_tunable_in_net_ticks() -> void:
	# **TRAP 9.** `SYS-DETECTION` ticks at 30 Hz, so a cooldown converted with
	# `step_ticks` would be half as long and both numbers are plausible integers.
	# The two converters must disagree, or this assertion proves nothing.
	assert_ne(
		Tuning.ticks(&"TUN-COMPASS-WARN-COOLDOWN"),
		Tuning.step_ticks(&"TUN-COMPASS-WARN-COOLDOWN"),
		"the two tick domains agree, so this test cannot tell them apart"
	)
	assert_true(_w.consider(PREY, PURSUER, true, true, 0), "the first warning was suppressed")
	var net_ticks := PreyWarning.cooldown_ticks()
	assert_false(_w.consider(PREY, PURSUER, true, true, net_ticks - 1), "warned early")
	assert_true(_w.consider(PREY, PURSUER, true, true, net_ticks), "warned late")
