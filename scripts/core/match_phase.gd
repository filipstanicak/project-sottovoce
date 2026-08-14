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
