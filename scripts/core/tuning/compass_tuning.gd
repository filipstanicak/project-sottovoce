## The Compass: pulse curve, lock, warning. TUNABLES §4.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name CompassTuning
extends Resource

## Half the map's width. Beyond this the Compass shows the slowest pulse and no more; the
## contract is "somewhere over there". 60 m guarantees that on a 120 m map you are almost never
## without signal, so the hunt never stalls.
## TUN-COMPASS-RANGE-MAX
@export_range(45.0, 80.0, 0.1) var range_max: float = 60.0

## Pulse period at maximum range. Slow enough to be background, present enough to be felt.
## TUN-COMPASS-PULSE-MAX
@export_range(0.7, 1.2, 0.1) var pulse_max: float = 0.9

## Pulse period at zero distance. 6.7 Hz — fast enough to read as urgency rather than rhythm.
## This is the sound of the last three metres.
## TUN-COMPASS-PULSE-MIN
@export_range(0.1, 0.25, 0.01) var pulse_min: float = 0.15

## Curve shape. See §4.2 for the formula and the sampled table. (ASM-0011)
## TUN-COMPASS-PULSE-EXP
@export_range(1.6, 3.0, 0.1) var pulse_exp: float = 2.2

## The rendered arc's half-width at TUN-COMPASS-RANGE-MAX, where the arc is narrowest. It widens
## inward to a whole ring at TUN-COMPASS-CONE-FULL-RADIUS — the two ends anchor the curve between
## them, so this value keeps meaning exactly what it says. Held at a fixed angle instead, as it
## was until 2026-08-27, the arc shrank to 1.06 m wide at the 2.85 m a kill lands from, which is
## narrower than two people side by side: it would have named the body it says it never names.
## (ASM-0012)
## TUN-COMPASS-CONE-HALFWIDTH
@export_range(8.0, 20.0, 0.1) var cone_halfwidth: float = 12.0

## Where the arc becomes a whole ring and the Compass stops saying which way, saying only here,
## somewhere. Derived, not chosen: it equals TUN-COMPASS-LOCK-RANGE — invariant 33 — whose own
## rationale is that a lock "always means 'I am in the same space as them'". That is exactly the
## sentence the ring needs, so the two are one boundary a player learns once: outside it the
## instrument points, inside it you look, and looking is what the lock is for. Reference
## semantics: "when you're looking at a complete circle, you know that your target is within
## range" — within engagement range, not touching. Widened twice on the same day, both times at
## the controls: 4.0 m derived from the half-width alone, then 6.0 m at TUN-SUSPICION-OPEN-
## RADIUS, both judged as having to stand on top of the contract.
## TUN-COMPASS-CONE-FULL-RADIUS
@export_range(6.0, 24.0, 0.1) var cone_full_radius: float = 20.0

## Deterministic slow drift of the cone's centre, seeded per contract so it is a stable property
## of this hunt rather than a per-frame lie.
## TUN-COMPASS-CONE-WOBBLE
@export_range(0.0, 8.0, 0.1) var cone_wobble: float = 4.0

## Wobble period. Non-integer and prime-ish so it does not visibly sync with the pulse.
## TUN-COMPASS-CONE-WOBBLE-PERIOD
@export_range(2.0, 6.0, 0.1) var cone_wobble_period: float = 3.1

## Matches the server tick. The Compass never contains information newer than the simulation.
## TUN-COMPASS-UPDATE-RATE
@export var update_rate: float = 30.0

## Total facing cone (±12.5°) within which the contract must sit for the lock arc to fill.
## Narrow: locking is aiming your attention, and you cannot do it while scanning.
## TUN-COMPASS-LOCK-CONE
@export_range(18.0, 35.0, 0.1) var lock_cone: float = 25.0

## Maximum lock distance. Inside a third of Compass range, so a lock always means "I am in the
## same space as them".
## TUN-COMPASS-LOCK-RANGE
@export_range(15.0, 28.0, 0.1) var lock_range: float = 20.0

## Time to fill the arc with an unbroken view. Deliberately longer than one NPC stride cycle, so
## incidental gaps in a walking group cannot complete a lock — you need a genuinely clear line.
## (ASM-0013)
## TUN-COMPASS-LOCK-FILL-TIME
@export_range(1.0, 2.5, 0.1) var lock_fill_time: float = 1.6

## Multiplier on the rate at which a partial lock drains when the conditions break. 1.4× means a
## broken lock is lost faster than it was gained, so peeking repeatedly is worse than committing
## once.
## TUN-COMPASS-LOCK-DECAY-RATE
@export_range(1.0, 3.0, 0.1) var lock_decay_rate: float = 1.4

## Line of sight is mandatory, evaluated server-side. Never trust the client's view.
## TUN-COMPASS-LOCK-REQUIRES-LOS
@export var lock_requires_los: bool = true

## How long a completed lock highlights the contract's silhouette. Long enough to start moving
## toward them; short enough that you must re-acquire, so a lock is not a permanent tag.
## TUN-COMPASS-REVEAL-DURATION
@export_range(1.0, 2.5, 0.1) var reveal_duration: float = 1.5

## Minimum interval between reveals on the same contract, so a hunter cannot chain-lock a target
## into permanent visibility.
## TUN-COMPASS-REVEAL-COOLDOWN
@export_range(2.0, 8.0, 0.1) var reveal_cooldown: float = 4.0

## Your Compass flashes red when your pursuer is within this radius and at least Noticed. This is
## the prey's only warning and the reason recklessness is self-defeating.
## TUN-COMPASS-WARN-RADIUS
@export_range(10.0, 22.0, 0.1) var warn_radius: float = 15.0

## The tier threshold that triggers the warning. Equals TUN-SUSPICION-TIER-NOTICED. An Anonymous
## pursuer produces no warning at any distance — patience really does buy invisibility.
## TUN-COMPASS-WARN-MIN-TIER
@export var warn_min_tier: float = 30.0

## How long the flash and audio sting persist after the condition ends.
## TUN-COMPASS-WARN-DURATION
@export_range(0.8, 2.0, 0.1) var warn_duration: float = 1.2

## Re-trigger interval, so a pursuer hovering at the tier boundary does not produce a strobe.
## TUN-COMPASS-WARN-COOLDOWN
@export_range(1.5, 5.0, 0.1) var warn_cooldown: float = 2.5

## The warning carries a bearing and a distance bucket. Amended 2026-08-26 (ADR-0013) from false,
## for reference fidelity: the reference marks a revealed pursuer on the compass with direction
## and range. It still tells you nothing about who — a marker on a bearing, never an identity —
## and the tier gate is unchanged, so a competent hunter produces no marker at all. The
## superseded argument is preserved in GDD-01 Law 5.
## TUN-COMPASS-WARN-GIVES-DIRECTION
@export var warn_gives_direction: bool = true

## PASV-COLDREAD: lock arc fills 30 % faster (1.23 s instead of 1.6 s). The offensive passive.
## TUN-PASV-COLDREAD-MULT
@export_range(1.15, 1.6, 0.01) var cold_read_mult: float = 1.3
