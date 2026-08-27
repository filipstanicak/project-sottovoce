## **THE COMPASS, DRAWN.** UI_UX_SPEC §3, US-0072. CLIENT ONLY.
##
## A pure renderer: it reads `CompassVm` and nothing else, has no `get_node` out of
## its own subtree (never-do #7), and holds no state a reload would lose. Every
## number it decides is a *pixel*; every number that means something comes from the
## view model.
##
## **THE CONE HAS SOFT EDGES BECAUSE THE READING IS IMPRECISE.** §3.1: *never a
## hard-edged needle*. The bearing carries `TUN-COMPASS-CONE-WOBBLE`'s deliberate
## lie, and a crisp needle would draw an uncertain value as a certain one — the
## widget would be telling a different story from the instrument.
##
## **AND NOTHING IS ENCODED IN HUE.** Distance is cadence, direction is position,
## lock is arc fill. UI_UX_SPEC §7.3 keeps the Compass readable on all four
## palettes by never asking colour to carry meaning in the first place, which is
## cheaper and more robust than picking colourblind-safe hues.
class_name CompassWidget
extends Control

## §3.1. Layout constants rather than tunables: changing them changes where a thing
## sits, not how the game plays. The spec is the source and is cited per line.
const DIAMETER := 220.0
const MARGIN_FROM_EDGE := 64.0

const CONE_INNER := 34.0
const CONE_OUTER := 96.0
const CONE_STEPS := 24
const MAX_CONE_STEPS := 144
const SLICE_DEGREES := 2.5
const RING_RADIUS := 30.0
const RING_WIDTH := 2.5
const LOCK_RADIUS := 104.0
const LOCK_WIDTH := 3.0
const DOT_RADIUS := 3.0

var vm: CompassVm = null

## **UI_UX_SPEC §7: no widget names a colour literal.** That rule named
## `test_no_colour_literals.gd` as its enforcement and **neither the guard nor the
## `Palette` resource existed**, which is why this file shipped four literals in
## US-0072. Both exist now and this reads from the palette like everything else.
var palette: Palette = null


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	# Centre-bottom, `MARGIN_FROM_EDGE` above the screen edge. Anchored rather than
	# positioned, so it stays put at any resolution.
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM, true)
	offset_left = -DIAMETER * 0.5
	offset_right = DIAMETER * 0.5
	offset_top = -(DIAMETER + MARGIN_FROM_EDGE)
	offset_bottom = -MARGIN_FROM_EDGE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## **THE PHASE ADVANCES ON THE RENDER FRAME, WHICH IS THE POINT.** §3.2: a 144 Hz
## and a 60 Hz client must see the same cadence, smoothed differently. Advancing it
## on the physics tick would quantise the beat to 30 Hz and make the instrument
## coarser on better hardware.
func _process(delta: float) -> void:
	if vm == null:
		return
	if vm.advance(delta):
		EventBus.compass_pulsed.emit()
	queue_redraw()


func _draw() -> void:
	if vm == null or not vm.has_contract():
		return
	var centre := size * 0.5
	_draw_cone(centre)
	_draw_pulse_ring(centre)
	_draw_lock_arc(centre)
	draw_circle(centre, DOT_RADIUS, palette.compass_dot)


## A filled arc whose alpha falls off toward both edges, so the cone fades out
## rather than ending. Drawn as radial slices because a gradient across an angle is
## not something `draw_*` offers directly.
##
## **THE WIDTH IS THE VIEW MODEL'S, NOT A TUNABLE READ HERE.** It grows as the
## contract closes and reaches a whole ring at `CompassMath.full_ring_distance` —
## the reference's own behaviour, and the fix for a fixed-angle arc that spanned
## barely more than one body at kill reach. §3.1.
func _draw_cone(centre: Vector2) -> void:
	var half := vm.cone_halfwidth()
	var aim := screen_angle()
	var brightness: float = vm.cone_brightness()
	var steps := _slices_for(half)
	var step := (half * 2.0) / float(steps)
	for i: int in steps:
		var t := (float(i) + 0.5) / float(steps)
		var across := 1.0 - absf(t - 0.5) * 2.0
		var alpha: float = palette.compass_cone.a * _edge(across, half) * brightness
		var colour := Palette.with_alpha(palette.compass_cone, minf(alpha, 1.0))
		_draw_slice(centre, aim + lerpf(-half, half, t), step, colour)


