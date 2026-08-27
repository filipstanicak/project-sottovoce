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
func _draw_cone(centre: Vector2) -> void:
	var half := deg_to_rad(Tuning.compass.cone_halfwidth)
	# Screen space puts +Y down and the cone points up at a bearing of zero.
	var aim := vm.cone_radians() - PI * 0.5
	var brightness: float = vm.cone_brightness()
	for i: int in CONE_STEPS:
		var t := (float(i) + 0.5) / float(CONE_STEPS)
		var angle := aim + lerpf(-half, half, t)
		# **SOFT EDGES.** Falls to zero at both rims; brightest along the aim.
		var across := 1.0 - absf(t - 0.5) * 2.0
		var alpha: float = palette.compass_cone.a * across * across * brightness
		var colour := Palette.with_alpha(palette.compass_cone, minf(alpha, 1.0))
		var step := (half * 2.0) / float(CONE_STEPS)
		_draw_slice(centre, angle, step, colour)


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
