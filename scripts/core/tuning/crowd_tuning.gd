## Crowd density, NPC speeds and reactions. TUNABLES §9.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name CrowdTuning
extends Resource

## Absolute floor. Below 60 on a 120 × 120 m map the district reads as abandoned and TUN-
## SUSPICION-GAIN-OPEN applies almost everywhere, which turns the game into a shooter.
## TUN-CROWD-COUNT-MIN
@export var count_min: int = 60

## Absolute ceiling, set by TUN-PERF-CROWD-BUDGET.
## TUN-CROWD-COUNT-MAX
@export var count_max: int = 90

## The 6-player default. Chosen as 48 clones (4 personas × 12) + 30 filler.
## TUN-CROWD-COUNT-DEFAULT-6P
@export_range(66, 90, 1) var count_default_6p: int = 78

## The 4-player default: 40 clones (4 × 10) + 26 filler. Fewer players need fewer clones for the
## same per-player anonymity, and the saved budget goes to frame time. See
## ../10_gdd/07_balance.md §7.
## TUN-CROWD-COUNT-DEFAULT-4P
@export_range(60, 78, 1) var count_default_4p: int = 66

## The 5-player default: 44 clones (4 × 11) + 28 filler. Interpolates the 4P and 6P rows; defined
## explicitly rather than derived so the 5-player crowd is reviewable in this table like every
## other number.
## TUN-CROWD-COUNT-DEFAULT-5P
@export_range(63, 84, 1) var count_default_5p: int = 72

## Below 8, a persona's clone population can be locally depleted (all on the far side of the map)
## and the player wearing it becomes unique.
## TUN-CROWD-CLONES-PER-PERSONA-MIN
@export var clones_per_persona_min: int = 8

## Above 12 the crowd starts reading as a police lineup of repeats rather than a city.
## TUN-CROWD-CLONES-PER-PERSONA-MAX
@export var clones_per_persona_max: int = 12

## The crowd director maintains at least this many clones of each in-use persona within 25 m of
## each player. Without this rule the statistical guarantee above fails locally, which is where
## it matters.
## TUN-CROWD-CLONE-LOCAL-MIN
@export_range(1, 4, 1) var clone_local_min: int = 2

## How often the crowd director rebalances clone distribution. Slow, because visible re-routing
## is itself an information leak.
## TUN-CROWD-DIRECTOR-INTERVAL
@export_range(1.0, 5.0, 0.1) var director_interval: float = 2.0

## Must equal TUN-SPEED-BLENDWALK.
## TUN-CROWD-NPC-SPEED-STROLL
@export var npc_speed_stroll: float = 1.4

## Startle speed. Below TUN-SPEED-SPRINT, so a sprinting player cannot hide inside a startle
## wave.
## TUN-CROWD-NPC-SPEED-FLEE
@export_range(4.0, 6.0, 0.1) var npc_speed_flee: float = 5.0

## Walking-group size. Four is the minimum that reads as a group and leaves a joinable slot.
## TUN-CROWD-GROUP-SIZE
@export_range(3, 6, 1) var group_size: int = 4

## Number of walking-group circuits on MAP-VETRAIO.
## TUN-CROWD-GROUP-COUNT
@export_range(3, 6, 1) var group_count: int = 4

## Formation slot spacing. Loose enough for a player to slot in without collision-shoving.
## TUN-CROWD-GROUP-SPACING
@export_range(1.0, 2.0, 0.1) var group_spacing: float = 1.3

## Shortest time an NPC stands at an idle anchor before strolling on. The range is GDD-03 §6.1's
## own "8–25 s", which the diagram specified and no tunable carried until US-0040 — the state
## machine cannot leave Idle without it. Wide because a crowd whose pauses are all the same
## length reads as a mechanism.
## TUN-CROWD-IDLE-DURATION-MIN
@export_range(5.0, 15.0, 0.1) var idle_duration_min: float = 8.0

## Longest such pause. Must exceed the minimum (invariant §17.27). A long tail matters more than
## the average: a few NPCs standing for twenty seconds is what makes an idle anchor read as a
## place rather than a waypoint, and it is what gives a hiding player somebody to stand beside.
## TUN-CROWD-IDLE-DURATION-MAX
@export_range(15.0, 40.0, 0.1) var idle_duration_max: float = 25.0

