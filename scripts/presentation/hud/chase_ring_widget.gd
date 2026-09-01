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
## **FOUR CHANNELS SEPARATE THEM AND ONLY ONE IS HUE**: radius, weight, direction
## of travel, and colour. UI_UX_SPEC §7.3's rule for this corner of the screen is
## that the instrument stays readable on the monochrome verification palette.
##
## **DIRECTION ONLY SEPARATES THEM IN MOTION, WHICH LOOKING AT IT IS WHAT FOUND.**
## A still frame shows an arc with a gap in it; which way it wound is not
## recoverable from the picture, only from watching it move. So the weight was
## added as the channel that works in a frozen frame **and** in monochrome, and the
## claim that direction is one of three was narrowed rather than left standing.
##
## **THE HUNTED BAR IS THE HEAVIER OF THE TWO, WHICH IS A DESIGN CALL AND NOT A
## TWEAK.** A hunter is already looking at the Compass — that is what the Compass
## is for — so their own bar can be a hairline beside it. The prey is looking at
## the *world*, hiding, and their bar has to be read without being looked at. That
## is the same requirement UI_UX_SPEC §5.2 states for the score feed, and the same
## answer: give the peripheral element the weight.
##
## **BOTH ARCS HAVE A TRACK BEHIND THEM, AND THAT IS THE FINDING WORTH KEEPING.**
## Without one, a bar at 0.95 and a bar at 0.6 are both *an arc with a gap in it*
## and the fraction is not judgeable at a glance — a progress bar without its track
## is not a progress bar. It matters more here than on the lock arc, which fills in
## 1.6 s, because the whole value of this element is judging how long you have.
class_name ChaseRingWidget
extends Control

## **DERIVED FROM THE COMPASS'S OWN CONSTANTS, NEVER RE-CHOSEN.** The two elements
## must share a centre or the bars read as belonging to something else, and a
## second hand-written offset is a second number to keep in step.
const DIAMETER := 260.0

## Outside `CompassWidget.LOCK_RADIUS` (104) and its 3 px stroke, with a gap wide
## enough that a full lock and a full chase do not read as one thick ring.
const HUNTED_RADIUS := 113.0
const HUNTED_WIDTH := 5.0
const HUNT_RADIUS := 123.0
const HUNT_WIDTH := 2.5

## The unfilled remainder, so a bar reads as a fraction rather than as an arc of
## arbitrary length. Faint enough to sit under the district without adding a ring
## the player has to learn.
const TRACK_ALPHA := 0.18

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
		_track(centre, HUNTED_RADIUS, palette.chase_hunted, HUNTED_WIDTH)
		_arc(centre, HUNTED_RADIUS, -vm.hunted, palette.chase_hunted, HUNTED_WIDTH + _flash_width())
	if vm.is_hunting():
		_track(centre, HUNT_RADIUS, palette.chase_hunt, HUNT_WIDTH)
		_arc(centre, HUNT_RADIUS, vm.hunting, palette.chase_hunt, HUNT_WIDTH)


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


## The whole circle at a fraction of the bar's own alpha, so the track cannot be a
## colour of its own to keep in step with the bar in front of it.
func _track(centre: Vector2, radius: float, colour: Color, width: float) -> void:
	var faint := Palette.with_alpha(colour, colour.a * TRACK_ALPHA)
	draw_arc(centre, radius, 0.0, TAU, SEGMENTS, faint, width, true)
