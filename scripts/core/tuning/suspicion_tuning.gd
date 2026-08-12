## Suspicion gain, decay, tiers and blending. TUNABLES §3.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name SuspicionTuning
extends Resource

## Fixed scale. Every source is expressed as a fraction of "fully exposed", which makes tuning
## arguments comparable.
## TUN-SUSPICION-MAX
@export var max_value: float = 100.0

## Clamped floor.
## TUN-SUSPICION-MIN
@export var min: float = 0.0

## Full 100 → 0 in 12.5 s of civilian behaviour. Long enough that a mistake has consequences you
## must live with; short enough that a match is not ruined by one bad five seconds.
## TUN-SUSPICION-DECAY-BASE
@export_range(6.0, 12.0, 0.1) var decay_base: float = 8.0

## Decay applies only at or below this speed — i.e. Idle, blend-walk and stroll. Equals TUN-
## SPEED-STROLL. This single threshold is the game's thesis: below it you recover, above it you
## spend. (ASM-0008)
## TUN-SUSPICION-DECAY-SPEED-CEILING
@export var decay_speed_ceiling: float = 2.2

## Grace period after the last gain before decay resumes. Prevents a player from tapping sprint
## repeatedly and paying almost nothing.
## TUN-SUSPICION-DECAY-DELAY
@export_range(0.3, 1.2, 0.1) var decay_delay: float = 0.6

## Noticed in 1.2 s, Exposed in 2.8 s. Sprinting is a 3-second budget, not a movement mode. This
## is the single most important number in the game.
## TUN-SUSPICION-GAIN-SPRINT
@export_range(20.0, 32.0, 0.1) var gain_sprint: float = 25.0

## Noticed in 2.1 s. Run is the "I need to be somewhere" speed: usable for a street's length, not
## a plaza's. (ASM-0007)
## TUN-SUSPICION-GAIN-RUN
@export_range(10.0, 18.0, 0.1) var gain_run: float = 14.0

## World height at or above which a pawn counts as being on the rooftop stratum, and so pays TUN-
## SUSPICION-GAIN-ROOF. Sits between MAP-VETRAIO's balcony (3.5 m) and roof (8.5 m) strata, so a
## balcony is free and a roof is not. Absolute, and that only works while the street stratum is
## flat at y = 0 — a map with varying ground level needs real stratum data in MapData instead.
## TUN-SUSPICION-ROOF-HEIGHT
@export_range(4.0, 8.0, 0.1) var roof_height: float = 6.0

## Being on the rooftop stratum at all, regardless of speed. Noticed in 1.7 s — which is 30/18,
## the toll alone: decay does not run up there, or the same figure would be 3.0 s. A roof is not
## somewhere you recover slowly, it is somewhere you do not recover. Roofs are fast and empty; a
## civilian is never up there. This is what stops the roofs from being strictly better.
## TUN-SUSPICION-GAIN-ROOF
@export_range(14.0, 24.0, 0.1) var gain_roof: float = 18.0

## While actively climbing. Lower than roof-presence because a climb is brief and sometimes
## necessary; the roof you arrive at is what really costs.
## TUN-SUSPICION-GAIN-CLIMB
@export_range(8.0, 16.0, 0.1) var gain_climb: float = 12.0

## While no NPC is within TUN-SUSPICION-OPEN-RADIUS. Noticed in 5 s of standing alone. The
## mechanic that makes an empty plaza a danger zone and makes crowd-seeking a constant background
## pressure.
## TUN-SUSPICION-GAIN-OPEN
@export_range(4.0, 9.0, 0.1) var gain_open: float = 6.0

## "Alone" means no NPC within this radius. Tuned against the crowd-pocket module spacing so that
## the designed pockets reliably suppress it and the designed empty spaces reliably do not.
## TUN-SUSPICION-OPEN-RADIUS
@export_range(4.0, 9.0, 0.1) var open_radius: float = 6.0

## Half the way to Noticed for one collision. Bumping is how a careless player betrays themselves
## in a crowd, and it is also what makes moving through a dense pocket a skill rather than a
## shortcut.
## TUN-SUSPICION-GAIN-NPC-BUMP
@export_range(10.0, 22.0, 0.1) var gain_npc_bump: float = 15.0

## Minimum interval between bump impulses, so one bad shove into a group is not five stacked
## charges.
## TUN-SUSPICION-GAIN-NPC-BUMP-COOLDOWN
@export_range(0.5, 1.5, 0.1) var gain_npc_bump_cooldown: float = 0.8

## Applied by ABIL-CINDERFALL and ABIL-LUNGE. From Anonymous, one loud ability puts you at 40 —
## Noticed immediately, and 5 s of walking to clear. Loud abilities cost your cover, which is
## exactly the trade they are for.
## TUN-SUSPICION-GAIN-LOUD-ABILITY
@export_range(30.0, 50.0, 0.1) var gain_loud_ability: float = 40.0

## A whiffed or interrupted kill. You lunged at someone and it did not land: everyone watching
## now knows what you are.
## TUN-SUSPICION-GAIN-FAILED-KILL
@export_range(20.0, 40.0, 0.1) var gain_failed_kill: float = 30.0

