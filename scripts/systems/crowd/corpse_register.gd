## **EVERY BODY ON THE GROUND, AND WHO IS LOOKING AT IT.** `SYS-CORPSE`.
## GDD-03 §6.4, TDD-08 §3.3, US-0044. SERVER ONLY.
##
## **THE GAWK CAP EXISTS FOR A NON-OBVIOUS REASON.** Without it, a corpse in a
## dense market pocket would recruit every nearby NPC — dropping the pocket below
## `TUN-BLEND-POCKET-MIN-NPC` and destroying it as a blend location. The site of a
## kill would become *safer* to stand in afterwards, which is exactly backwards.
## `TUN-CROWD-GAWK-MAX` 6 keeps the cluster visible and the pocket alive.
##
## **TOKENS ARE ISSUED ONCE, ON THE TICK THE BODY APPEARS.** A corpse that
## re-recruited as it aged would hold a cluster for its whole twenty seconds and
## collapse the two information phases into one — see `Corpse`.
class_name CorpseRegister
extends RefCounted

## Every body currently on the ground.
var corpses: Array[Corpse] = []

## npc index -> the corpse it is looking at. Kept so an expiring body can tell its
## own onlookers and nobody else's; a single "somebody's corpse went" flag would
## disperse every cluster in the district whenever any body faded.
var _watchers: Dictionary = {}


## Put a body on the ground. The tokens go out on the same tick.
func add(corpse: Corpse, hash: SpatialHash, pool: NpcPool) -> void:
	corpses.append(corpse)
	_issue_tokens(corpse, hash, pool)


## **NEAREST FIRST, FLEEING SKIPPED, CAPPED AT `TUN-CROWD-GAWK-MAX`.**
##
## Fleeing beats gawking (TDD-08 §3.3): an NPC in `STARTLE` is running away from
## the very thing that made the corpse, and `NpcBrain.TRANSITIONS` refuses
## `GAWK_GRANTED` from that state anyway — so granting one would burn a token on
## an NPC that silently ignores it, and the cluster would come up short with
## nothing anywhere saying why.
func _issue_tokens(corpse: Corpse, hash: SpatialHash, pool: NpcPool) -> void:
	corpse.tokens_issued = true
	var remaining: int = int(Tuning.crowd.gawk_max)
	for npc: int in _nearest_first(corpse.position, hash, pool):
		if remaining == 0:
			break
		var brain := pool.brain_of(npc)
		var cctx := pool.context_of(npc)
		if brain == null or cctx == null or brain.state == NpcBrain.State.STARTLE:
			continue
		if _watchers.has(npc):
			continue
		cctx.gawk_granted = true
		_watchers[npc] = corpse
		remaining -= 1


## Candidates within `TUN-CROWD-GAWK-RADIUS`, closest first. The hash answers
## *who is near*; the ordering is this file's, because "nearest first" is what
## makes a cluster form around the body rather than in a ring at its edge.
func _nearest_first(point: Vector3, hash: SpatialHash, pool: NpcPool) -> PackedInt32Array:
	var found := hash.query(point, Tuning.crowd.gawk_radius)
	var ranked: Array = []
	for npc: int in found:
		var body := pool.body_of(npc)
		if body != null:
			ranked.append([body.global_position.distance_to(point), npc])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out := PackedInt32Array()
	for entry: Array in ranked:
		out.append(int(entry[1]))
	return out


## Age every body and clear away the expired ones, telling their own onlookers.
## Returns how many were removed.
##
## **A GAWKER USUALLY LEAVES BEFORE THE BODY DOES**, because
## `TUN-CROWD-GAWK-DURATION` is shorter than `TUN-CORPSE-LIFETIME` — so
## `corpse_gone` is the *unusual* path, for a body removed early. It exists
## because without it an onlooker of a vanished corpse would stand staring at
## nothing until its own timer ran out.
func expire(tick: int, pool: NpcPool) -> int:
	var removed := 0
	for index: int in range(corpses.size() - 1, -1, -1):
		var corpse := corpses[index]
		if not corpse.expired(tick):
			continue
		_release(corpse, pool)
		corpses.remove_at(index)
		removed += 1
	return removed


## Tell everyone watching `corpse` that it has gone, and forget them.
func _release(corpse: Corpse, pool: NpcPool) -> void:
	for npc: int in _watchers.keys():
		if _watchers[npc] != corpse:
			continue
		var cctx := pool.context_of(npc)
		if cctx != null:
			cctx.corpse_gone = true
		_watchers.erase(npc)


## Forget an onlooker who has stopped looking — its gawk timer ran out, or a
## startle took it. Called on the director's 2 s pass, so a body that outlives its
## first cluster can never re-recruit the same NPC twice by accident.
func forget_departed(pool: NpcPool) -> void:
	for npc: int in _watchers.keys():
		var brain := pool.brain_of(npc)
		if brain == null or brain.state != NpcBrain.State.GAWK:
			_watchers.erase(npc)


## How many NPCs are currently looking at something. For tests, and for the
## `TUN-CROWD-GAWK-MAX` claim to be checkable from outside.
func watcher_count() -> int:
	return _watchers.size()


## The body `npc` was sent to look at, or null. **A gawker walks to the corpse**,
## so the director needs to know which one — and it must be *that* body, not the
## nearest: two kills ten metres apart would otherwise swap their crowds and the
## cluster would stop marking where the killing was.
func corpse_for(npc: int) -> Corpse:
	return _watchers.get(npc, null) as Corpse


func watching(npc: int) -> bool:
	return _watchers.has(npc)


## Drop everything at match end. A corpse surviving into the next match would be a
## body nobody in it had ever killed.
func clear() -> void:
	corpses.clear()
	_watchers.clear()
