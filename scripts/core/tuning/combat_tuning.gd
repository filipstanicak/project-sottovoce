## The kill and the stun. TUNABLES §5–6.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name CombatTuning
extends Resource

## Conversational distance. You must be close enough that standing there is itself a commitment,
## and close enough that the victim could have looked at you.
## TUN-KILL-RANGE
@export_range(2.0, 3.2, 0.1) var kill_range: float = 2.5

## Total cone (±30°) the killer must face within. Generous enough that camera wobble does not eat
## a kill; tight enough that you cannot kill someone beside you. The victim's facing is
## irrelevant — killing someone facing away from you is the intended patient play. (ASM-0010)
## TUN-KILL-FACING-CONE
@export_range(45.0, 90.0, 0.1) var kill_facing_cone: float = 60.0

## The committed animation. The killer is fully visible and cannot act. This is the price of
## every kill and the reason a kill in the open is a bad idea even when it works. Sits exactly at
## TUN-FEEL-MAX-COMMIT.
## TUN-KILL-ANIM-DURATION
@export_range(1.2, 1.8, 0.1) var kill_anim_duration: float = 1.4

## Zero. There is no cancel. Commitment is the mechanic.
## TUN-KILL-ANIM-CANCEL-WINDOW
@export var anim_cancel_window: float = 0.0

## Server-side range tolerance on top of TUN-KILL-RANGE, applied after lag-compensated rewind.
## Absorbs residual netcode error so a legitimate kill is not denied by 4 cm.
## TUN-KILL-VALIDATION-GRACE
@export_range(0.2, 0.6, 0.01) var kill_validation_grace: float = 0.35

## Two initiations on the same victim inside this window are contested; the earlier server
## timestamp wins.
## TUN-KILL-CONTEST-WINDOW
@export_range(0.25, 0.6, 0.01) var kill_contest_window: float = 0.4

## The loser of a contest is staggered. Not stunned: no points to anyone, no lockout. Losing a
## race should cost tempo, not the match.
## TUN-KILL-CONTEST-STAGGER
@export_range(1.0, 2.5, 0.1) var kill_contest_stagger: float = 1.5

## Pressing kill on a valid-range non-contract player applies TUN-SUSPICION-GAIN-FAILED-KILL and
## plays the whiff animation. You cannot safely test whether a stranger is your contract.
## TUN-KILL-INVALID-TARGET-PENALTY
@export var invalid_target_penalty: bool = true

## Point within the kill animation at which the corpse and its SYS-CORPSE information object
## appear. Aligned to the animation's contact frame.
## TUN-KILL-CORPSE-SPAWN-DELAY
@export var kill_corpse_spawn_delay: float = 0.9

## Slightly longer than TUN-KILL-RANGE. Deliberate: the prey's reach must exceed the hunter's, so
## a hunter who closes to kill range has already entered stun range. Recklessness is punished by
## geometry before it is punished by scoring.
## TUN-STUN-RANGE
@export_range(2.5, 4.0, 0.1) var stun_range: float = 3.0

## Wide (±60°). You are turning in panic; the game must not require precision from a player who
## has just been startled.
## TUN-STUN-FACING-CONE
@export_range(90.0, 180.0, 0.1) var stun_facing_cone: float = 120.0

## The pursuer must be at least Noticed. Equals TUN-SUSPICION-TIER-NOTICED. An Anonymous hunter
## cannot be stunned — patience is genuinely safe, which is the whole point.
## TUN-STUN-MIN-TIER
@export var stun_min_tier: float = 30.0

## The hunter is frozen and helpless. Four seconds is long enough to walk away, blend, and be
## gone. It must feel catastrophic.
## TUN-STUN-FREEZE
@export_range(3.0, 6.0, 0.1) var stun_freeze: float = 4.0

## The stunned hunter cannot re-initiate on that specific target for this long. Without it, stun
## merely delays the kill by four seconds and is not counterplay at all.
## TUN-STUN-LOCKOUT
@export_range(8.0, 18.0, 0.1) var stun_lockout: float = 12.0

## The stunned hunter is set to TUN-SUSPICION-MAX and held at Exposed for TUN-STUN-FREEZE.
## Everyone nearby now knows what they are.
## TUN-STUN-FORCES-EXPOSED
@export var forces_exposed: bool = true

## Twice SCORE-CONTRACT, and the reference's own number (2026-09-03, ADR-0018). Successfully
## defending yourself outscores the cheapest thing a hunter can do and loses to their best — the
## statement that defence is a scoring strategy, not a survival tax.
## TUN-STUN-SCORE
@export_range(75.0, 250.0, 0.1) var score: float = 200.0

## The stunner's own commitment. Half the kill animation: defence is faster than offence.
## TUN-STUN-ANIM-DURATION
@export_range(0.5, 1.0, 0.1) var stun_anim_duration: float = 0.7

## Stunning a non-pursuer: zero points and this stagger. Longer than TUN-STUN-ANIM-DURATION so
## flailing is strictly worse than doing nothing.
## TUN-STUN-INVALID-STAGGER
@export_range(1.5, 3.5, 0.1) var stun_invalid_stagger: float = 2.0

## And you look ridiculous doing it. Stops "stun everyone who comes near" from being free.
## TUN-STUN-INVALID-SUSPICION
@export_range(10.0, 30.0, 0.1) var stun_invalid_suspicion: float = 20.0

## Minimum interval between stun attempts by the same player. Anti-spam backstop.
## TUN-STUN-COOLDOWN
@export_range(2.0, 6.0, 0.1) var stun_cooldown: float = 3.0

## A player mid-ABIL-LUNGE is stunnable for the entire dash. The dash is loud and telegraphed; it
## must lose to a prepared defender.
## TUN-STUN-VS-LUNGE-WINDOW
@export var vs_lunge_window: bool = true

## PASV-SECONDWIND: TUN-STUN-LOCKOUT drops from 12 s to 8 s for this player. Explicitly does not
## reduce TUN-STUN-FREEZE — being stunned must always be catastrophic in the moment; the passive
## only shortens the exile afterwards.
## TUN-PASV-SECONDWIND-REDUCTION
@export_range(2.0, 6.0, 0.1) var second_wind_reduction: float = 4.0
