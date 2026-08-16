## **A BODY IS AN INFORMATION OBJECT, NOT A PROP.** `SYS-CORPSE`. GDD-03 §6.4,
## TDD-08 §3.3, US-0044. SERVER ONLY, and PURE — a point and two tick numbers.
##
## **IT SAYS TWO DIFFERENT THINGS AT TWO DIFFERENT TIMES**, and that is the whole
## reason `TUN-CROWD-GAWK-DURATION` (6 s) is shorter than `TUN-CORPSE-LIFETIME`
## (20 s) — invariant 13:
##
## **0–6 s.** Six NPCs staring at a point. Readable at 25 m as "something happened
## *just now*, over there", and it means the killer may still be nearby.
##
## **6–20 s.** A body on the ground and the crowd back to normal. Readable only up
## close, and it means somebody respawned and a contract has shifted.
##
## Collapse the two and the corpse becomes one signal instead of two: a cluster
## that lasted the body's whole life would say "a kill is happening here" for
## twenty seconds, and a cluster that never formed would make a kill in a busy
## market invisible from ten metres away.
class_name Corpse
extends RefCounted

## Where the body is. The gawk radius is measured from here, not from the killer.
var position: Vector3 = Vector3.ZERO

## The server tick it appeared on. **A tick, never a wall clock**: everything
## deterministic in this project is written against the tick, and a corpse whose
## lifetime came from `Time` would expire at a different moment in a replay.
var spawned_tick: int = 0

## The peer whose death produced it, or 0 for nobody. Recorded rather than used:
## `SYS-SCORE` and the contract cycle are M4's, and a corpse that could not say
## whose it was would have to be re-derived from the score log.
var victim_peer: int = 0

## Whether anybody has been sent to look at it yet. Tokens are issued **once**, on
## the tick it spawns — a corpse that re-recruited as it aged would keep a cluster
## alive for its whole lifetime and destroy the two phases above.
var tokens_issued: bool = false


static func at(where: Vector3, tick: int, victim: int = 0) -> Corpse:
	var corpse := Corpse.new()
	corpse.position = where
	corpse.spawned_tick = tick
	corpse.victim_peer = victim
	return corpse


## Seconds since it appeared, derived from the tick like `MatchContext.elapsed()`.
func age(tick: int) -> float:
	return float(maxi(tick - spawned_tick, 0)) / Tuning.net.server_tick


func expired(tick: int) -> bool:
	return age(tick) >= Tuning.crowd.corpse_lifetime


## True while the gawk cluster should still be standing around it. Nothing reads
## this to *end* a gawk — each gawker's own timer does that, and the two agree
## because both come from `TUN-CROWD-GAWK-DURATION`. It is here so a test can ask
## the question the design states, rather than inferring it from five brains.
func gathering(tick: int) -> bool:
	return age(tick) < Tuning.crowd.gawk_duration
