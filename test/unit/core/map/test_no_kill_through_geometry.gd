## **IS THERE ANY GEOMETRY ON THIS MAP THIN ENOUGH TO KILL THROUGH?** ADR-0015.
##
## This is the measurement that decided the line-of-sight question, and it is kept
## because the answer is a property of `MAP-VETRAIO` and `TUN-KILL-RANGE`
## together — it changes if a stall is resized or the reach is retuned, which is
## exactly when somebody needs to re-read that ADR.
##
## **THE ANSWER IS YES, AND US-0054 PUT A BLEND SPOT ON EACH SIDE OF IT.** A market
## stall is 2.0 m deep and the two lean spots derived from it sit
## `NAV_AGENT_RADIUS` clear of each long face — **2.80 m apart, against a reach of
## 2.85 m.** So before ADR-0015, a player leaning on a stall could be killed by a
## hunter leaning on the other side of the same counter, through two metres of it.
extends GutTest

var _t: CombatTuning


func before_all() -> void:
	_t = Tuning.combat


## The closest two players can stand on opposite sides of an obstacle: its
## thinnest dimension plus a body's clearance on each face. **Raw thickness is the
## wrong question** — a player cannot stand inside the `NAV_AGENT_RADIUS` margin
## the navmesh and the lean spots both keep, so a 2.6 m wall holds bodies 3.4 m
## apart. Asking it the wrong way puts two walls on the list that do not belong.
func _across(w: float, d: float) -> float:
	return minf(w, d) + 2.0 * VetraioLayout.NAV_AGENT_RADIUS


func test_no_building_mass_is_thin_enough_to_kill_through() -> void:
	# **THE PREMISE, AND IT NEARLY WENT THE OTHER WAY.** The two Mercato west walls
	# are **2.6 m** thick — thinner than the 2.85 m reach — and are excluded only by
	# the clearance, at 3.40 m against 2.85. They are also the masses GDD-05 §2.7
	# rule 6 leans on to occlude `S2`-`S5`, so a thinner version of them would put a
	# kill straight through the thing built to stop a sightline.
	var worst := INF
	var worst_who := ""
	for row: Array in VetraioLayout.BLOCKS:
		var across := _across(float(row[3]), float(row[4]))
		if across < worst:
			worst = across
			worst_who = str(row[0])
	gut.p(
		(
			"closest across a mass: %.2f m at %s; kill reach %.2f m"
			% [worst, worst_who, KillRules.reach(_t)]
		)
	)
	assert_gt(worst, KillRules.reach(_t), "%s is thin enough to kill through" % worst_who)


func test_the_two_lean_spots_on_a_stall_are_within_kill_reach() -> void:
	# The finding itself. Six stalls, twelve spots, six facing pairs.
	var spots := VetraioGround.stall_lean_points()
	assert_eq(spots.size(), 12, "the lean spots moved; this measurement is about the old ones")
	var pairs := 0
	var closest := INF
	for i: int in spots.size():
		for j: int in range(i + 1, spots.size()):
			var a := Vector3(float(spots[i][1]), 0.0, float(spots[i][2]))
			var b := Vector3(float(spots[j][1]), 0.0, float(spots[j][2]))
			if not KillRules.in_reach(a, b, _t):
				continue
			pairs += 1
			closest = minf(closest, a.distance_to(b))
	gut.p("lean-spot pairs inside kill reach: %d, closest %.2f m" % [pairs, closest])
	assert_eq(pairs, 6, "one facing pair per stall was expected")
	assert_lt(closest, KillRules.reach(_t), "the pair is no longer inside reach")


func test_the_margin_is_five_centimetres_and_that_is_the_point() -> void:
	# **IT IS NOT A COMFORTABLE MARGIN, WHICH IS WHY A GEOMETRY GATE RATHER THAN A
	# TUNING NUDGE.** Shrinking `TUN-KILL-RANGE` until the pair falls outside reach
	# would close this one case by 5 cm and change every kill in the game to do it,
	# and the next thin prop would reopen it. ADR-0015 gates on sight instead.
	var across := _across(float(VetraioLayout.STALLS[0][3]), float(VetraioLayout.STALLS[0][4]))
	var margin := KillRules.reach(_t) - across
	gut.p(
		"across a stall %.2f m, reach %.2f m, margin %.3f m" % [across, KillRules.reach(_t), margin]
	)
	assert_gt(margin, 0.0, "the case closed by itself; re-read ADR-0015 before relying on that")
	assert_lt(margin, 0.5, "the margin grew; the measurement in ADR-0015 is stale")
