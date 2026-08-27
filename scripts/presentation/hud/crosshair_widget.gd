## **THE ONE WIDGET WITH A HARD CORRECTNESS REQUIREMENT.** UI_UX_SPEC §6, US-0073.
##
## > **The ring appears if and only if pressing kill would succeed.**
##
## **IT IS FED BY A SERVER FLAG AND NOTHING ELSE.** `kill_ready` and `stun_ready`
## are computed by `SYS-KILL` against the same range, cone, contract, lockout,
## concealment and — since ADR-0015 — line-of-sight rules the press itself is
## judged by. A client-side range check would be a *second* implementation of that,
## and it would disagree the moment lag compensation mattered, which is precisely
## when a player is looking at the crosshair.
##
## **A LYING CROSSHAIR IS WORSE THAN NO CROSSHAIR.** GDD-02 §9's failure mode 7 is
## *"kill feels unresponsive"*, and the shape it actually takes is a player
## pressing a button the HUD promised would work. This widget has no way to lie,
## because it has no way to compute.
##
## **KILL AND STUN DIFFER IN SHAPE, NOT ONLY COLOUR** (§6): a ring against a
## bracket pair. The colours reinforce a distinction that is already legible
## without them, which is what keeps this readable on the monochrome palette.
class_name CrosshairWidget
extends Control

const DOT_RADIUS := 1.5
const RING_RADIUS := 9.0
const RING_WIDTH := 1.5
const BRACKET_REACH := 11.0
const BRACKET_ARM := 4.0
const BRACKET_WIDTH := 1.5

var palette: Palette = null

var _kill: bool = false
var _stun: bool = false


func _ready() -> void:
	if palette == null:
		palette = Palette.fallback()
	# **THE CENTRE IS OTHERWISE EMPTY.** §1: nothing occupies the centre 60 % of
	# the screen except this. A 3 px dot is the whole of what the game puts in
	# front of the thing the player is looking at.
	set_anchors_preset(Control.PRESET_CENTER, true)
	custom_minimum_size = Vector2(2.0 * BRACKET_REACH, 2.0 * BRACKET_REACH)
	offset_left = -BRACKET_REACH
	offset_right = BRACKET_REACH
	offset_top = -BRACKET_REACH
	offset_bottom = BRACKET_REACH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.kill_ready_changed.connect(_on_ready)


func _exit_tree() -> void:
	if EventBus.kill_ready_changed.is_connected(_on_ready):
		EventBus.kill_ready_changed.disconnect(_on_ready)


func _on_ready(kill: bool, stun: bool) -> void:
	_kill = kill
	_stun = stun
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	draw_circle(centre, DOT_RADIUS, palette.crosshair)
	if _kill:
		draw_arc(centre, RING_RADIUS, 0.0, TAU, 40, palette.crosshair_kill, RING_WIDTH, true)
	if _stun:
		_draw_brackets(centre)


## Four corner brackets. **A shape a ring cannot be mistaken for**, which is the
## requirement — a player must be able to tell a stun opportunity from a kill
## opportunity without reading a colour, because the two verbs cost very different
## things when pressed at the wrong moment.
func _draw_brackets(centre: Vector2) -> void:
	var colour := palette.crosshair_stun
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var elbow := centre + corner * BRACKET_REACH
		draw_line(elbow, elbow - Vector2(corner.x * BRACKET_ARM, 0.0), colour, BRACKET_WIDTH, true)
		draw_line(elbow, elbow - Vector2(0.0, corner.y * BRACKET_ARM), colour, BRACKET_WIDTH, true)
