## Speed states, traversal and the feel budget. TUNABLES §2.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name MovementTuning
extends Resource

## Must equal TUN-CROWD-NPC-SPEED-STROLL exactly. If a player at blend-walk moves at a different
## speed from the NPCs around them, they are readable from motion alone and anonymity is dead.
## TUN-SPEED-BLENDWALK
@export_range(1.2, 1.6, 0.1) var blend_walk: float = 1.4

## The "purposeful civilian" speed. Fast enough that crossing the map is not tedious (120 m ≈ 55
## s), slow enough to remain suspicion-free. This is the speed a good player travels at.
## TUN-SPEED-STROLL
@export_range(1.8, 2.6, 0.1) var stroll: float = 2.2

## The first speed that costs anonymity. Priced so a short jog is a real option, not a mistake —
## a player must be able to reposition under mild pressure without falling out of SCORE-PATIENT.
## TUN-SPEED-JOG
@export_range(3.0, 3.8, 0.1) var jog: float = 3.4

## The commitment speed. 32 % faster than jog, and 3.5× the suspicion cost — the ratio is
## deliberately unfavourable so that running is a decision, not a default.
## TUN-SPEED-RUN
@export_range(4.0, 5.0, 0.1) var run: float = 4.5

## 4.4× blend-walk. Fast enough to catch a fleeing target across a plaza, expensive enough (TUN-
## SUSPICION-GAIN-SPRINT) that you reach Exposed in 2.8 s. Sprinting is a countdown, not a state.
## TUN-SPEED-SPRINT
@export_range(5.6, 6.8, 0.1) var sprint: float = 6.2

## Faster than stroll, so the roofs really are a highway. Combined with TUN-SUSPICION-GAIN-CLIMB
## this is the "roofs are fast but cost anonymity" trade the level design exists to exploit.
## TUN-SPEED-CLIMB
@export_range(2.4, 3.2, 0.1) var climb: float = 2.8

## Reaches sprint in 0.34 s. High, because input latency must not feel like sluggishness; the
## cost of sprinting is suspicion, not acceleration.
## TUN-SPEED-ACCEL
@export_range(12.0, 26.0, 0.1) var accel: float = 18.0

## Stopping is faster than starting, so that "stop and blend" is instantly available. This
## asymmetry is the thesis in the acceleration curve.
## TUN-SPEED-DECEL
@export_range(16.0, 34.0, 0.1) var decel: float = 24.0

## Turning is not throttled by speed state — a player must always be able to look.
## TUN-SPEED-TURN-RATE-GROUND
@export_range(360.0, 720.0, 0.1) var turn_rate_ground: float = 540.0

## How long INPUT-RUN must be held before Jog escalates to Run. Promoted from prose in
## 02_player_controller.md §2.2; the escalation is a gameplay timing and belongs here like every
## other.
## TUN-SPEED-RUN-HOLD
@export_range(0.2, 0.6, 0.01) var run_hold: float = 0.35

## Sustained-hold threshold for INPUT-SPRINT, the alternative to a double-tap. Deliberately
## awkward (§1.5): sprinting must be a decision, not a lean on the stick. Promoted from prose.
## TUN-SPEED-SPRINT-HOLD
@export_range(0.3, 0.6, 0.1) var sprint_hold: float = 0.4

## Maximum gap between the two INPUT-SPRINT presses of a double-tap. The other half of §1.5's
## deliberate friction, and the half that had no number: the GDD says "double-tap" and never said
## how fast. Short enough that a nervous re-press does not sprint you; long enough to be
## reachable under pressure.
## TUN-SPEED-SPRINT-DOUBLETAP
@export_range(0.15, 0.4, 0.01) var sprint_doubletap: float = 0.25

## Below this, the left stick reads as no input at all. Not cosmetic: wants_movement() decides →
## Idle, so a drifting stick would hold a pawn out of the one state where suspicion decays
## fastest.
## TUN-SPEED-STICK-DEADZONE
@export_range(0.05, 0.25, 0.01) var stick_deadzone: float = 0.15

## Left-stick magnitude at or below which a gamepad walks at blend-walk without holding the
## modifier (§1.3). Promoted from prose; it is the pad's half of the most important key in the
## game.
## TUN-SPEED-STICK-BLENDWALK-MAX
@export_range(0.2, 0.45, 0.01) var stick_blendwalk_max: float = 0.3

## Analogue trigger pull above which INPUT-RUN reads as full rather than partial — GDD-02 §1.3's
## "partial pull = jog, full pull = run". Below it the pad is held at jog, which is the rung a
## player can afford.
## TUN-SPEED-TRIGGER-RUN
@export_range(0.5, 0.95, 0.01) var trigger_run: float = 0.75

## Backing away from a hunter is possible but slow; the correct defensive answer is to blend, not
## to retreat.
## TUN-SPEED-BACKPEDAL-MULT
@export_range(0.4, 0.8, 0.01) var backpedal_mult: float = 0.55

## Waist height. Anything a civilian could plausibly hop. Above this it reads as athletic and
## becomes a climb.
## TUN-TRAVERSE-VAULT-MAX-HEIGHT
@export_range(0.9, 1.3, 0.1) var traverse_vault_max_height: float = 1.1

## Under the TUN-FEEL-MAX-COMMIT ceiling, so a vault never feels like a trap.
## TUN-TRAVERSE-VAULT-DURATION
@export_range(0.4, 0.7, 0.01) var vault_duration: float = 0.55

## Reachable ledge. Above this a climb is required.
## TUN-TRAVERSE-MANTLE-MAX-HEIGHT
@export_range(2.0, 2.6, 0.1) var traverse_mantle_max_height: float = 2.3

