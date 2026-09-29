## **THE COMPASS RING CIRCLES THE PAWN'S LEGS AT THE RESTING FRAMING.** US-0105,
## UI_UX_SPEC §1.1 A, owner decision of 2026-09-29.
##
## The ring is fixed on screen (`CompassWidget.CENTRE_HEIGHT`) and the figure is
## wherever the camera puts it, so the two are only related through
## `TUN-CAM-REST-PITCH`, the arm and the lens. **The first version of US-0105 tested
## the anchor and the flattening and called the result "at the feet"**; the review of
## #243 rendered it and found the ring round the thighs. The reference's ring circles
## its figure's legs too — about 40 % of the figure above the feet, measured from its
## recordings (sources in the chat log) — and the owner kept that spot. So what is
## held here is the relation, projected with the rig's own arithmetic: above the feet,
## below the hips.
extends GutTest

const FEET := Vector3.ZERO

## Where the ring's centre may sit, as a share of the figure's height above its feet.
## Zero would be the feet and a half the hips; the reference measures about 0.40.
const LOWEST := 0.2
const HIGHEST := 0.5


## Where `point` lands on screen, as a fraction of the frame's height from the top,
## for the rig at rest behind `FEET` at the default lens. Godot's `fov` is vertical.
static func screen_height_of(point: Vector3) -> float:
	var pitch := CameraArm.view_pitch(0.0, deg_to_rad(70.0))
	var camera := CameraArm.ideal_position(FEET, 0.0, pitch)
	var view := (CameraArm.pivot(FEET) - camera).normalized()
	var to := (point - camera).normalized()
	var below := asin(clampf(-to.y, -1.0, 1.0)) - asin(clampf(-view.y, -1.0, 1.0))
	var half := deg_to_rad(CameraFov.default_fov()) * 0.5
	return 0.5 + 0.5 * tan(below) / tan(half)


## The ring's centre as a share of the figure's height above its feet.
static func share_above_feet(centre: float) -> float:
	var feet := screen_height_of(FEET)
	var head := screen_height_of(FEET + Vector3.UP * PawnNavigation.NAV_AGENT_HEIGHT)
	return (feet - centre) / (feet - head)


func test_the_figure_is_where_the_measurement_says() -> void:
	# **THE PREMISE**, against the client screenshot: head ~42 %, feet ~97 %. This
	# projection reads 0.417 and 0.944 — the tolerance covers both, and a projection
	# outside it would make the test below about arithmetic rather than the screen.
	assert_almost_eq(
		screen_height_of(FEET), 0.97, 0.03, "the feet are not where the client drew them"
	)
	var head := screen_height_of(FEET + Vector3.UP * PawnNavigation.NAV_AGENT_HEIGHT)
	assert_almost_eq(head, 0.42, 0.03, "the head is not where the client drew it")


func test_the_ring_circles_the_legs() -> void:
	var share := share_above_feet(CompassWidget.CENTRE_HEIGHT)
	gut.p("ring centre at %.2f of the figure above its feet (the reference: ~0.40)" % share)
	assert_gt(share, LOWEST, "the ring is at the feet, below the reference's spot on the legs")
	assert_lt(share, HIGHEST, "the ring is above the hips — it no longer circles the legs")


func test_the_check_can_actually_fail() -> void:
	# The bounds must reject both ways of moving the ring off the legs.
	assert_lt(share_above_feet(screen_height_of(FEET)), LOWEST, "a ring at the feet passed")
	var hips := screen_height_of(FEET + Vector3.UP * PawnNavigation.NAV_AGENT_HEIGHT * 0.6)
	assert_gt(share_above_feet(hips), HIGHEST, "a ring at the chest passed")