## **WHERE ON THE DIAL THE CONE IS DRAWN, AND TWO SIGN CONVENTIONS MEET HERE.**
##
## `cone_radians()` is the world's: this game's yaw increases toward a turn to the
## **left** on screen (`InputSampler` subtracts the mouse's x, and
## `ProbeLayout.right` is `forward × up` = −X at yaw 0). A screen angle increases
## **clockwise**, because +Y is down. So the two run opposite ways and the drawn
## angle is the negative of the relative bearing, with a quarter turn to put zero
## at the top of the dial.
##
## **IT SHIPPED WITHOUT THIS AND WITHOUT `HudRoot`'s HALF TURN, AND THE TWO ERRORS
## PARTLY CANCELLED** — which is why it survived a review and a probe. Composed,
## they are a front-to-back flip: a contract at either shoulder drew **correctly**
## and one dead ahead drew at the bottom of the dial. The owner reported exactly
## that. **A defect that is right at two of four cardinal points is worse than one
## that is wrong at all of them**, because it looks like an instrument that works.
##
## **PUBLIC BECAUSE IT IS THE ANSWER WORTH TESTING.**
## `test_the_cone_points_at_the_contract.gd` asks the widget itself rather than
## re-deriving this line — a test that recomputed it would agree with a widget that
## was wrong.
func screen_angle() -> float:
	return -vm.cone_radians() - PI * 0.5


## **SOFT EDGES, AND THE FALLOFF FLATTENS AS THE ARC OPENS.** §3.1 forbids a
## hard-edged needle in as many words — *"the visual must communicate
## imprecision"* — and this was `across * across`, which put four fifths of a 24°
## cone below a quarter alpha and drew a sliver. `sqrt` keeps the edges soft and
## lets the full width read.
##
## **AND AN EDGE ONLY MEANS SOMETHING WHILE THERE IS ONE.** At a full ring every
## direction is equally possible, so a falloff would draw the one reading that
## carries no direction as though it still had a front and a back. The blend is the
## width itself: pure falloff at the narrow end, uniform at 180°.
func _edge(across: float, half: float) -> float:
	return lerpf(sqrt(across), 1.0, clampf(half / PI, 0.0, 1.0))


## Slices are kept to a roughly constant angular size, so a ring three times the
## width of a cone is not drawn three times coarser. `CONE_STEPS` is the count at
## the narrow end and the floor.
func _slices_for(half: float) -> int:
	var wanted := int(ceil(rad_to_deg(half * 2.0) / SLICE_DEGREES))
	return clampi(wanted, CONE_STEPS, MAX_CONE_STEPS)


func _draw_slice(centre: Vector2, angle: float, step: float, colour: Color) -> void:
	var a := Vector2.from_angle(angle - step * 0.5)
	var b := Vector2.from_angle(angle + step * 0.5)
	var points := PackedVector2Array(
		[
			centre + a * CONE_INNER,
			centre + a * CONE_OUTER,
			centre + b * CONE_OUTER,
			centre + b * CONE_INNER,
		]
	)
	draw_colored_polygon(points, colour)


## Scale eases out, alpha eases in — the onset is the sharp event. `CompassVm`
## owns both curves; this only draws what they return.
func _draw_pulse_ring(centre: Vector2) -> void:
	var colour := Palette.with_alpha(palette.compass_ring, vm.ring_alpha())
	draw_arc(centre, RING_RADIUS * vm.ring_scale(), 0.0, TAU, 48, colour, RING_WIDTH, true)


## Fills **clockwise from the top**, 0 → 360° over `TUN-COMPASS-LOCK-FILL-TIME`.
func _draw_lock_arc(centre: Vector2) -> void:
	if vm.lock <= 0.0:
		return
	var from := -PI * 0.5
	draw_arc(
		centre, LOCK_RADIUS, from, from + TAU * vm.lock, 64, palette.compass_lock, LOCK_WIDTH, true
	)
