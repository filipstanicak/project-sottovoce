## **NINETY NPCs, ALLOCATED ONCE.** TDD-08 §2, US-0039. SERVER ONLY.
##
## **NOTHING IS INSTANTIATED OR FREED BETWEEN MATCH START AND END.** Instantiating
## a `CharacterBody3D` with a `NavigationAgent3D` mid-match is a frame spike, and
## a frame spike in a game decided at 2.5 m inside a 0.4 s window is a lost kill.
##
## **SIZED TO `TUN-CROWD-COUNT-MAX` REGARDLESS OF THE ACTIVE COUNT**, so that
## player-count scaling never allocates. A four-player match activates 66 of the
## 90 and the other 24 sit inactive — hidden, skipped by every system, and still
## there. That is the whole point: the difference between a 4-player crowd and a
## 6-player crowd must cost nothing at the moment it changes.
##
## Deactivation is **not** deallocation and never becomes it. An inactive NPC
## keeps its node, its body and its agent; it loses only its place in the roster.
class_name NpcPool
extends Node

## An NPC appeared in the world. Past tense.
signal npc_activated(index: int)

const NPC_SERVER := "res://scenes/npc/npc_server.tscn"

## Every NPC's identity, by index: a persona ID for a clone, an archetype ID for
## filler. Empty until `activate()`.
var roster: Array[StringName] = []

## **THE ACTUAL NODES.** Ninety `CharacterBody3D`s, created once and never freed.
## Allocating slots without bodies would satisfy the criterion's words and miss
## its point entirely — the cost this story exists to move off the hot path is
## the body, not the array entry.
var _npcs: Array[CharacterBody3D] = []

## **ONE BRAIN AND ONE CONTEXT PER BODY, ALLOCATED WITH IT.** `NpcBrain.reset()`
## was written for this in US-0040 — the pool reuses brains along with the
## bodies, so a match end costs no allocation and a match start costs none
## either. They live here rather than on `CrowdDirector` for the same reason the
## bodies do: the no-mid-match-allocation rule is checkable by reading one file.
var _brains: Array[NpcBrain] = []
var _contexts: Array[CrowdContext] = []

var _capacity: int = 0
var _active: int = 0
var _positions: PackedVector3Array = PackedVector3Array()
var _allocated: bool = false


## Allocate the ceiling. **Called during COUNTDOWN, before the first PLAYING
## tick** — never from `activate()`, which is what keeps the no-mid-match-alloc
## rule checkable by reading rather than by profiling.
##
## Idempotent: calling it twice does not reallocate, because a second call would
## be exactly the mid-match spike this exists to prevent.
func preallocate(count: int = -1) -> void:
	if _allocated:
		return
	_capacity = count if count > 0 else int(Tuning.crowd.count_max)
	_positions.resize(_capacity)

	var scene := load(NPC_SERVER) as PackedScene
	for index: int in _capacity:
		var npc := scene.instantiate() as CharacterBody3D
		npc.name = "Npc%03d" % index
		# **INACTIVE MEANS HIDDEN AND SKIPPED, NEVER FREED.** Collision off as well
		# as visibility: an inactive NPC that still had a collider would be an
		# invisible wall in the middle of the district.
		npc.process_mode = Node.PROCESS_MODE_DISABLED
		npc.visible = false
		add_child(npc)
		_npcs.append(npc)
		_brains.append(NpcBrain.new())
		_contexts.append(CrowdContext.new())
	_allocated = true
	Log.info("NpcPool: %d bodies allocated" % _capacity, &"crowd")


