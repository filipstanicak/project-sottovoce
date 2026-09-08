## WHEN EACH PHASE ENDS, IN NET TICKS. Pure, Core, and it reads no autoload.
##
## US-0079's phases are driven by tick counts and never by wall time (TDD-10 §6),
## so every transition in the match is arithmetic — and arithmetic belongs where it
## can be asked a question with no engine standing up. `ContractCycle` and
## `ScoreFold` are the same shape for the same reason.
##
## **IT TAKES A `MatchTuning` RATHER THAN READING `Tuning`, AND THAT IS NOT
## FASTIDIOUSNESS.** `ScoreEvent.multiplier_at` already takes one, and these two
## must agree about a single instant — see `final_opens_at` below. Two functions
## that read the live profile independently agree until somebody adopts a second
## one; two functions handed the same object cannot disagree at all.
##
## **WHAT THIS CLASS DELIBERATELY DOES NOT KNOW:** how many players are connected.
## `LOBBY` ends when the lobby is full enough, which is a fact about peers rather
## than about a clock, so `duration_ticks` answers `NO_CLOCK` for it and the system
## above decides. A clock that also counted players would be the place a
## player-count rule quietly acquired a timeout nobody documented.
class_name MatchClock
extends RefCounted

## `duration_ticks` for a phase that does not end on a clock at all.
const NO_CLOCK := -1


## Seconds to net ticks against this profile's own rate.
##
## `Tuning.ticks()` converts against the live autoload and takes a `TUN-` id; this
## takes the resource it was handed, so a test can drive a profile the autoload has
## never seen. Trap 9's two domains still apply: these are NET ticks, 30 Hz.
static func ticks_of(seconds: float, rules: MatchTuning) -> int:
	return int(round(seconds * maxf(rules.tick_rate, 1.0)))


## How long `phase` lasts, or `NO_CLOCK` when it does not end on one.
##
## **`ACTIVE` IS THE MATCH MINUS THE FINAL CONTRACT, NOT THE WHOLE MATCH.**
## `TUN-MATCH-DURATION` 480 s is the pair: 450 s of `ACTIVE` and 30 s of `FINAL`.
## Reading it as the length of `ACTIVE` would run a 510 s match and put the
## multiplier boundary 30 s past where scoring already puts it.
static func duration_ticks(phase: int, rules: MatchTuning) -> int:
	match phase:
		MatchPhase.Phase.LOBBY:
			return NO_CLOCK
		MatchPhase.Phase.WARMUP:
			return ticks_of(rules.lobby_countdown, rules)
		MatchPhase.Phase.ACTIVE:
			return ticks_of(rules.duration - rules.finalphase_duration, rules)
		MatchPhase.Phase.FINAL:
			return ticks_of(rules.finalphase_duration, rules)
		MatchPhase.Phase.RESULTS:
			return ticks_of(rules.results_duration, rules)
	return NO_CLOCK


## The phase that follows this one once its clock runs out.
##
## `RESULTS` returns itself: a match that has shown its result has nowhere to go,
## and returning `LOBBY` would restart it on a timer nobody asked for. Whether a
## server re-opens is US-0078's, and it is a decision rather than a fall-through.
static func next_phase(phase: int) -> int:
	match phase:
		MatchPhase.Phase.WARMUP:
			return MatchPhase.Phase.ACTIVE
		MatchPhase.Phase.ACTIVE:
			return MatchPhase.Phase.FINAL
		MatchPhase.Phase.FINAL:
			return MatchPhase.Phase.RESULTS
	return phase


## The tick, counted from the first tick of `ACTIVE`, at which `FINAL` opens.
##
## **THIS IS THE ONE HOME FOR THAT INSTANT, AND `ScoreEvent` READS IT.** The
## corpus's own instruction for this story was that US-0079 must *read* the
## boundary scoring already derives rather than decide it again, "or the phase the
## HUD announces and the phase the points are paid at will drift" — a defect worth
## naming precisely because it needs both halves to be seen at once, which no test
## of either alone can do.
static func final_opens_at(rules: MatchTuning) -> int:
	return duration_ticks(MatchPhase.Phase.ACTIVE, rules)


## The tick, from the first tick of `ACTIVE`, at which the warning is announced.
##
## **A WARNING IS NOT A PHASE, AND THE ENUM IS WHY.** US-0079's description says
## six phases; its own criterion says the warning "changes NO rules". `MatchPhase`'s
## ordinals are the wire — `NET-S2C-PHASE-CHANGED` carries `phase:u8` — so a sixth
## name inserted for something that changes nothing would remap every client's idea
## of what is happening, which is `PawnStateId.ALL`'s hazard in a second enum. It is
## an announcement at a tick, and this is that tick.
static func warning_at(rules: MatchTuning) -> int:
	return final_opens_at(rules) - ticks_of(rules.finalphase_warning, rules)


## True on the tick the elapsed count CROSSES `at`, never on equality alone.
##
## **THE SKETCH IN TDD-10 §6 COMPARES `ticks_remaining ==` AND THAT IS FRAGILE.**
## An exact equality fires only if the clock lands on the value; anything that ever
## advances it by more than one — a catch-up after a hitch, a rejoin, a test that
## steps in tens — skips the announcement in silence, and a warning that sometimes
## does not arrive is worse than none, because players learn to stop expecting it.
## A crossing cannot be skipped: it asks whether the boundary is now behind you and
## was not before.
static func crossed(previous_elapsed: int, elapsed: int, at: int) -> bool:
	return previous_elapsed < at and elapsed >= at
