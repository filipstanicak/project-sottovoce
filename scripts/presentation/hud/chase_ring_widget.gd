## **THE PURSUIT BARS, DRAWN.** UI_UX_SPEC §1.1 H, ADR-0014, US-0097. CLIENT ONLY.
##
## Two arcs concentric with the Compass, outside its lock arc. The inner one is the
## chase run **against you**; the outer one is the chase **you** are running.
##
## **A SEPARATE WIDGET RATHER THAN THREE MORE LINES IN `CompassWidget`, BECAUSE
## THE COMPASS DRAWS NOTHING WITHOUT A CONTRACT.** Its `_draw` returns early on
## `has_contract()`, and the most important moment this element has — a hunter
## about to lose you while you hold no contract of your own, or hold one you cannot
## see — is exactly the moment that early-out fires. Folding the bars in would have
## meant deleting a guard that is correct for the Compass.
##
## **THREE CHANNELS SEPARATE THE TWO BARS AND ONLY ONE OF THEM IS HUE**: radius,
## direction of travel, and colour. UI_UX_SPEC §7.3's rule for this corner of the
## screen is that the instrument stays readable on the monochrome verification
## palette, and it does — the two arcs are at different radii and wind opposite
## ways, so the colour is reinforcement rather than the carrier.
class_name ChaseRingWidget
extends Control

## **DERIVED FROM THE COMPASS'S OWN CONSTANTS, NEVER RE-CHOSEN.** The two elements
## must share a centre or the bars read as belonging to something else, and a
## second hand-written offset is a second number to keep in step.
const DIAMETER := 260.0

## Outside `CompassWidget.LOCK_RADIUS` (104) and its 3 px stroke, with a gap wide
## enough that a full lock and a full chase do not read as one thick ring.
const HUNTED_RADIUS := 112.0
const HUNT_RADIUS := 121.0
const WIDTH := 3.0

## The re-acquisition pulse thickens the bar rather than only brightening it, so
## the moment survives the monochrome palette too.
const FLASH_WIDTH := 3.0
const SEGMENTS := 64

## Both arcs begin at the top of the dial, which is where `CompassWidget`'s lock
## arc begins and where the cone's zero sits.
const TOP := -PI * 0.5

var vm: ChaseVm = null
var palette: Palette = null


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM, true)
	offset_left = -DIAMETER * 0.5
	offset_right = DIAMETER * 0.5
	var centre_up := compass_centre_from_bottom()
	offset_top = -(centre_up + DIAMETER * 0.5)
	offset_bottom = -(centre_up - DIAMETER * 0.5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How far above the screen's bottom edge the Compass's centre sits. **Public
## because it is the answer worth testing**: a test that re-derived it would agree
## with a widget that had drifted, which is `CompassWidget.screen_angle`'s lesson.
static func compass_centre_from_bottom() -> float:
	return CompassWidget.MARGIN_FROM_EDGE + CompassWidget.DIAMETER * 0.5


## **THE PULSE ADVANCES ON THE RENDER FRAME**, like the Compass's, so a 144 Hz and
## a 60 Hz client see the same cadence. And a quiet chase costs no redraw at all —
## most of a match has no pursuit in it, and a HUD that repaints anyway is the
## shape that makes an empty district cost frame time.
func _process(delta: float) -> void:
	if vm == null:
		return
	var was_quiet := vm.is_quiet() and vm.flash() <= 0.0
	vm.advance(delta)
	if not (was_quiet and vm.is_quiet() and vm.flash() <= 0.0):
		queue_redraw()


func _draw() -> void:
	if vm == null:
		return
	var centre := size * 0.5
	# **THE ONE RUN ANTICLOCKWISE IS THE ONE THAT IS NOT ABOUT YOUR CONTRACT.**
	# Your own chase drains the way the lock arc fills, because both are about the
	# Compass's one relationship; the chase on you unwinds the other way, so the two
	# are told apart by motion as well as by radius.
	if vm.is_hunted():
		_arc(centre, HUNTED_RADIUS, -vm.hunted, palette.chase_hunted, WIDTH + _flash_width())
	if vm.is_hunting():
		_arc(centre, HUNT_RADIUS, vm.hunting, palette.chase_hunt, WIDTH)


## A pulse thickens the bar the prey is reading, never the one they are not. The
## rise it marks is a fact about **their pursuer** re-acquiring them, and putting
## it on the hunter's own arc would say the opposite thing in the same shape.
func _flash_width() -> float:
	return FLASH_WIDTH * vm.flash()


## `fraction` is signed: positive winds clockwise from the top, negative
## anticlockwise. Both shrink toward the top as the bar empties, which is the
## convention a cooldown already uses and the reason neither needs a label.
func _arc(centre: Vector2, radius: float, fraction: float, colour: Color, width: float) -> void:
	draw_arc(centre, radius, TOP, TOP + TAU * fraction, SEGMENTS, colour, width, true)