## Bring `count` NPCs into the world with identities derived from the seed.
##
## **DERIVES, NEVER RECEIVES.** The roster is computed from `match_seed` on every
## peer independently (GDD-03 §6.3 rule 4). Handing it over the wire would cost
## bandwidth and, far worse, would make a desync possible at all.
##
## Refuses a count above what was allocated rather than growing to fit: growing
## is the frame spike.
func activate(count: int, match_seed: int, personas_in_use: Array, players: int) -> bool:
	if not _allocated:
		Log.error("NpcPool.activate before preallocate", &"crowd")
		return false
	if count > _capacity:
		Log.error(
			"NpcPool: %d requested, %d allocated — refusing to grow" % [count, _capacity], &"crowd"
		)
		return false

	roster = CrowdRoster.derive(count, match_seed, personas_in_use, players)
	_active = count
	for index: int in _capacity:
		# **A REUSED BRAIN CARRIES THE LAST MATCH'S STATE UNLESS IT IS RESET.** An
		# NPC that entered the new match already Startled would flee from a violence
		# that happened in a match nobody in this one played.
		_brains[index].reset()
		_contexts[index].clear_events()
		var live := index < count
		_npcs[index].process_mode = (
			Node.PROCESS_MODE_INHERIT if live else Node.PROCESS_MODE_DISABLED
		)
		_npcs[index].visible = live
		if live:
			npc_activated.emit(index)
	return true


func capacity() -> int:
	return _capacity


## How many are in the world. The rest are inactive, not absent.
func active_count() -> int:
	return _active


func is_active(index: int) -> bool:
	return index >= 0 and index < _active


## The persona or archetype at `index`, or `&""` for an inactive slot.
func identity_of(index: int) -> StringName:
	if not is_active(index) or index >= roster.size():
		return &""
	return roster[index]


## **READ FROM THE BODY, NEVER FROM THE CACHE.** The body is where an NPC actually
## is: `Steering` moves it from `NavigationAgent3D`'s avoidance callback on the
## **physics** frame, and nothing calls `set_position` after placement.
##
## **THIS RETURNED THE CACHE UNTIL US-0031, AND IT WAS STALE FOR THE WHOLE MATCH.**
## Nothing read it, so nothing was wrong — until `SnapshotBuilder._fill_crowd`
## became its first consumer and would have replicated all seventy-eight NPCs at
## their **spawn anchors, forever**, on a live server. No error, no failing test:
## every client would simply have seen a frozen city, and the one symptom would
## have been a playtester saying the crowd looked like statues.
##
## It was found because the NPC delta measured 25 % of the bandwidth budget where
## the change fraction said 78 % of records move every tick. **A number far better
## than the mechanism can explain is a broken measurement**, and this time it was a
## broken program underneath it.
func position_of(index: int) -> Vector3:
	var body := body_of(index)
	return body.global_position if body != null else Vector3.ZERO


## Place an NPC. The cache is kept in step for `_positions`' own sake, but the
## body is the authority and `position_of` reads that.
func set_position(index: int, position: Vector3) -> void:
	if index < 0 or index >= _positions.size():
		return
	_positions[index] = position
	_npcs[index].global_position = position


## The body at `index`. For tests and for the systems that will steer it in M3.
func body_of(index: int) -> CharacterBody3D:
	return _npcs[index] if index >= 0 and index < _npcs.size() else null


## The navigation agent at `index`, or null. Named rather than found by type: a
## `get_node` that silently returned null would disable steering for that NPC
## and look exactly like an NPC with nowhere to go.
func agent_of(index: int) -> NavigationAgent3D:
	var body := body_of(index)
	return null if body == null else body.get_node_or_null(^"Agent") as NavigationAgent3D


func brain_of(index: int) -> NpcBrain:
	return _brains[index] if index >= 0 and index < _brains.size() else null


func context_of(index: int) -> CrowdContext:
	return _contexts[index] if index >= 0 and index < _contexts.size() else null


## How many bodies exist, active or not. **Never falls** during a match.
func body_count() -> int:
	return _npcs.size()


## Stand the crowd down at match end. **Clears the roster; keeps the
## allocation.** The pool outlives a match precisely so the next one does not pay
## for it.
func deactivate_all() -> void:
	roster.clear()
	_active = 0
	for npc: CharacterBody3D in _npcs:
		npc.process_mode = Node.PROCESS_MODE_DISABLED
		npc.visible = false
