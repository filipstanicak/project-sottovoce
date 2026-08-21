## **A TRAVERSAL PLANNED TO A LANDING THAT DOES NOT EXIST.** GDD-02 §7.2, US-0093,
## US-0041.
##
## Reported from the controls: *"when i am at a edge into the abyss and move towards
## it and jump, my jump stops mid air so that my speed goes down to 0 m/s"*.
##
## **IT IS NOT US-0093's DEFECT COMING BACK.** That one was a held Space arming a
## fresh traverse sixty times a second, fixed by arming on the press. This one
## happens on a single press, and it is the whole chain below.
##
## 1. The probes find no floor within `TUN-TRAVERSE-GAP-PROBE-DEPTH`, so
##    `drop_height` is `INF` — the game refusing to answer.
## 2. `_over_the_edge` classifies it `DROP`, which is **§7.2 case 3 as written** and
##    is not in doubt: "no landing within range resolves to Drop".
## 3. `_plan_drop` calls `_finite()`, which substitutes the probe depth for the
##    missing number and **invents a landing ten metres down**.
## 4. `DropState.enter` zeroes velocity, `step` interpolates to that target, and
##    then sets `grounded = true` **at a point in mid-air**, where the pawn stays.
##
## **THE RESOLVER ALREADY ARGUES WITH ITSELF ABOUT STEP 3.** `_over_the_edge`'s
## docstring says a fall the probes cannot measure "is not planned at all" and that
## substituting the depth "set the pawn down in mid-air at exactly that depth";
## `_finite` thirty lines below still does it, under a comment defending it.
##
## **AND THE DECISION WAS THAT NOTHING CHANGES, WHICH IS WHY THIS STILL PASSES.**
## The owner asked whether a fix is needed at all given the shipped district has no
## abyss, and it is not, because the case is **unreachable by construction**:
##
## 1. Invariant 24 pins `TUN-TRAVERSE-GAP-PROBE-DEPTH` at or above
##    `TUN-TRAVERSE-CLIMB-MAX-HEIGHT`, and the tallest façade is 8.5 m — so every
##    fall you can take legitimately is one the probes can measure, and `INF` can
##    only mean a true void.
## 2. **No void is reachable on foot**: every street-level floor edge borders floor,
##    building mass or parapet. That was an assumption until
##    `test_the_district_is_enclosed.gd`, which samples 2574 points along every edge
##    and fires on 1303 of them if the fencing is removed.
##
## **THE BEHAVIOUR IS STILL WRONG AND IS DELIBERATELY LEFT.** Fixing it means either
## amending §7.2 case 3 — which `test_edges_that_are_steps.gd` asserts on purpose —
## or giving the pawn a state that **falls under gravity** rather than interpolating
## to a plan, which it does not have because every traversal here is a planned arc
## that discards momentum. Neither is worth doing for a case the level cannot reach.
## This file asserts what the code does today so that a future change to §7.2, to
## the probe depth, or to the fencing surfaces it rather than a player finding it.
extends GutTest


## A pawn at the lip of the void: ground underfoot, nothing ahead, nothing below
## within the probes' reach.
func _at_the_abyss() -> ProbeResult:
	var probe := ProbeResult.new()
	probe.valid = true
	probe.has_hit = false
	probe.foot_clear = true
	probe.ground_ahead = false
	probe.gap_distance = INF
	probe.drop_height = INF
	return probe


func _context() -> PawnContext:
	var ctx := PawnContext.new()
	ctx.position = Vector3(60.0, 0.0, 30.0)
	ctx.yaw = 0.0
	ctx.probe_result = _at_the_abyss()
	return ctx


## **THE GUARD AGAINST VACUOUS SUCCESS COMES FIRST.** If the resolver refused every
## case, the finding below would hold for the wrong reason. A measurable ledge must
## still resolve and still be planned where the probes actually found ground.
func test_a_measurable_ledge_is_still_planned_where_the_ground_is() -> void:
	var ctx := _context()
	ctx.probe_result.drop_height = 1.5
	var case := TraversalResolver.classify(ctx)
	assert_eq(case, TraversalResolver.Case.DROP, "a real ledge stopped resolving to a drop")
	TraversalResolver.plan(ctx, case)
	assert_almost_eq(
		ctx.traverse_target.y, ctx.position.y - 1.5, 0.01, "a measurable drop was not planned to it"
	)


## The behaviour, asserted as it is so a change to it cannot pass unnoticed.
func test_an_unmeasured_fall_is_planned_to_an_invented_landing() -> void:
	var ctx := _context()
	var case := TraversalResolver.classify(ctx)
	TraversalResolver.plan(ctx, case)
	var invented := ctx.position.y - Tuning.movement.gap_probe_depth
	assert_eq(case, TraversalResolver.Case.DROP, "§7.2 case 3 changed; re-read this file")
	assert_true(
		is_equal_approx(ctx.traverse_target.y, invented),
		(
			"the invented landing is gone, which means the behaviour changed. That is fine, but "
			+ "this file and `test_edges_that_are_steps.gd` both describe the old one — read "
			+ "them before deleting either."
		)
	)
	gut.p(
		(
			(
				"an edge with no floor below is planned to a landing %.1f m down that the probes "
				% Tuning.movement.gap_probe_depth
			)
			+ "never found; DropState zeroes velocity, interpolates to it and grounds the pawn "
			+ "there. Unreachable while the district stays enclosed — see "
			+ "test_the_district_is_enclosed.gd. Deliberately left."
		)
	)
