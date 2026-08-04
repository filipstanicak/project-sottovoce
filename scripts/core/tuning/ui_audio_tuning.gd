## HUD and audio timing. TUNABLES §15.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name UiAudioTuning
extends Resource

## Every HUD state must be parseable in this long. The test procedure is in
## ../30_bible/UI_UX_SPEC.md §9.
## TUN-UI-READABILITY-TARGET
@export var readability_target: float = 0.5

## How long a score-feed line persists. Long enough to read three stacked bonuses.
## TUN-UI-SCOREFEED-DURATION
@export_range(3.0, 6.0, 0.1) var scorefeed_duration: float = 4.0

## Simultaneous lines before the oldest is dropped.
## TUN-UI-SCOREFEED-MAX-LINES
@export_range(3, 6, 1) var scorefeed_max_lines: int = 4

## Delay between stacked bonuses appearing on one kill. They arrive as a sequence, which is far
## more readable — and more satisfying — than a block.
## TUN-UI-SCOREFEED-STAGGER
@export_range(0.08, 0.25, 0.01) var scorefeed_stagger: float = 0.12

## Visual transition when your own suspicion tier changes.
## TUN-UI-TIER-TRANSITION-TIME
@export_range(0.15, 0.4, 0.01) var tier_transition_time: float = 0.25

## Duration of the exposed-tier screen-edge vignette fade.
## TUN-UI-DAMAGE-VIGNETTE-TIME
@export var damage_vignette_time: float = 0.8

## Ducking applied to ambience when the Compass pulse plays. The pulse must never be masked by
## crowd noise: it is the primary information channel.
## TUN-AUDIO-COMPASS-DUCK
@export var compass_duck: float = -6.0

## Ducking on the prey warning sting. Aggressive, because this is the single most important sound
## in the game.
## TUN-AUDIO-STING-DUCK
@export var sting_duck: float = -12.0

## Low-pass cutoff for sound sources occluded by geometry.
## TUN-AUDIO-OCCLUSION-LOWPASS
@export_range(600.0, 1600.0, 0.1) var occlusion_lowpass: float = 900.0

## Audible radius of a blend-walking player's footsteps.
## TUN-AUDIO-FOOTSTEP-RADIUS-BLEND
@export_range(3.0, 6.0, 0.1) var footstep_radius_blend: float = 4.0

## Audible radius at sprint. 4.5× — running is loud, and the audio channel is a genuine,
## unblockable information leak.
## TUN-AUDIO-FOOTSTEP-RADIUS-SPRINT
@export_range(12.0, 26.0, 0.1) var footstep_radius_sprint: float = 18.0
