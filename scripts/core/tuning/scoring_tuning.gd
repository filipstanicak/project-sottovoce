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

## Suspicion ≤ 29 (Anonymous) at initiation. Re-priced 2026-08-26 from +100 (ADR-0013) to the
## reference's own value for the same condition: a kill where the hunter was briefly conspicuous
## but is not conspicuous now. With SCORE-PATIENT it sums to 300, which is what the reference
## pays for an approach that was never conspicuous at all — the two bonuses together are its top
## stealth rung, split across an instantaneous half and a sustained one.
## TUN-SCORE-SILENT
@export_range(150.0, 250.0, 0.1) var silent: float = 200.0

## Never exceeded TUN-SCORE-PATIENT-SPEED in the 10 s before initiation. Re-priced 2026-08-26
## from +150 (ADR-0013). It is now the smaller half of the stealth ladder, and invariant 18 is
## amended to say so: the reference pays 200 for being unseen at the moment of the kill and 300
## for having been unseen throughout, so the sustained half is worth 100 on top, not more than
## the instantaneous half. What the pair sums to is the number that matters.
## TUN-SCORE-PATIENT
@export_range(75.0, 150.0, 0.1) var patient: float = 100.0

## The lookback window for SCORE-PATIENT. Long enough that it cannot be gamed by decelerating at
## the last moment.
## TUN-SCORE-PATIENT-WINDOW
@export_range(8.0, 15.0, 0.1) var patient_window: float = 10.0

## The speed SCORE-PATIENT requires you never to have exceeded. This was TUN-SPEED-JOG until the
## ladder lost that rung, and the number is deliberately unchanged — patience means exactly what
## it meant before, but it is a scoring threshold now rather than a speed anything travels at. It
## sits above TUN-SPEED-STROLL and below TUN-SPEED-RUN (invariant §17.23), which is what makes it
## a real line: a patient player may drift above their cruising speed while accelerating or being
## shoved by a crowd, and may not run.
## TUN-SCORE-PATIENT-SPEED
@export_range(2.6, 4.4, 0.1) var patient_speed: float = 3.4

## Suspicion in Noticed (30–69) at initiation — seen, but not conspicuously. Added 2026-08-27 by
## the fidelity re-audit, which found our stealth ladder was a cliff where the reference's is a
## staircase. With SCORE-SILENT at 200 and SCORE-RECKLESS at 0, a kill taken at Noticed — the
## commonest careless kill there is — paid the base 100 and nothing more, so being slightly seen
## cost exactly as much as being caught in the open. The reference pays its lowest rung for this,
## and this is that rung. The value is the weakest-sourced number in this table: the reference's
## own is inferred at 50 from a sequel raising that bonus to 150 and giving its old 50 to the
## rung below — treat the 50 as a shape rather than a measurement. It is also exactly half the
## unit of account, which is the only other thing pointing at it. Invariant 32 keeps the ladder
## monotone and strictly positive here, so the cliff cannot come back by a retune.
## TUN-SCORE-HALFSEEN
@export_range(25.0, 100.0, 0.1) var halfseen: float = 50.0

## ABIL-SECONDFACE active at initiation. Equal to Patient: disguise is a different route to the
## same virtue.
## TUN-SCORE-MASKED
@export_range(100.0, 200.0, 0.1) var masked: float = 150.0

## Re-priced 2026-08-26 from +100 (ADR-0013) to the reference's exact value.
## TUN-SCORE-FOCUS
@export_range(100.0, 200.0, 0.1) var focus: float = 150.0

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

## Suspicion ≥ TUN-SUSPICION-TIER-EXPOSED at initiation. Neutralised 2026-08-26 from −50
## (ADR-0013): the reference has no penalty of any kind. Its enforcement is that a careless kill
## earns less, never that it costs. An Exposed kill already forfeits SCORE-SILENT and SCORE-
## PATIENT — 300 points — so a further −50 was punishment the reference does not levy. The event
## still fires and is still shown, at zero: the score feed telling you you were seen is the
## feedback, and deleting the event would delete the lesson with the penalty. The ID is retained
## rather than reused (§19).
## TUN-SCORE-RECKLESS
@export_range(-100.0, 0.0, 0.1) var reckless: float = 0.0

## Equals TUN-STUN-SCORE. 100 → 200 on 2026-09-03 (ADR-0018): the reference pays 200 for a stun
## against 100 for a base assassination, so the old value under-paid the prey by half while
## claiming to be design law 5 written as a number. It still loses to a well-made kill (100 + up
## to 400 of stealth bonuses), which is the reference's ordering and the one law 5 now states.
## Invariant 19 is a floor, not a ratio.
## TUN-SCORE-STUN
@export_range(75.0, 250.0, 0.1) var stun: float = 200.0

## Added 2026-08-29 (US-0097, ADR-0014). Your pursuer's chase timer emptied while you were the
## prey. The reference's own value, and it lands equal to a base kill: surviving a hunt is worth
## what ending one is. This row used to add "and to TUN-SCORE-STUN" and that stopped being true
## on 2026-09-03, when ADR-0018 took the stun to 200 — the row directly above this one. The value
## is unchanged and is not in question; ADR-0014 sourced it and got it exactly. What changed is
## that the prey's three teeth are not priced alike: a read stun is the expensive one. Invariant
## 37.
## TUN-SCORE-ESCAPE
@export_range(75.0, 150.0, 0.1) var escape: float = 100.0

## Added 2026-08-29 (US-0097, ADR-0014). …and the hunter was still within TUN-PURSUIT-CLOSECALL-
## RADIUS 5.0 m when it emptied. The reference's own value. Half an escape, because escaping from
## under the hunter's nose is the same achievement performed under pressure rather than a
## different achievement.
## TUN-SCORE-CLOSECALL
@export_range(25.0, 100.0, 0.1) var closecall: float = 50.0

## Stunning a non-pursuer. Zero, plus TUN-STUN-INVALID-STAGGER and TUN-STUN-INVALID-SUSPICION.
## TUN-SCORE-STUN-INVALID
@export var stun_invalid: float = 0.0

## Dying costs no points. Only time. A points penalty for dying would make a losing player's
## position unrecoverable and would push them toward the safest, most boring play — which is the
## opposite of what a trailing player should do.
## TUN-SCORE-DEATH-PENALTY
@export var death_penalty: float = 0.0