## Conversation clusters.
## TUN-CROWD-IDLE-GROUP-SIZE-MIN
@export var idle_group_size_min: int = 2

## "
## TUN-CROWD-IDLE-GROUP-SIZE-MAX
@export_range(4, 6, 1) var idle_group_size_max: int = 4

## How long a startled NPC flees. Long enough that the wave is visible from across a plaza — a
## startle is a public announcement.
## TUN-CROWD-STARTLE-DURATION
@export_range(3.0, 6.0, 0.1) var startle_duration: float = 4.0

## Startle radius for a kill or stun.
## TUN-CROWD-STARTLE-RADIUS-VIOLENCE
@export_range(8.0, 18.0, 0.1) var startle_radius_violence: float = 12.0

## Startle radius for a sprinting player brushing past. Smaller: it is a ripple, not a wave, but
## it still marks your path.
## TUN-CROWD-STARTLE-RADIUS-SPRINT
@export_range(3.0, 8.0, 0.1) var startle_radius_sprint: float = 5.0

## How often the crowd looks for a sprinting player to be startled by. GDD-03 §6.4's own
## "evaluated once per second, not per tick", which no tunable carried until US-0044. It is a
## gameplay number rather than a sampling detail: a sprinter crossing a 5 m radius at TUN-SPEED-
## SPRINT is inside it for about 1.6 s, so at this interval they are caught once or twice — the
## ripple marks the path without every stride firing a fresh wave. Longer and a fast player can
## cross a crowd unremarked; shorter and sprinting past a market produces one continuous scatter,
## which reads as a radius rather than as a trail.
## TUN-CROWD-STARTLE-SPRINT-INTERVAL
@export_range(0.5, 2.0, 0.1) var startle_sprint_interval: float = 1.0

## A startled NPC startles others within TUN-CROWD-STARTLE-RADIUS-SPRINT with this probability,
## once. Produces a decaying wave rather than a hard-edged circle, which reads as organic and —
## more usefully — gives the wave a direction a distant player can read.
## TUN-CROWD-STARTLE-PROPAGATION
@export_range(0.0, 0.7, 0.1) var startle_propagation: float = 0.4

## How long NPCs crowd a corpse. Shorter than TUN-CORPSE-LIFETIME so the crowd disperses before
## the body does, giving two distinct phases of information.
## TUN-CROWD-GAWK-DURATION
@export_range(4.0, 10.0, 0.1) var gawk_duration: float = 6.0

## Recruitment radius for gawkers.
## TUN-CROWD-GAWK-RADIUS
@export_range(6.0, 15.0, 0.1) var gawk_radius: float = 10.0

## Cap on gawkers, so a corpse in a dense pocket does not depopulate the pocket — which would
## perversely make a kill site safer to stand in.
## TUN-CROWD-GAWK-MAX
@export_range(4, 10, 1) var gawk_max: int = 6

## How long a corpse persists. It is a deliberate information object: it says "someone died here,
## recently, and their killer was here 20 seconds ago".
## TUN-CORPSE-LIFETIME
@export_range(12.0, 30.0, 0.1) var corpse_lifetime: float = 20.0

## Visual dissolve at end of life.
## TUN-CORPSE-FADE-TIME
@export var fade_time: float = 1.5

## Impulse applied to an NPC a player collides with. Enough to be visible to onlookers — a bump
## is an information event, not just a suspicion charge.
## TUN-CROWD-BUMP-PUSH
@export_range(0.8, 2.0, 0.1) var bump_push: float = 1.2

## How close an NPC must come to its idle anchor to count as arrived. It decides how tightly an
## idle cluster packs, which is what makes it a gameplay number rather than a navigation one:
## NPCs arriving within 1.2 m of one anchor stand inside TUN-BLEND-POCKET-RADIUS of each other,
## so an anchor reliably forms a valid blend pocket. Larger and a cluster stops reading as a
## group; smaller and NPCs shove one another for the same 0.35 m of floor. Invariant §17.28.
## TUN-CROWD-ANCHOR-ARRIVE-RADIUS
@export_range(0.6, 2.5, 0.1) var anchor_arrive_radius: float = 1.2
