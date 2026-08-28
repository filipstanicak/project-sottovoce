## **THE TWO WINDOWS THAT NEED REAL BUFFERS, AND THE TWO FACTS THAT NEED A
## MEMORY.** TDD-10 §2.1, US-0065. PURE.
##
## Four bonuses cannot be answered from the tick they are asked on:
##
## - **Patient** needs the last `TUN-SCORE-PATIENT-WINDOW` of speed samples, so it
##   cannot be gamed by decelerating at the last moment.
## - **Focus** needs an unbroken-line-of-sight streak that survives an NPC walking
##   through it.
## - **Long Hunt** needs when this hunt started.
## - **Vendetta** needs who killed you last.
##
## **THIS LIVES ON `MatchContext`, NOT ON `PawnContext`, AND TDD-10 §2.1 IS
## AMENDED.** That section writes `var speed_history: PackedFloat32Array` on the
## pawn. `PawnContext` is **replayed during prediction reconciliation** (never-do
## #9), so a client replaying twenty commands would push twenty duplicate speed
## samples into a gameplay buffer — and the ring would then say a patient player
## sprinted. It is US-0052's finding about the suspicion impulse queue, in a second
## place: *a system reaching another system's state does it through the context.*
##
## **AND IT IS SAMPLED BEFORE THE `combat` STAGE, NEVER AT the `score` STAGE.**
## Every bonus is judged at kill *initiation*, which is stage 7; a sampler at stage
## 9 would answer every question one tick late. `SYS-SUSPICION` (stage 4) already
## reads horizontal speed and `SYS-DETECTION` (stage 5) already asks the Compass
## lock's line-of-sight question, so both windows ride passes that exist.
class_name ScoreWindows
extends RefCounted

## Peer -> ring of horizontal speeds, `TUN-SCORE-PATIENT-WINDOW` long.
var _speed: Dictionary = {}

## Peer -> next write index into its ring.
var _speed_at: Dictionary = {}

## Peer -> [unbroken ticks, grace ticks remaining].
var _focus: Dictionary = {}

## Peer -> the tick this hunt started, which is the LATER of the contract
## assignment and the first Compass lock.
var _hunt_from: Dictionary = {}

## Peer -> who killed them last, or 0. Cleared by the next death, which is what
## makes "and has not died since" true without a second field.
var _killed_by: Dictionary = {}

# ------------------------------------------------------------- Patient ---


## One horizontal speed sample. **Horizontal, because a grounded
## `CharacterBody3D` keeps a small downward velocity from its floor snap** — the
## finding that would have made `PASV-STILLNESS` dead on arrival (US-0052).
func sample_speed(peer: int, horizontal: float, window_ticks: int) -> void:
	var size := maxi(window_ticks, 1)
	var ring: PackedFloat32Array = _speed.get(peer, PackedFloat32Array())
	if ring.size() != size:
		ring = PackedFloat32Array()
		ring.resize(size)
		_speed[peer] = ring
		_speed_at[peer] = 0
	var at := int(_speed_at.get(peer, 0)) % size
	ring[at] = horizontal
	_speed[peer] = ring
	_speed_at[peer] = (at + 1) % size


## The fastest this player has moved inside the window. **A ring that has not
## filled yet reads as slow, and that is deliberate rather than a coincidence of
## zero-initialisation**: "never exceeded the speed in the 10 s before initiation"
## is *true* of a player who has only existed for three of them. Denying the bonus
## for the first ten seconds of every life would punish a respawn for the timing of
## its own death.
func peak_speed(peer: int) -> float:
	var ring: PackedFloat32Array = _speed.get(peer, PackedFloat32Array())
	var peak := 0.0
	for sample: float in ring:
		peak = maxf(peak, sample)
	return peak


# --------------------------------------------------------------- Focus ---


## One tick of the line-of-sight streak on this player's own contract.
##
## **THE GRACE PRESERVES THE STREAK RATHER THAN PAUSING IT** (TDD-10 §2.1): a tick
## spent behind a passing NPC still counts toward the window. Without that the
## bonus is unearnable in a crowd, which is exactly where it should be earned.
func sample_focus(peer: int, has_los: bool, grace_ticks: int) -> void:
	var row: Array = _focus.get(peer, [0, 0])
	if has_los:
		row = [int(row[0]) + 1, maxi(grace_ticks, 0)]
	elif int(row[1]) > 0:
		row = [int(row[0]) + 1, int(row[1]) - 1]
	else:
		row = [0, 0]
	_focus[peer] = row


func focus_ticks(peer: int) -> int:
	return int((_focus.get(peer, [0, 0]) as Array)[0])


## A reassignment ends the streak: a window built watching one contract says
## nothing about the next, and carrying it across would pay Focus for attention
## the player never spent on the person they killed.
func break_focus(peer: int) -> void:
	_focus[peer] = [0, 0]


# ------------------------------------------------------------ Long Hunt ---


## The contract was assigned. **Never overwrites a hunt already under way** for the
## same contract — `SYS-CONTRACT` announces once, and a second call would restart
## the clock a player has already been paying for.
func begin_hunt(peer: int, tick: int) -> void:
	_hunt_from[peer] = tick


## The first Compass lock on this contract. **Whichever is LATER wins** (US-0065's
## criterion): a hunt only really begins when you know who you are looking for, so
## an assignment you have not acted on does not accrue.
func note_lock(peer: int, tick: int) -> void:
	if tick > int(_hunt_from.get(peer, 0)):
		_hunt_from[peer] = tick


func hunt_ticks(peer: int, now: int) -> int:
	if not _hunt_from.has(peer):
		return 0
	return maxi(now - int(_hunt_from[peer]), 0)


# ------------------------------------------------------------- Vendetta ---


## **CLEARED BY THE NEXT DEATH, WHICH IS WHY THERE IS NO SECOND FIELD.** "And has
## not died since" falls out of an overwrite: die to somebody else and they are
## the debt you are owed now.
func note_killed_by(victim: int, killer: int) -> void:
	_killed_by[victim] = killer


func avenges(killer: int, victim: int) -> bool:
	return _killed_by.get(killer, 0) == victim and victim != 0


# ----------------------------------------------------------- lifecycle ---


## A death ends both windows. The speed ring is not cleared — a corpse does not
## move, so it fills with zeros on its own, and clearing it would be a second rule
## saying the same thing.
func report_death(peer: int) -> void:
	break_focus(peer)
	_hunt_from.erase(peer)


func forget(peer: int) -> void:
	_speed.erase(peer)
	_speed_at.erase(peer)
	_focus.erase(peer)
	_hunt_from.erase(peer)
	_killed_by.erase(peer)
	for victim: int in _killed_by.keys():
		if int(_killed_by[victim]) == peer:
			_killed_by.erase(victim)