## Applied to the killer if any other player had line of sight at the moment of initiation. The
## reason a kill in a theatre space is riskier than a kill in an alley — and the mechanic that
## makes theatre spaces matter.
## TUN-SUSPICION-GAIN-WITNESSED-KILL
@export_range(15.0, 35.0, 0.1) var gain_witnessed_kill: float = 25.0

## Entry to Noticed. At 30, the player who holds you as a contract sees a faint tint on you. Set
## at 30 % so that a single instant impulse (bump, 15) does not cross it from zero, but two do.
## TUN-SUSPICION-TIER-NOTICED
@export_range(25.0, 40.0, 0.1) var tier_noticed: float = 30.0

## Entry to Exposed. Hard silhouette to your pursuer, free Compass lock, and your prey is warned.
## 70 is reachable from Anonymous by ~2.8 s of sprinting or one loud ability plus one bump plus a
## second of running.
## TUN-SUSPICION-TIER-EXPOSED
@export_range(60.0, 80.0, 0.1) var tier_exposed: float = 70.0

## A tier is exited 5 points below the threshold that entered it. Prevents strobing at the
## boundary. A flickering tint is not merely ugly — it is an unreliable information channel, and
## the game is made of information channels. (ASM-0009)
## TUN-SUSPICION-HYSTERESIS
@export_range(3.0, 10.0, 0.1) var hysteresis: float = 5.0

## Time from blend entry to suspicion 0, linear from the current value. Long enough that you
## cannot blend during a chase to erase it; short enough that pre-emptive blending is reliably
## rewarded.
## TUN-BLEND-CRUSH-TIME
@export_range(0.8, 2.0, 0.1) var blend_crush_time: float = 1.2

## Time to physically enter the blend (sit, step into the group, climb into the cart). You are
## vulnerable and visibly transitioning during it.
## TUN-BLEND-ENTRY-TIME
@export_range(0.2, 0.6, 0.01) var blend_entry_time: float = 0.35

## Time to leave. Slightly shorter than entry: escaping a blend under threat must not feel like a
## trap.
## TUN-BLEND-EXIT-TIME
@export_range(0.2, 0.5, 0.1) var blend_exit_time: float = 0.3

## How close you must be to a walking group to join it. Matches TUN-KILL-RANGE deliberately — the
## distance at which you can join a group is the distance at which you can be killed in it.
## TUN-BLEND-GROUP-JOIN-RADIUS
@export_range(2.0, 3.5, 0.1) var blend_group_join_radius: float = 2.5

## How far you may drift from your formation slot before the blend breaks.
## TUN-BLEND-GROUP-SLOT-TOLERANCE
@export_range(0.5, 1.2, 0.1) var blend_group_slot_tolerance: float = 0.8

## Minimum NPCs within TUN-BLEND-POCKET-RADIUS for a standing blend to be valid. Four is the
## smallest number that reads as "a group" rather than "some people".
## TUN-BLEND-POCKET-MIN-NPC
@export_range(3, 6, 1) var blend_pocket_min_npc: int = 4

## The radius in which those NPCs must stand.
## TUN-BLEND-POCKET-RADIUS
@export_range(2.5, 5.0, 0.1) var blend_pocket_radius: float = 3.5

## Being hit or stunned always breaks a blend.
## TUN-BLEND-BREAK-ON-DAMAGE
@export var break_on_damage: bool = true

## Exceeding stroll breaks any blend. Equals TUN-SPEED-STROLL.
## TUN-BLEND-BREAK-ON-SPEED
@export var break_on_speed: float = 2.2

## Players per concealment prop (hay cart, well, wardrobe). One, so that a prop is a claimable
## resource and a second player arriving is a real problem.
## TUN-BLEND-PROP-CAPACITY
@export_range(1, 2, 1) var blend_prop_capacity: int = 1

## Window after leaving a prop during which you cannot re-enter it. Prevents door-flickering to
## dodge a kill.
## TUN-BLEND-PROP-EXIT-VULN
@export_range(0.3, 0.8, 0.1) var blend_prop_exit_vuln: float = 0.5

## You may initiate a kill up to 1.0 s after leaving a blend and still earn SCORE-BLENDED. This
## is what makes the blend-then-strike play legible and reliable rather than frame-perfect.
## TUN-BLEND-SCORE-GRACE
@export_range(0.5, 1.5, 0.1) var blend_score_grace: float = 1.0

## PASV-STILLNESS: suspicion decay is 40 % faster while stationary (11.2/s). Full 100 → 0 in 8.9
## s instead of 12.5 s. The passive for a player who commits to the thesis.
## TUN-PASV-STILLNESS-MULT
@export_range(1.2, 1.8, 0.1) var stillness_mult: float = 1.4

## "Stationary" means below this. Non-zero so that micro-drift from a walking-group slot does not
## disable it.
## TUN-PASV-STILLNESS-SPEED-CEILING
@export_range(0.0, 0.5, 0.01) var stillness_speed_ceiling: float = 0.15