## Long enough to be a visible commitment from 30 m — a mantle is an information event.
## TUN-TRAVERSE-MANTLE-DURATION
@export_range(0.8, 1.2, 0.01) var mantle_duration: float = 0.95

## One stratum transition (street → balcony, balcony → roof) in a single unbroken climb.
## TUN-TRAVERSE-CLIMB-MAX-HEIGHT
@export_range(6.0, 12.0, 0.1) var traverse_climb_max_height: float = 9.0

## Below this, drop and keep moving. Above this, the drop-swing manoeuvre is required or the
## landing staggers.
## TUN-TRAVERSE-DROP-SAFE-HEIGHT
@export_range(3.0, 5.0, 0.1) var traverse_drop_safe_height: float = 4.0

## The punishment for panicking off a roof. Not a death sentence; a window during which you can
## be killed.
## TUN-TRAVERSE-DROP-STAGGER
@export_range(0.5, 1.2, 0.1) var drop_stagger: float = 0.8

## The furthest jumpable gap. The metrics bible builds all rooftop gaps at 2.0 m (easy), 2.8 m
## (committed) or 3.6 m (impossible) so a player never has to guess.
## TUN-TRAVERSE-GAP-MAX
@export_range(2.5, 4.0, 0.1) var traverse_gap_max: float = 3.2

## Ledge-grab forgiveness. The player may press traverse up to 0.25 s late and still catch.
## Forgiveness is mandatory: parkour here is assisted, not simulated, and a missed grab must be a
## decision error, not an timing error.
## TUN-TRAVERSE-MAGNET-WINDOW
@export_range(0.15, 0.4, 0.01) var traverse_magnet_window: float = 0.25

## Lateral snap distance to a ledge. Same reasoning.
## TUN-TRAVERSE-MAGNET-RADIUS
@export_range(0.4, 0.9, 0.1) var traverse_magnet_radius: float = 0.6

## Chest, waist, foot. Fixed at three; the resolution priority list in
## ../10_gdd/02_player_controller.md §7 assumes exactly these.
## TUN-TRAVERSE-PROBE-COUNT
@export var probe_count: int = 3

## Probe origin heights, measured from pawn origin.
## TUN-TRAVERSE-PROBE-HEIGHT-CHEST
@export var probe_height_chest: float = 1.35

## "
## TUN-TRAVERSE-PROBE-HEIGHT-WAIST
@export var probe_height_waist: float = 0.85

## "
## TUN-TRAVERSE-PROBE-HEIGHT-FOOT
@export var probe_height_foot: float = 0.25

## Forward reach of each probe. Longer than the pawn's radius so intent is detected before
## collision.
## TUN-TRAVERSE-PROBE-LENGTH
@export_range(0.7, 1.2, 0.1) var probe_length: float = 0.9

## A traverse input pressed this long before it becomes valid is queued, not dropped.
## TUN-TRAVERSE-INPUT-BUFFER
@export_range(0.1, 0.3, 0.1) var traverse_input_buffer: float = 0.2

## Upward launch speed of a gap jump. Gives a ~0.8 s flight under the pinned 9.8 gravity, which
## is the figure §6's traversal cost table already quotes. Horizontal speed is derived from the
## gap the probes measured, not tuned: a gap at or under TUN-TRAVERSE-GAP-MAX is jumpable always,
## and a launch that sometimes fell short would make that a lie.
## TUN-TRAVERSE-GAPJUMP-LAUNCH
@export_range(3.0, 5.0, 0.1) var gapjump_launch: float = 3.9

## Half-arc within which a gap jump auto-aligns to the crossing. Promoted from a bare "±20°" in
## ../10_gdd/02_player_controller.md §7.3's forgiveness table, which was the one row there with
## no ID. Wide enough that eyeballing the far side is enough, narrow enough that it never turns
## you toward a gap you were not crossing.
## TUN-TRAVERSE-GAP-ALIGN-ARC
@export_range(10.0, 30.0, 0.1) var gap_align_arc: float = 20.0

## How far ahead of the pawn the downward gap probe starts. Promoted from prose in
## ../10_gdd/02_player_controller.md §7.1. Far enough to clear the pawn's own 0.35 m radius,
## close enough that the edge is detected before the pawn is over it.
## TUN-TRAVERSE-GAP-PROBE-AHEAD
@export_range(0.4, 0.9, 0.1) var gap_probe_ahead: float = 0.6

## How deep the downward probes look. Deeper than TUN-TRAVERSE-DROP-SAFE-HEIGHT so a landing that
## will stagger is still found — resolving to a costly drop is a decision the player gets to
## make; finding nothing is the game refusing to answer.
## TUN-TRAVERSE-GAP-PROBE-DEPTH
@export_range(3.0, 8.0, 0.1) var gap_probe_depth: float = 5.0

## Spacing of the downward probes marching out to TUN-TRAVERSE-GAP-MAX. This is the resolution at
## which a landing edge is found: coarser and a narrow ledge across a gap is missed, finer and it
## costs raycasts every frame on every pawn.
## TUN-TRAVERSE-GAP-PROBE-STEP
@export_range(0.2, 0.8, 0.1) var gap_probe_step: float = 0.4

## Hard ceiling on input-to-visible-response, measured locally with prediction. Above ~100 ms
## players report the character as "floaty" and stop trusting close-range timing — fatal in a
## game decided at 2.5 m.
## TUN-FEEL-INPUT-TO-ANIM-MAX
@export_range(50.0, 100.0, 0.1) var input_to_anim_max: float = 80.0

## No unskippable animation may exceed this. The kill (TUN-KILL-ANIM-DURATION) is exactly at the
## ceiling and is the only thing allowed there.
## TUN-FEEL-MAX-COMMIT
@export var max_commit: float = 1.4
