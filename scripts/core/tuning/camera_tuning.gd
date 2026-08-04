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
## TUN-CAM-FOV-JOG
@export_range(60.0, 70.0, 0.1) var fov_jog: float = 65.0

## "
## TUN-CAM-FOV-RUN
@export_range(64.0, 74.0, 0.1) var fov_run: float = 69.0

## Wide FOV at sprint. Speed lines and peripheral distortion. The camera itself tells you that
## you are doing something conspicuous.
## TUN-CAM-FOV-SPRINT
@export_range(68.0, 80.0, 0.1) var fov_sprint: float = 72.0

## FOV transition speed between states. Fast enough to track a speed change, slow enough not to
## snap.
## TUN-CAM-FOV-BLEND-RATE
@export_range(60.0, 140.0, 0.1) var fov_blend_rate: float = 90.0

## Spring-arm length. Far enough to see your own silhouette (you must be able to judge how you
## look), close enough to keep the crowd legible.
## TUN-CAM-ARM-LENGTH
@export_range(2.2, 3.2, 0.1) var arm_length: float = 2.6

## Pivot height — roughly shoulder height on the tallest persona.
## TUN-CAM-ARM-HEIGHT
@export_range(1.4, 1.8, 0.01) var arm_height: float = 1.55

## Lateral offset.
## TUN-CAM-SHOULDER-OFFSET
@export_range(0.3, 0.7, 0.01) var shoulder_offset: float = 0.45

## Time to swap shoulders.
## TUN-CAM-SHOULDER-SWAP-TIME
@export_range(0.15, 0.4, 0.01) var shoulder_swap_time: float = 0.25

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
