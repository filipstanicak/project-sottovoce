## **NO FLOOR EDGE IS LEFT OPEN, WHICH IS WHAT MAKES THE MID-AIR STOP
## UNREACHABLE.** GDD-02 §7.2, GDD-05 §2.1, US-0041, US-0093.
##
## The owner reported a jump stopping in mid-air at the lip of the void, and the
## chain is real: the probes find no floor within `TUN-TRAVERSE-GAP-PROBE-DEPTH`,
## `drop_height` comes back `INF`, `_plan_drop` invents a landing at the probe
## depth, and `DropState` grounds the pawn there at rest.
##
## **THE DECISION WAS THAT NO BEHAVIOUR CHANGES, AND THIS IS THE CONDITION THAT
## DECISION RESTS ON.** Two things together make the case unreachable:
##
## 1. **Every legitimate fall is measurable.** Invariant 24 pins
##    `TUN-TRAVERSE-GAP-PROBE-DEPTH` at or above `TUN-TRAVERSE-CLIMB-MAX-HEIGHT`,
##    and `MAP-VETRAIO`'s tallest façade is 8.5 m. Anything you can climb down, the
##    probes can see the bottom of.
## 2. **Every edge that is not a fall is fenced.** So `INF` can only mean a true
##    void, and no void is reachable on foot.
##
## **THE SECOND ONE WAS AN ASSUMPTION UNTIL THIS FILE.** "It cannot happen in the
## finished map" is exactly the kind of claim that stops being true quietly — the
## day someone adds a plaza, a balcony or a jetty and its outward edge is open. The
## defect then returns as a player stopping in mid-air, which reads as a netcode
## fault and not as a level one.
extends GutTest

## Finer than `VetraioGround.EDGE_STEP`, so a gap left between two runs of parapet
## by the derivation's own merging would be caught rather than stepped over.
const SAMPLE := 0.5


func test_every_floor_edge_is_floor_block_or_parapet() -> void:
	var parapets := VetraioGround.parapets()
	assert_gt(
		parapets.size(), 0, "no parapets at all — the district is unfenced or the derivation broke"
	)

	var open: PackedStringArray = []
	var sampled := 0
	for row: Array in VetraioGround.street_floors():
		var r := VetraioGround.rect_of(row)
		for side: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			sampled += _walk_side(str(row[0]), r, side, parapets, open)

	gut.p("sampled %d points along every street-level floor edge" % sampled)
	assert_gt(sampled, 400, "almost nothing was sampled — the floor table or the walk moved")
	assert_eq(
		open.size(),
		0,
		(
			"an edge borders neither floor, block nor parapet, so a pawn can walk off it into a "
			+ "fall the probes cannot measure — which is planned to an invented landing and "
			+ "stops the pawn in mid-air (test_traverse_into_the_void.gd):\n"
			+ "\n".join(open)
		)
	)


## One side of one floor. Returns how many points it checked, appending any that
## are open to `open`.
func _walk_side(
	who: String, r: Rect2, side: Vector2, parapets: Array, open: PackedStringArray
) -> int:
	var along_x := absf(side.y) > 0.5
	var from := r.position.x if along_x else r.position.y
	var to := r.end.x if along_x else r.end.y
	var edge := (
		(r.position.y if side.y < 0.0 else r.end.y)
		if along_x
		else (r.position.x if side.x < 0.0 else r.end.x)
	)
	var checked := 0
	var at := from + SAMPLE * 0.5
	while at < to:
		checked += 1
		# Just outside the edge: is there ground or masonry there?
		var beyond := (
			Vector2(at, edge + side.y * VetraioGround.EDGE_PROBE)
			if along_x
			else Vector2(edge + side.x * VetraioGround.EDGE_PROBE, at)
		)
		if not VetraioGround.on_a_floor(beyond) and VetraioGround.block_at(beyond) == "":
			# Then a parapet must occupy the strip immediately outside it.
			var inside_wall := (
				Vector2(at, edge + side.y * VetraioGround.PARAPET_THICKNESS * 0.5)
				if along_x
				else Vector2(edge + side.x * VetraioGround.PARAPET_THICKNESS * 0.5, at)
			)
			if not _fenced(inside_wall, parapets):
				open.append("  %s at (%.1f, %.1f)" % [who, inside_wall.x, inside_wall.y])
		at += SAMPLE
	return checked


func _fenced(at: Vector2, parapets: Array) -> bool:
	for w: Array in parapets:
		if Rect2(float(w[1]), float(w[2]), float(w[3]), float(w[4])).has_point(at):
			return true
	return false


## **AND THE OTHER HALF OF THE CONDITION**, asserted here so the two live together:
## a fall you can survive is a fall the probes can measure. Invariant 24 owns this;
## it is repeated because it is the reason the paragraph above is true.
func test_every_climbable_height_is_measurable() -> void:
	assert_gte(
		Tuning.movement.gap_probe_depth,
		Tuning.movement.traverse_climb_max_height,
		(
			"the probes cannot see the bottom of the tallest climb, so a legitimate descent "
			+ "would resolve as an unmeasured fall and be planned to an invented landing"
		)
	)
