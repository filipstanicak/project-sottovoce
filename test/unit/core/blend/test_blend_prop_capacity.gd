## **CAPACITY ONE, AND THE REFUSAL THAT IS NOT SILENCE.** GDD-03 §4.1.4,
## US-0054's third criterion.
##
## The criterion exists because of a specific moment: you run for the hay cart
## with a hunter behind you, press blend, and nothing happens. Without a reason
## the game has told you *the button is broken*; with one it has told you
## *somebody is already in there*, which is a fact you can act on.
##
## `PropOccupancy` is pure, so the two-players-one-prop race and the re-entry
## window can be exercised without a district.
extends GutTest

const FIRST := 11
const SECOND := 12
const WELL := 0
const CART := 1

var _props: PropOccupancy


func before_each() -> void:
	_props = PropOccupancy.new()


func test_the_first_player_gets_in() -> void:
	# **THE PREMISE.** Every refusal below is satisfied by an occupancy that
	# refuses everybody, and this is what stops the file passing that way.
	assert_true(_props.claim(FIRST, WELL, 0), "nobody could enter an empty prop")
	assert_eq(_props.holder_of(WELL), FIRST)
	assert_true(_props.is_inside(FIRST))


func test_a_second_player_is_refused_with_a_reason() -> void:
	_props.claim(FIRST, WELL, 0)
	assert_eq(
		_props.may_enter(SECOND, WELL, 0),
		BlendRefusal.Why.PROP_OCCUPIED,
		"the second arrival was refused without saying why"
	)
	assert_false(_props.claim(SECOND, WELL, 0), "two players got into one prop")
	assert_eq(_props.holder_of(WELL), FIRST, "the second arrival evicted the first")


func test_the_refusal_is_distinct_from_every_other_refusal() -> void:
	# **"DISTINCT FEEDBACK, NOT SILENCE."** If two different problems produced the
	# same answer the criterion would be met in letter and not in spirit: a player
	# told *no* cannot tell "somebody is inside" from "you just got out".
	_props.claim(FIRST, WELL, 0)
	_props.release(FIRST, 0)
	var too_soon := _props.may_enter(FIRST, WELL, 1)
	_props.claim(SECOND, WELL, 100)
	var occupied := _props.may_enter(FIRST, WELL, 100 + PropOccupancy.reentry_ticks())
	assert_eq(too_soon, BlendRefusal.Why.PROP_TOO_SOON)
	assert_eq(occupied, BlendRefusal.Why.PROP_OCCUPIED)
	assert_ne(too_soon, occupied, "two different problems give the same answer")
	assert_true(BlendRefusal.has_feedback(too_soon) and BlendRefusal.has_feedback(occupied))


func test_capacity_is_read_from_the_tunable() -> void:
	# Written as a literal `1` the class would agree with `TUN-BLEND-PROP-CAPACITY`
	# today and stop agreeing the moment somebody raised it, with nothing failing.
	assert_eq(
		PropOccupancy.capacity(),
		int(Tuning.suspicion.blend_prop_capacity),
		"the class does not read TUN-BLEND-PROP-CAPACITY"
	)
	assert_eq(PropOccupancy.capacity(), 1, "the shipped capacity is no longer one")


func test_a_player_may_hold_only_one_prop() -> void:
	_props.claim(FIRST, WELL, 0)
	_props.claim(FIRST, CART, 0)
	assert_eq(_props.occupied_count(), 2, "the fixture did not actually claim two")
	# Not a rule `PropOccupancy` enforces — `BlendSystem` never asks twice, because
	# a press while engaged is an exit. Asserted so the day somebody relies on the
	# opposite, this file says which layer owns it.
	assert_ne(_props.prop_of(FIRST), PropOccupancy.VACANT)


func test_leaving_locks_you_out_of_that_prop_and_no_other() -> void:
	# **`TUN-BLEND-PROP-EXIT-VULN` IS PER PROP, NOT PER PLAYER.** The window exists
	# to stop door-flickering on *one* prop to dodge a kill; a player who leaves
	# the well and runs to the hay cart is doing exactly what the design wants.
	_props.claim(FIRST, WELL, 50)
	_props.release(FIRST, 50)
	assert_eq(_props.may_enter(FIRST, WELL, 51), BlendRefusal.Why.PROP_TOO_SOON)
	assert_eq(_props.may_enter(FIRST, CART, 51), BlendRefusal.Why.TAKEN, "the lockout spread")


func test_the_window_expires_on_the_tick_it_names() -> void:
	_props.claim(FIRST, WELL, 50)
	_props.release(FIRST, 50)
	var back := 50 + PropOccupancy.reentry_ticks()
	assert_eq(_props.may_enter(FIRST, WELL, back - 1), BlendRefusal.Why.PROP_TOO_SOON, "early")
	assert_eq(_props.may_enter(FIRST, WELL, back), BlendRefusal.Why.TAKEN, "never expired")


func test_the_window_is_counted_in_net_ticks() -> void:
	# **TRAP 9.** `SYS-BLEND` resolves at the 30 Hz suspicion pass; `step_ticks`
	# would halve the window, and both numbers are plausible integers. The two
	# converters must disagree or this assertion proves nothing.
	assert_ne(
		Tuning.ticks(&"TUN-BLEND-PROP-EXIT-VULN"),
		Tuning.step_ticks(&"TUN-BLEND-PROP-EXIT-VULN"),
		"the two tick domains agree, so this test cannot tell them apart"
	)
	assert_eq(PropOccupancy.reentry_ticks(), Tuning.ticks(&"TUN-BLEND-PROP-EXIT-VULN"))


func test_someone_else_may_take_a_prop_you_are_locked_out_of() -> void:
	# The lockout is about you, not about the prop. Otherwise leaving would reserve
	# it for half a second, which is the opposite of a claimable resource.
	_props.claim(FIRST, WELL, 50)
	_props.release(FIRST, 50)
	assert_true(_props.claim(SECOND, WELL, 51), "leaving reserved the prop against everybody")


func test_a_departing_peer_does_not_take_a_hiding_spot_with_them() -> void:
	# **ENet REUSES PEER IDS**, and a prop left claimed by a peer that
	# disconnected is one nobody can ever enter again — a hiding spot that
	# silently vanishes from the map for the rest of the match.
	_props.claim(FIRST, WELL, 0)
	_props.forget(FIRST)
	assert_eq(_props.occupied_count(), 0, "the departed peer is still inside")
	assert_true(_props.claim(SECOND, WELL, 1), "the prop is still held by nobody")


func test_an_empty_registry_lets_everybody_in() -> void:
	# The state at the first tick of every match. A default that refused would make
	# all five hiding spots unusable until somebody had used them.
	for index: int in 5:
		assert_eq(_props.may_enter(FIRST, index, 0), BlendRefusal.Why.TAKEN, "prop %d" % index)
