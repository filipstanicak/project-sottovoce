## **SUSPICION IS NOT A BROADCAST.** US-0055, GDD-03 §2.1, TDD-07 §4.1.
##
## The story's named test: one player at suspicion 100 must be `PLAIN` to four
## observers and `HARD` to their hunter and their prey. At six players that is
## **four of five observers seeing nothing**, which is what stops the match
## collapsing into everyone converging on whoever is currently visible.
##
## The rule is pure — `tier × relationship` — so it is exercised here with no
## world, no pawns and no contracts, and the system test beside it checks that the
## real pass reaches the same answers from a real cycle.
extends GutTest

const ANON := SuspicionMath.Tier.ANONYMOUS
const NOTICED := SuspicionMath.Tier.NOTICED
const EXPOSED := SuspicionMath.Tier.EXPOSED


func test_an_anonymous_subject_is_plain_to_everyone_including_their_hunter() -> void:
	# **THE FLOOR THE WHOLE ANONYMITY MODEL RESTS ON.** A hunter standing at
	# conversational distance behind an Anonymous player is told nothing at all.
	for hunts: bool in [false, true]:
		for hunted_by: bool in [false, true]:
			assert_eq(
				RenderState.of(ANON, hunts, hunted_by),
				RenderState.State.PLAIN,
				"an Anonymous subject was rendered for hunts=%s hunted_by=%s" % [hunts, hunted_by]
			)


func test_a_noticed_subject_is_tinted_to_their_hunter_only() -> void:
	assert_eq(
		RenderState.of(NOTICED, true, false), RenderState.State.TINTED, "the hunter sees no tint"
	)
	assert_eq(
		RenderState.of(NOTICED, false, false), RenderState.State.PLAIN, "a bystander saw the tint"
	)


func test_a_noticed_hunter_is_plain_to_their_own_prey() -> void:
	# **TDD-07 §9 QUESTION 1, ANSWERED `NO`.** A tint at Noticed would let prey
	# track a merely-Noticed hunter continuously, which makes the 15 m Compass
	# warning meaningless and hands prey a tracking tool. The prey's channel is the
	# warning; the tint belongs to the hunter.
	assert_eq(
		RenderState.of(NOTICED, false, true),
		RenderState.State.PLAIN,
		"a Noticed pursuer was rendered to their prey"
	)


func test_an_exposed_subject_is_hard_to_their_hunter_and_to_their_prey() -> void:
	# **EXPOSED CUTS BOTH WAYS.** Visible to your hunter, who can kill you more
	# easily, *and* to your prey, who is warned. One mechanic, two punishments.
	assert_eq(
		RenderState.of(EXPOSED, true, false), RenderState.State.HARD, "the hunter sees nothing"
	)
	assert_eq(RenderState.of(EXPOSED, false, true), RenderState.State.HARD, "the prey sees nothing")


func test_everyone_else_sees_plain_whatever_the_subject_is_doing() -> void:
	for tier: int in [ANON, NOTICED, EXPOSED]:
		assert_eq(
			RenderState.of(tier, false, false),
			RenderState.State.PLAIN,
			"a bystander saw a subject at tier %d" % tier
		)


func test_the_story_case_four_of_five_observers_see_nothing() -> void:
	# **THE SHAPE OF A SIX-PLAYER MATCH.** One player at 100. Their hunter, their
	# prey, and three strangers.
	var seen: Array = [
		RenderState.of(EXPOSED, true, false),  # the hunter
		RenderState.of(EXPOSED, false, true),  # the prey
		RenderState.of(EXPOSED, false, false),  # three strangers
		RenderState.of(EXPOSED, false, false),
		RenderState.of(EXPOSED, false, false),
	]
	var plain := 0
	for state: int in seen:
		if state == RenderState.State.PLAIN:
			plain += 1
	assert_eq(plain, 3, "%d of five observers saw an ordinary civilian, not three" % plain)
	assert_eq(seen[0], RenderState.State.HARD, "the hunter was not shown their contract")
	assert_eq(seen[1], RenderState.State.HARD, "the prey was not warned of a reckless pursuer")


func test_the_exposed_outline_is_the_only_thing_drawn_through_geometry() -> void:
	# GDD-03 §2.3's prohibition, expressed as a question the presentation layer has
	# to ask rather than a rule it has to remember.
	assert_true(RenderState.draws_through_geometry(RenderState.State.HARD), "the x-ray is gone")
	for state: int in [RenderState.State.PLAIN, RenderState.State.TINTED]:
		assert_false(RenderState.draws_through_geometry(state), "state %d became an x-ray" % state)


func test_plain_is_zero_and_the_field_fits_two_bits() -> void:
	# An unfilled record must decode as "nothing to see" rather than as a tint
	# somebody then has to explain — the reason `SlotTable` reserves slot 0 and
	# `BlendKind.NONE` is zero.
	assert_eq(RenderState.State.PLAIN, 0, "PLAIN is no longer the zero value")
	assert_true(RenderState.fits_the_wire(), "the render states no longer fit render_state:u2")


func test_the_matrix_defaults_to_plain_and_stores_only_what_is_not() -> void:
	var matrix := RenderMatrix.new()
	assert_eq(matrix.state_of(1, 2), RenderState.State.PLAIN, "an unrecorded pair was not PLAIN")
	matrix.set_state(1, 2, RenderState.State.PLAIN)
	assert_eq(matrix.marked_pairs(), 0, "PLAIN was stored")
	matrix.set_state(1, 2, RenderState.State.HARD)
	assert_eq(matrix.state_of(1, 2), RenderState.State.HARD, "a recorded pair was lost")
	assert_eq(matrix.state_of(2, 1), RenderState.State.PLAIN, "the matrix is symmetric — it is not")
	matrix.clear()
	assert_eq(matrix.marked_pairs(), 0, "the matrix survived a clear")
