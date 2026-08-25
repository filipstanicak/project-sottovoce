## **THE SOURCE LIST AND THE NUMBER MUST BE ONE DECISION.** US-0052,
## NETWORK_PROTOCOL §4, UI_UX_SPEC §4.1.
##
## `active_sources` is printed under the tier as the words that answer *"why am I
## visible?"*. If it were computed by a second function applying the same
## conditions, the two would drift the first time a condition was retuned — and
## the symptom is not an error, it is a player reading "sprinting" while the value
## climbs because they are alone. That teaches the wrong lesson and, worse,
## teaches the player to stop reading the channel.
##
## So the property under test is not "the bits look right". It is **`gain_rate()`
## equals the sum of the rates of exactly the bits `of()` sets**, over every
## combination of inputs that can occur.
extends GutTest

## Every state that can occupy `speed_state`, including the three that cost
## nothing — a free state that quietly set a bit would be caught here.
const STATES: Array[StringName] = [
	PawnStateId.IDLE,
	PawnStateId.BLEND_WALK,
	PawnStateId.STROLL,
	PawnStateId.RUN,
	PawnStateId.SPRINT,
	PawnStateId.CLIMB,
]

var _t: SuspicionTuning


func before_each() -> void:
	_t = Tuning.suspicion


## One reading per combination of state × roof × alone × blending.
func _every_case() -> Array:
	var cases: Array = []
	for state: StringName in STATES:
		for roof: bool in [false, true]:
			for alone: bool in [false, true]:
				for blending: bool in [false, true]:
					var s := SuspicionState.new()
					s.speed_state = state
					s.on_roof = roof
					s.blending = blending
					s.nearest_npc_distance = (_t.open_radius + 1.0) if alone else 0.5
					cases.append(s)
	return cases


func test_the_rate_is_the_sum_of_the_bits_in_every_case() -> void:
	var seen := SuspicionSources.NONE
	var highest := 0.0
	for s: SuspicionState in _every_case():
		var bits := SuspicionSources.of(s, _t)
		seen |= bits
		var summed := 0.0
		for bit: int in SuspicionSources.ALL:
			if (bits & bit) != 0:
				summed += SuspicionSources.rate_of(bit, _t)
		var rate := SuspicionMath.gain_rate(s, _t)
		highest = maxf(highest, rate)
		assert_almost_eq(
			rate,
			summed,
			0.001,
			(
				"gain %.2f against a source list worth %.2f for state=%s roof=%s alone=%s blend=%s"
				% [
					rate,
					summed,
					s.speed_state,
					s.on_roof,
					s.nearest_npc_distance > _t.open_radius,
					s.blending
				]
			)
		)
	# **THE VACUOUS-SUCCESS GUARD, AND IT IS TWO GUARDS.** An `of()` that always
	# returned nothing and a `gain_rate()` that always returned zero would satisfy
	# every assertion above. So: every bit must have been reached, and the worst
	# case must be the compounded one ASM-0018 exists for.
	for bit: int in SuspicionSources.ALL:
		assert_true((seen & bit) != 0, "no case in the sweep ever set bit %d" % bit)
	assert_almost_eq(
		highest,
		_t.gain_sprint + _t.gain_roof + _t.gain_open,
		0.001,
		"the sweep never reached sprint + roof + alone, so it did not cover compounding"
	)


func test_run_sprint_and_climb_are_mutually_exclusive() -> void:
	# They are *states*, and a pawn is in one state. A reading with two of them set
	# would double-charge a player for one decision.
	var movement := SuspicionSources.RUN | SuspicionSources.SPRINT | SuspicionSources.CLIMB
	for s: SuspicionState in _every_case():
		var bits: int = SuspicionSources.of(s, _t) & movement
		assert_true(
			bits == 0 or (bits & (bits - 1)) == 0,
			"state %s set more than one movement bit" % s.speed_state
		)


func test_roof_and_alone_accompany_any_movement() -> void:
	# The other half: they are *conditions*, not states, so nothing may make them
	# exclusive with each other or with the movement bits.
	var s := SuspicionState.new()
	s.speed_state = PawnStateId.SPRINT
	s.on_roof = true
	s.nearest_npc_distance = INF
	var bits := SuspicionSources.of(s, _t)
	for bit: int in [SuspicionSources.SPRINT, SuspicionSources.ROOF, SuspicionSources.OPEN]:
		assert_true((bits & bit) != 0, "bit %d was dropped from a compounded reading" % bit)


func test_an_npc_exactly_at_the_radius_is_company() -> void:
	# **THE BOUNDARY THE SPATIAL HASH RETURNS.** `nearest_distance` answers with the
	# distance when it is inside the bound and `INF` when it is not, so exactly the
	# radius is a real reading and must not read as alone. One centimetre either way
	# is the difference between free and 6/s.
	var s := SuspicionState.new()
	s.nearest_npc_distance = _t.open_radius
	assert_eq(
		SuspicionSources.of(s, _t) & SuspicionSources.OPEN, 0, "an NPC at the radius read as alone"
	)
	s.nearest_npc_distance = _t.open_radius + 0.01
	assert_true(
		(SuspicionSources.of(s, _t) & SuspicionSources.OPEN) != 0,
		"an NPC beyond the radius did not read as alone"
	)


func test_blending_reports_no_sources_at_all() -> void:
	# A list naming reasons the value is *not* rising would be the opposite of an
	# explanation. `integrate()` early-returns on the same flag.
	var s := SuspicionState.new()
	s.speed_state = PawnStateId.SPRINT
	s.on_roof = true
	s.nearest_npc_distance = INF
	assert_gt(SuspicionSources.of(s, _t), 0, "the un-blended case proves nothing")
	s.blending = true
	assert_eq(SuspicionSources.of(s, _t), SuspicionSources.NONE, "a blend still listed sources")


func test_the_bit_order_is_the_one_the_protocol_declares() -> void:
	# **NOT A STYLE ASSERTION.** NETWORK_PROTOCOL §4 lists them SPRINT ROOF CLIMB
	# OPEN RUN, bit 0 upward, and a peer on a different build reads the byte
	# positionally. Every misread bit is a plausible one.
	assert_eq(SuspicionSources.SPRINT, 1, "SPRINT is not bit 0")
	assert_eq(SuspicionSources.ROOF, 2, "ROOF is not bit 1")
	assert_eq(SuspicionSources.CLIMB, 4, "CLIMB is not bit 2")
	assert_eq(SuspicionSources.OPEN, 8, "OPEN is not bit 3")
	assert_eq(SuspicionSources.RUN, 16, "RUN is not bit 4")
	# And the whole field fits the `u8` the format spends on it.
	var all_bits := 0
	for bit: int in SuspicionSources.ALL:
		all_bits |= bit
	assert_lte(all_bits, 255, "the source bitfield no longer fits a byte")


func test_an_undeclared_bit_is_worth_nothing_rather_than_erroring() -> void:
	# Three of the byte's eight values are undeclared. A future source appended at
	# bit 5 must not make an old client throw.
	assert_eq(SuspicionSources.rate_of(1 << 7, _t), 0.0, "an undeclared bit carried a rate")
	assert_eq(SuspicionSources.rate(1 << 7, _t), 0.0, "an undeclared bit was summed")
