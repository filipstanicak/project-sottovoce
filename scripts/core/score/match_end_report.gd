## **WHAT A CLIENT IS TOLD WHEN THE MATCH ENDS.** `NET-S2C-MATCH-END`, US-0077.
## PURE Core: it is what `MatchEndWire.unpack` produces and what the results screen
## reads, and it decides nothing.
##
## **THE EVENTS ARE REAL `ScoreEvent`s, NOT A SUMMARY**, which is US-0077's third
## criterion made structural rather than promised: *the breakdown is derived from the
## SAME fold as the totals, so they cannot disagree*. `ScoreFold.fold` produces the
## placement and `ScoreFold.breakdown` the per-bonus rows, from this one array — so
## there is no second arithmetic anywhere for the two to disagree across.
##
## **AND THE MULTIPLIER IS RE-DERIVED RATHER THAN SENT.** `ScoreEvent` has one
## constructor and it freezes `TUN-MATCH-FINALPHASE-MULT` from the event's own tick,
## which is exactly why no inconsistent event can be built (US-0064). A client
## rebuilding events from the wire therefore gets the same number the server paid,
## from the same rules — the handshake refuses a peer whose `TuningProfile` hash
## differs, and `_tuning_sync` corrects one that merely lags. Sending the multiplier
## as well would be a second source of truth for a value already implied by two
## fields that are on the wire.
##
## **EVERY ID HERE IS A WIRE SLOT, NEVER A PEER.** `SlotTable` exists so the
## engine's random 32-bit ids never reach a client, and a results screen is not the
## place to make an exception.
class_name MatchEndReport
extends RefCounted

## Slot -> net ticks spent at `Tier.ANONYMOUS` over the whole match.
var anonymous_ticks: Dictionary = {}

## Slot -> `Array[StringName]` of `ABIL-` ids, in loadout slot order.
var kits: Dictionary = {}

## Every `ScoreEvent` of the match, actors and subjects addressed by slot.
var events: Array[ScoreEvent] = []


## The slots this report describes, in the order the server packed them.
func slots() -> Array:
	return anonymous_ticks.keys()


## Seconds spent Anonymous, for a screen that prints seconds rather than ticks.
##
## **THE RATE COMES FROM THE RULES RATHER THAN FROM A LITERAL 30**, because
## `TUN-MATCH-TICK-RATE` is a tunable and a screen that hardcoded it would print a
## number that quietly stopped being true.
func anonymous_seconds(slot: int, rules: MatchTuning) -> float:
	return float(int(anonymous_ticks.get(slot, 0))) / maxf(rules.tick_rate, 1.0)
