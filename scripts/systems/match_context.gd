## **EVERYTHING A SYSTEM NEEDS, PASSED EXPLICITLY.** TDD-01 §5.
##
## The project's dependency-injection seam: **if it is not on `MatchContext`, a
## system cannot reach it.** Systems receive their dependencies rather than
## looking them up, so the whole dependency graph is visible in one file instead
## of scattered across thirty `get_node` calls that only fail at runtime.
##
## Constructed by `MatchDirector`, once per match, and torn down with it.
##
## **THE FIELDS ARRIVE WITH THEIR SYSTEMS.** TDD-01 §5 lists `crowd`, `cycle`,
## `score_log` and `lag_comp` too. Declaring them now as nulls of types that do
## not exist would be four fields nobody can use and one compile error each time
## someone renames a class that has not been written. They land in M3 and M4 with
## the systems that own them.
##
## In `scripts/systems/` rather than `scripts/core/`, where TDD-01 §6's file
## table puts it. Core is pure by law — `test_core_is_pure.gd` — and a context
## holding live pawns is server state, not a value type. The document's own
## §1.3 draws the line where the guard does.
class_name MatchContext
extends RefCounted

## **MONOTONIC SERVER TICK SINCE MATCH START.** Never wall-clock, never a frame
## count: it is the number every deterministic thing in the project is written
## against, and it advances exactly once per net tick even if a frame took 200 ms.
var tick: int = 0

## `MatchPhase.Phase`. The server's own answer, not the client's mirror.
var phase: int = MatchPhase.Phase.LOBBY

## peer id -> the authoritative pawn. Populated by `SYS-SPAWN` in M4; the
## director exposes it now because the pawn substep walks it.
var pawns: Dictionary = {}

## `MapData` for the loaded map. Read-only to systems.
var map: MapData = null

## The seeded RNG. **THE ONLY SOURCE OF GAMEPLAY RANDOMNESS**, server-side —
## `randf` and `randi` are banned outside `scripts/presentation/`, because a
## match must replay identically from its seed.
var rng: RandomNumberGenerator = null


## Seconds per net tick. Every system's `tick(ctx, dt)` receives exactly this.
static func net_dt() -> float:
	return 1.0 / Tuning.net.server_tick


## Seconds per pawn substep. Half of `net_dt()`, and the difference matters:
## see `MatchDirector._substep_pawns`.
static func step_dt() -> float:
	return 1.0 / Tuning.net.client_input_rate


## Seconds since the match started, derived from the tick rather than measured.
##
## Derived on purpose. A clock read from `Time` would drift from the tick count
## under load, and then two answers to "how long is left" would exist — one the
## players see and one the scoring uses.
func elapsed() -> float:
	return float(tick) * net_dt()
