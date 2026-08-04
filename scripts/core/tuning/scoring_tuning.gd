## Score event values and multipliers. TUNABLES §11.
##
## GENERATED FROM TUNABLES.md. Every field's docstring ends with its TUN- ID,
## which is what test_tuning_docs_sync greps for. Never reorder these: the order
## is the .tres property order, and reordering rewrites every file unreviewably.
class_name ScoringTuning
extends Resource

## Any valid kill on your contract. The unit of account — every other value is expressed as a
## multiple of this, so it is fixed by definition, not tuned.
## TUN-SCORE-CONTRACT
@export var contract: float = 100.0

## Suspicion ≤ 29 (Anonymous) at initiation. Doubles the kill. The floor of good play.
## TUN-SCORE-SILENT
@export_range(75.0, 150.0, 0.1) var silent: float = 100.0

## Never exceeded TUN-SPEED-JOG in the 10 s before initiation. The most valuable single bonus,
## because it is the thesis.
## TUN-SCORE-PATIENT
@export_range(100.0, 200.0, 0.1) var patient: float = 150.0

## The lookback window for SCORE-PATIENT. Long enough that it cannot be gamed by decelerating at
## the last moment.
## TUN-SCORE-PATIENT-WINDOW
@export_range(8.0, 15.0, 0.1) var patient_window: float = 10.0

## ABIL-SECONDFACE active at initiation. Equal to Patient: disguise is a different route to the
## same virtue.
## TUN-SCORE-MASKED
@export_range(100.0, 200.0, 0.1) var masked: float = 150.0

## Unbroken line of sight on the contract for the last 6 s. Pays for the hardest thing in the
## game: standing still and watching one person in a moving crowd.
## TUN-SCORE-FOCUS
@export_range(75.0, 150.0, 0.1) var focus: float = 100.0

## The required unbroken-LOS duration.
## TUN-SCORE-FOCUS-WINDOW
@export_range(4.0, 10.0, 0.1) var focus_window: float = 6.0

## LOS may lapse this long (an NPC passing between you) without resetting the window. Without it
## the bonus is unearnable in a crowd — which is exactly where it should be earned.
## TUN-SCORE-FOCUS-BREAK-GRACE
@export_range(0.2, 0.8, 0.1) var focus_break_grace: float = 0.4

## Initiated from ≥ TUN-SCORE-FROMABOVE-HEIGHT above the target. Pays for the roof route, which
## otherwise only costs.
## TUN-SCORE-FROMABOVE
@export_range(75.0, 150.0, 0.1) var fromabove: float = 100.0

## Roughly one storey. Above balcony rail height, below full roof height, so both strata qualify.
## TUN-SCORE-FROMABOVE-HEIGHT
@export_range(2.5, 4.5, 0.1) var fromabove_height: float = 3.0

## Inside a blend action within TUN-BLEND-SCORE-GRACE of initiation. The largest bonus in the
## game, because it is the purest expression of the thesis: you waited, hidden, in plain sight,
## and let them come to you.
## TUN-SCORE-BLENDED
@export_range(150.0, 250.0, 0.1) var blended: float = 200.0

## Delayed-kill ability. Dormant in MVP — no MVP ability triggers it. Reserved for post-MVP ABIL-
## NIGHTSHADE. (ASM-0016)
## TUN-SCORE-POISONED
@export_range(50.0, 125.0, 0.1) var poisoned: float = 75.0

## Chase > TUN-SCORE-LONGHUNT-T1 before the kill.
## TUN-SCORE-LONGHUNT-1
@export_range(25.0, 100.0, 0.1) var longhunt_1: float = 50.0

## Chase > TUN-SCORE-LONGHUNT-T2. Replaces, does not stack with, tier 1.
## TUN-SCORE-LONGHUNT-2
@export_range(100.0, 200.0, 0.1) var longhunt_2: float = 150.0

## Tier-1 threshold, measured from contract assignment or from first Compass lock, whichever is
## later.
## TUN-SCORE-LONGHUNT-T1
@export_range(15.0, 30.0, 0.1) var longhunt_t1: float = 20.0

## Tier-2 threshold. Pays for the patient stalk that the whole game is about, and specifically
## counteracts the incentive to rush a kill before someone else's contract graph shifts.
## TUN-SCORE-LONGHUNT-T2
@export_range(35.0, 70.0, 0.1) var longhunt_t2: float = 45.0

## Killing the player who last killed you. Only the most recent killer counts, and only until you
## die again. Emotional payoff, cheap to implement, generates stories.
## TUN-SCORE-VENDETTA
@export_range(75.0, 150.0, 0.1) var vendetta: float = 100.0

## n = bonus types earned on this kill for the first time in the current life. Excludes itself,
## SCORE-CONTRACT and SCORE-RECKLESS. Resets on death. Pays for varying your approach across a
## streak. (ASM-0017)
## TUN-SCORE-VARIETY
@export_range(25.0, 75.0, 0.1) var variety: float = 50.0

## Suspicion ≥ TUN-SUSPICION-TIER-EXPOSED at initiation. The only penalty. Makes a sprinting kill
## worth 50 points against a blended kill's 550+ — the 11× ratio the design brief demands, and
## then some.
## TUN-SCORE-RECKLESS
@export_range(-100.0, -25.0, 0.1) var reckless: float = -50.0

## Equals TUN-STUN-SCORE. Defence pays like offence.
## TUN-SCORE-STUN
@export_range(75.0, 150.0, 0.1) var stun: float = 100.0

## Stunning a non-pursuer. Zero, plus TUN-STUN-INVALID-STAGGER and TUN-STUN-INVALID-SUSPICION.
## TUN-SCORE-STUN-INVALID
@export var stun_invalid: float = 0.0

## Dying costs no points. Only time. A points penalty for dying would make a losing player's
## position unrecoverable and would push them toward the safest, most boring play — which is the
## opposite of what a trailing player should do.
## TUN-SCORE-DEATH-PENALTY
@export var death_penalty: float = 0.0
