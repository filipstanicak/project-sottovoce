## **EVERYTHING A KILL IS JUDGED ON, CAPTURED AT INITIATION.** TDD-10 §2,
## US-0065. PURE.
##
## **THE POINT IS THE TENSE.** GDD-07 §3 evaluates every bonus at the moment the
## player *pressed*, not at the moment the body falls — a hunter who was Anonymous
## when they committed does not lose Silent because the 0.9 s animation made them
## conspicuous, and one who sprinted into range does not gain Patient by standing
## still through it. A record captured at initiation and paid at the contact frame
## is that rule expressed as a data flow rather than as a comment.
##
## **PLAIN FIELDS AND NO CONSTRUCTOR, DELIBERATELY.** Twelve values do not belong
## in a positional signature — `.gdlintrc` caps one at six and calls the limit a
## design signal — and this is transport rather than a value type: it is filled
## field-by-field by the one function that can see the world, and read once.
## `ScoreEvent` is the immutable end of that pipeline.
class_name KillScoreFacts
extends RefCounted

## The initiation tick. Freezes the final-phase multiplier on every event.
var tick: int = 0

var killer: int = 0
var victim: int = 0

## The killer's tier at initiation, from `SuspicionMath.evaluate_tier` by way of
## `PawnContext.tier`. **The tier and not the raw value**, so the hysteresis that
## decides what the player was *shown* also decides what they are paid.
var tier: int = 0

## True when the whole `TUN-SCORE-PATIENT-WINDOW` was under
## `TUN-SCORE-PATIENT-SPEED`.
var patient: bool = false

## `ABIL-SECONDFACE` active. **Always false in the MVP** until US-0069.
var masked: bool = false

## Unbroken line-of-sight ticks on the contract, grace included.
var focus_ticks: int = 0

## `killer.y - victim.y` at initiation. Metres.
var height: float = 0.0

## Inside a blend action, or within `TUN-BLEND-SCORE-GRACE` of leaving one.
var blended: bool = false

## Ticks since this hunt began — the later of the contract assignment and the
## first Compass lock.
var hunt_ticks: int = 0

## The victim is the player who last killed the killer.
var vendetta: bool = false

## A delayed-kill ability landed this. **Dormant in the MVP** (ASM-0016): no MVP
## ability sets it, and `ABIL-NIGHTSHADE` is post-MVP. Implemented and tested
## rather than absent, so the day an ability wants it there is nothing to design.
var poisoned: bool = false
