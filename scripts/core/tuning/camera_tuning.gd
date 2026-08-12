## Camera framing, damping and shake. TUNABLES §12.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name CameraTuning
extends Resource

## Narrow FOV at blend-walk. Compresses the scene and makes faces readable at 20 m — you are
## looking at people.
## TUN-CAM-FOV-BLEND
@export_range(50.0, 60.0, 0.1) var fov_blend: float = 55.0

## "
## TUN-CAM-FOV-STROLL
@export_range(55.0, 65.0, 0.1) var fov_stroll: float = 60.0

## "
## TUN-CAM-FOV-RUN
@export_range(64.0, 74.0, 0.1) var fov_run: float = 69.0

## The lens while climbing. Promoted from prose — GDD-02 §2.1's state table has framed a climb at
## 62° since it was written, without an ID, and ClimbState borrowed the deprecated Jog rung's 65°
## instead. Between stroll and run, because a climb is faster than a stroll and is not a
## commitment to speed.
## TUN-CAM-FOV-CLIMB
@export_range(55.0, 70.0, 0.1) var fov_climb: float = 62.0

## Wide FOV at sprint. Speed lines and peripheral distortion. The camera itself tells you that
## you are doing something conspicuous.
## TUN-CAM-FOV-SPRINT
@export_range(68.0, 80.0, 0.1) var fov_sprint: float = 72.0

## FOV transition speed between states. Fast enough to track a speed change, slow enough not to
## snap.
## TUN-CAM-FOV-BLEND-RATE
@export_range(60.0, 140.0, 0.1) var fov_blend_rate: float = 90.0

## The single FOV motion-reduction mode locks to, replacing the whole ladder. Sits between stroll
## and run so no speed is framed unusually — the mode removes a warning channel and must not add
## a framing bias on top. Promoted from prose — ../10_gdd/02_player_controller.md §9.4 gives the
## value without an ID. The compensating speed indicator it trades for is SYS-UI's, in US-0084.
## TUN-CAM-FOV-MOTION-REDUCED
@export_range(55.0, 70.0, 0.1) var fov_motion_reduced: float = 62.0

## Spring-arm length. Far enough to see your own silhouette (you must be able to judge how you
## look), close enough to keep the crowd legible.
## TUN-CAM-ARM-LENGTH
@export_range(2.2, 3.2, 0.1) var arm_length: float = 2.6

## Pivot height — roughly shoulder height on the tallest persona.
## TUN-CAM-ARM-HEIGHT
@export_range(1.4, 1.8, 0.01) var arm_height: float = 1.55

## How far short of an occluder the arm stops. Below it the near plane clips into geometry and
## the player sees through the wall; above it the camera reads as detached from the surface it is
## avoiding. Promoted from prose — GDD-02 §4.4 describes the pull-in without saying where it
## stops.
## TUN-CAM-OCCLUSION-MARGIN
@export_range(0.1, 0.5, 0.1) var occlusion_margin: float = 0.2

## Speed at which the arm pulls in on collision. Fast, because a camera stuck in a wall in a game
## about looking at people is a critical failure.
## TUN-CAM-OCCLUSION-PULL-RATE
@export_range(8.0, 20.0, 0.1) var occlusion_pull_rate: float = 12.0

## Speed of restoration. Slower than pull-in, to avoid oscillation in doorways.
## TUN-CAM-OCCLUSION-RESTORE-RATE
@export_range(2.0, 8.0, 0.1) var occlusion_restore_rate: float = 4.0

## Look-sensitivity multiplier while holding the crowd-scan input. Slow, precise panning for
## reading a crowd — the game's central act, given its own input.
## TUN-CAM-CROWDSCAN-SPEED
@export_range(0.3, 0.7, 0.01) var crowdscan_speed: float = 0.45

## FOV while crowd-scanning. Narrower than any speed state: leaning in.
## TUN-CAM-CROWDSCAN-FOV
@export_range(42.0, 54.0, 0.1) var crowdscan_fov: float = 48.0
