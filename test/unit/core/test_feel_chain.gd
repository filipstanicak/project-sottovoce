## The feel chain, and the tripwire that finishes it. GDD-02 §5, US-0024.
##
## **THIS FILE CONTAINS A TEST DESIGNED TO FAIL LATER.** `test_the_animation_stage_is_still_blocked`
## passes only while there are no animation clips. The day someone adds an
## `AnimationPlayer` to the pawn, it goes red and says what to do — which is the
## point. US-0024's first three criteria cannot be met today, and the choice was
## between a note in a document nobody re-reads and a build failure at the exact
## moment the blocker lifts.
##
## The same reasoning is why `FeelChain` exists at all. A harness that measured
## three stages of five and printed "42 ms, within budget" would be stating
## something false in a form that reads as authoritative.
extends GutTest

const PAWN_SCENES: Array[String] = [
	"res://scenes/pawn/pawn_local.tscn",
	"res://scenes/pawn/pawn_server.tscn",
]

# ------------------------------------------------------------- the arithmetic --


func test_ticks_convert_at_the_input_rate_not_the_net_tick() -> void:
	# Trap 9, in the one place where getting it wrong is least visible: 33 ms is
	# exactly as plausible a latency reading as 16, and nothing about the number
	# says which rate produced it.
	assert_almost_eq(FeelChain.ms_for_ticks(1), 1000.0 / 60.0, 0.001)
	assert_almost_eq(Tuning.net.client_input_rate, 60.0, 0.001)
	assert_almost_eq(FeelChain.ms_for_ticks(6), 100.0, 0.001)


func test_the_budget_is_the_tunable() -> void:
	assert_almost_eq(FeelChain.budget_ms(), Tuning.movement.input_to_anim_max, 0.001)
	assert_almost_eq(Tuning.movement.input_to_anim_max, 80.0, 0.001)


func test_the_budget_is_a_fifth_of_the_contest_window() -> void:
	# §5's actual argument, asserted rather than quoted. The game is decided at
	# 2.5 m inside TUN-KILL-CONTEST-WINDOW; if that window were ever retuned, an
	# 80 ms budget would stop meaning what the design says it means.
	var window_ms := Tuning.combat.kill_contest_window * 1000.0
	assert_almost_eq(FeelChain.budget_ms() / window_ms, 0.2, 0.02)


func test_a_reading_over_the_ceiling_is_rejected() -> void:
	assert_true(FeelChain.within_budget(FeelChain.budget_ms()))
	assert_false(FeelChain.within_budget(FeelChain.budget_ms() + 0.1))


# --------------------------------------------------------------- the coverage --


func test_three_stages_are_measurable_and_two_are_not() -> void:
	assert_eq(FeelChain.measured().size(), 3, "the measurable stage count changed")
	assert_eq(FeelChain.unmeasured().size(), 2)
	assert_eq(FeelChain.measured().size() + FeelChain.unmeasured().size(), FeelChain.STAGES.size())


func test_every_unmeasured_stage_says_what_blocks_it() -> void:
	# "Not measured" with no reason is indistinguishable from "forgotten".
	for stage: Dictionary in FeelChain.unmeasured():
		assert_gt(
			String(stage["blocked_by"]).length(),
			20,
			"%s is unmeasured with no useful reason" % FeelChain.Stage.keys()[int(stage["stage"])]
		)


func test_the_coverage_note_names_what_is_missing() -> void:
	# It is printed beside every number the harness reports. A reading quoted
	# without it will be read as the whole chain.
	var note := FeelChain.coverage_note()
	assert_string_contains(note, "ANIMATE")
	assert_string_contains(note, "PRESENT")
	assert_string_contains(note, "3 of 5")


# ------------------------------------------------------------------ the tripwire --


func test_the_animation_stage_is_still_blocked() -> void:
	# **WHEN THIS FAILS, DO NOT DELETE IT — FINISH THE HARNESS.**
	#
	# The pawn scenes carry no AnimationPlayer and no AnimationTree, so there is
	# no pose for input to change and nothing for the ANIMATE stage to observe.
	# US-0024 criteria 1 and 2 stay unticked for exactly this reason.
	#
	# The moment a clip lands, this test goes red. What it is asking for:
	#   1. Measure the ANIMATE stage in test/integration/test_feel_latency.gd.
	#   2. Clear its `blocked_by` in FeelChain.STAGES.
	#   3. Tick US-0024's criteria 1 and 2 — if, and only if, the number is real.
	var found: PackedStringArray = []
	for path: String in PAWN_SCENES:
		var source := SourceScanner.read(path)
		if source.contains("AnimationPlayer") or source.contains("AnimationTree"):
			found.append(path)
	assert_eq(
		found.size(),
		0,
		(
			"An animation node exists now, so the ANIMATE stage is measurable:\n  "
			+ "\n  ".join(found)
			+ "\nFinish the harness and clear ANIMATE's blocked_by in FeelChain — "
			+ "do not delete this test."
		)
	)


func test_the_chain_agrees_with_itself_about_what_is_blocked() -> void:
	# The tripwire above reads the scenes; FeelChain declares the state of play.
	# If they ever disagree, one of them is lying about the same fact.
	var animate: Dictionary = FeelChain.STAGES[FeelChain.Stage.ANIMATE]
	assert_false(
		String(animate["blocked_by"]).is_empty(),
		"FeelChain says ANIMATE is measured — then the harness must measure it"
	)
	assert_string_contains(String(animate["blocked_by"]), "animation clips")
