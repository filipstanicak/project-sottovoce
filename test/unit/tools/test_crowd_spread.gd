## **THE CROWD CENSUS, CHECKED ON FRAMES WHOSE ANSWER IS KNOWN.** US-0103.
##
## The review of #237 found the first version separating strollers from processions
## in only one of its two figures. The first two tests are the reviewer's two
## counterexamples; each reddens with its half of the fix removed.
extends GutTest

const SPREAD := preload("res://tools/crowd_spread.gd")
const STROLL := 1
const GROUP := 2
const IDLE := 0
const DT := 0.5


## One frame: `{index: [position, state]}`.
func _frame(entries: Dictionary) -> Dictionary:
	return entries


func test_a_state_change_is_booked_to_neither_state() -> void:
	# A stroller that walked 0.7 m and was IDLE by the second sample.
	var before := _frame({7: [Vector3.ZERO, STROLL]})
	var now := _frame({7: [Vector3(0.7, 0.0, 0.0), IDLE]})
	var moving := SPREAD.walkers(before, now, DT)
	assert_false(moving.has(7), "a walk straddling STROLL -> IDLE was booked to IDLE")


func test_a_stroller_beside_a_procession_has_no_same_state_company() -> void:
	# One stroller and one procession member, side by side, heading the same way.
	var before := _frame({1: [Vector3.ZERO, STROLL], 2: [Vector3(1.0, 0.0, 0.0), GROUP]})
	var now := _frame({1: [Vector3(0.0, 0.0, 0.7), STROLL], 2: [Vector3(1.0, 0.0, 0.7), GROUP]})
	var moving := SPREAD.walkers(before, now, DT)
	assert_false(
		SPREAD.has_company(1, moving, true),
		"a procession member counted as a stroller's same-state company"
	)
	assert_true(
		SPREAD.has_company(1, moving, false),
		"the any-state figure must still see the procession member beside the stroller"
	)


func test_two_strollers_side_by_side_are_company() -> void:
	var before := _frame({1: [Vector3.ZERO, STROLL], 2: [Vector3(1.0, 0.0, 0.0), STROLL]})
	var now := _frame({1: [Vector3(0.0, 0.0, 0.7), STROLL], 2: [Vector3(1.0, 0.0, 0.7), STROLL]})
	var moving := SPREAD.walkers(before, now, DT)
	assert_true(SPREAD.has_company(1, moving, true), "two strollers abreast read as alone")


func test_walkers_heading_apart_are_not_company() -> void:
	var before := _frame({1: [Vector3.ZERO, STROLL], 2: [Vector3(1.0, 0.0, 0.0), STROLL]})
	var now := _frame({1: [Vector3(0.0, 0.0, 0.7), STROLL], 2: [Vector3(1.0, 0.0, -0.7), STROLL]})
	var moving := SPREAD.walkers(before, now, DT)
	assert_false(SPREAD.has_company(1, moving, true), "opposite headings counted as company")


func test_standing_is_not_walking() -> void:
	var before := _frame({1: [Vector3.ZERO, STROLL]})
	var now := _frame({1: [Vector3(0.1, 0.0, 0.0), STROLL]})
	assert_true(SPREAD.walkers(before, now, DT).is_empty(), "0.2 m/s was counted as walking")


func test_the_tally_keeps_the_two_company_figures_apart() -> void:
	var a := _frame({1: [Vector3.ZERO, STROLL], 2: [Vector3(1.0, 0.0, 0.0), GROUP]})
	var b := _frame({1: [Vector3(0.0, 0.0, 0.7), STROLL], 2: [Vector3(1.0, 0.0, 0.7), GROUP]})
	var t := SPREAD.tally([a, b], DT, STROLL)
	assert_eq(int(t["walking"].get(STROLL, 0)), 1, "the stroller's walk was not counted")
	assert_eq(int(t["same"].get(STROLL, 0)), 0, "same-state company counted a procession")
	assert_eq(int(t["any"].get(STROLL, 0)), 1, "any-state company missed the procession")


func test_a_lane_needs_five_different_strollers() -> void:
	var frames: Array = []
	for step: int in 3:
		var frame := {}
		for index: int in 5:
			frame[index] = [Vector3(0.5, 0.0, 0.2 + 0.7 * step), STROLL]
		frames.append(frame)
	var t := SPREAD.tally(frames, DT, STROLL)
	assert_gt(SPREAD.shared_lane_share(t), 0.0, "five strollers through one cell made no lane")
	var lone := SPREAD.tally(
		frames.map(func(f: Dictionary) -> Dictionary: return {0: f[0]}), DT, STROLL
	)
	assert_eq(SPREAD.shared_lane_share(lone), 0.0, "one stroller alone made a shared lane")
