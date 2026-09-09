## The match's phases, server-side. TDD-01 §5, TDD-10.
##
## PURE and Core, because the phase gates rules — `Authority` refuses input
## outside play, scoring multiplies inside `FINAL` — and a rule that decides
## something belongs where it can be tested with no engine.
##
## **THE NAMES MATCH `GameState.Phase`, AND THAT IS NOT DUPLICATION.**
## `GameState` is the client's read-only *mirror* of what the server said; this
## is the server's own answer. Merging them would put the authority and its
## reflection in one object, and the first bug would be a client writing the
## phase it is supposed to be told.
##
## The ordinals are the wire: `NET-S2C-PHASE-CHANGED` carries `phase:u8`, so
## reordering them silently remaps every client's idea of what is happening.
class_name MatchPhase
extends RefCounted

enum Phase { LOBBY, WARMUP, ACTIVE, FINAL, RESULTS }


## Whether the match clock is running and inputs move pawns.
##
## **WARMUP IS NOT PLAYING.** Pawns exist by then, so anything that inferred
## "playing" from a pawn's existence would let a player move before the clock
## they are scored against started.
static func is_playing(phase: int) -> bool:
	return phase == Phase.ACTIVE or phase == Phase.FINAL


## Whether systems should tick at all. Nothing gameplay-relevant advances in the
## lobby or over the results fold — a suspicion value that decayed during the
## results screen would change a number players are still reading.
static func is_simulating(phase: int) -> bool:
	return phase == Phase.WARMUP or is_playing(phase)


## Whether a player is looking at this phase and must be told what it holds.
##
## **THIS IS NOT `is_simulating`, AND CONFLATING THE TWO COST THE RESULTS SCREEN
## ITS CLOCK.** `MatchDirector` emitted the end of a tick only while simulating, so
## the instant a match reached `RESULTS` the snapshots stopped — every client's last
## one said `FINAL`, `ticks_remaining` froze on whatever the final tick carried, and
## the unanimous skip had **no channel at all** to end the screen through. Found by
## the second agent on 2026-09-09, against a claim of mine from the day before.
##
## *Nothing advances* and *nobody is told* are different questions. A results screen
## is a phase in which nothing may change and everything must still be visible.
##
## **`LOBBY` IS DELIBERATELY OUT.** There is no world to describe yet — no pawns, no
## crowd placed, no match — and a snapshot of one describes nothing. What a lobby
## screen needs is a roster and a player count, which is US-0078's message rather
## than this one's format.
static func is_watched(phase: int) -> bool:
	return is_simulating(phase) or phase == Phase.RESULTS
