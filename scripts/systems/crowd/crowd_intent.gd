## **WHAT A BRAIN STATE WANTS: A POINT AND A SPEED.** TDD-08 §8, US-0041,
## US-0045. SERVER ONLY.
##
## **THIS IS THE WHOLE BOUNDARY US-0041's FOURTH CRITERION DRAWS.** `Steering`
## takes a destination and a number and knows nothing else; somebody has to turn
## `WALKING_GROUP` into "the slot two metres ahead, at stroll", and this is that
## somebody. Keeping it in one small object rather than scattered through the
## director means the answer to "why did that NPC walk there" has exactly one
## address.
##
## Split out of `CrowdDirector` when the file passed 400 lines (never-do #6). The
## director owns the tick; this owns the intent.
class_name CrowdIntent
extends RefCounted

var _pool: NpcPool = null
var _map: MapData = null
var _rng: RandomNumberGenerator = null
var _formations: CrowdFormations = null
var _corpses: CorpseRegister = null
var _clones: CloneBalance = null
var _stroll: float = 1.4
var _flee: float = 5.0


func setup(
	pool: NpcPool,
	map: MapData,
	rng: RandomNumberGenerator,
	formations: CrowdFormations,
	corpses: CorpseRegister,
	clones: CloneBalance
) -> void:
	_pool = pool
	_map = map
	_rng = rng
	_formations = formations
	_corpses = corpses
	_clones = clones
	refresh()


## Cached speeds, refreshed with `Steering`'s for the same reason: ninety agents
## looking two values up through an autoload every tick is ADR-0005's threshold.
func refresh() -> void:
	_stroll = Tuning.crowd.npc_speed_stroll
	_flee = Tuning.crowd.npc_speed_flee


## Does this state need a navigation target? Everything except `IDLE`, which
## stands still by definition.
##
## `WALKING_GROUP` does, and for a reason that is not pathing: **an agent that has
## arrived stops avoiding**, answering `velocity_computed` with exactly zero
## however it was driven. Its target is therefore a point one rebalance interval
## *ahead* on the circuit rather than its slot — see `CrowdFormations.lookahead_for`
## — which keeps the agent unfinished while costing the repath budget about a
## third of a query per tick instead of sixteen.
func travels(state: int) -> bool:
	return state != NpcBrain.State.IDLE


## Metres per second for a state. **Stroll is `TUN-CROWD-NPC-SPEED-STROLL`, which
## invariant 1 forces to equal `TUN-SPEED-BLENDWALK`** — a crowd moving at any
## other speed is a crowd a blend-walking player cannot hide in.
func speed_for(state: int) -> float:
	match state:
		NpcBrain.State.STROLL, NpcBrain.State.WALKING_GROUP, NpcBrain.State.GAWK:
			return _stroll
		NpcBrain.State.STARTLE:
			return _flee
		_:
			return 0.0


## Where a state wants to be.
##
## Stroll picks an idle anchor from the seeded generator — anchors rather than
## open ground, because GDD-05 puts them where a city would actually gather, and
## a crowd walking between benches reads as a district while a crowd walking
## between random points reads as a screensaver.
func goal_for(index: int, state: int) -> Vector3:
	match state:
		NpcBrain.State.STROLL:
			return _an_anchor(index)
		NpcBrain.State.STARTLE:
			return _away_from(index)
		NpcBrain.State.WALKING_GROUP:
			return _formations.lookahead_for(index, _lookahead())
		NpcBrain.State.GAWK:
			return _toward_the_body(index)
		_:
			return CrowdDirector.NO_GOAL


## How far ahead of its slot a group member aims: what the formation covers
## between two rebalances, so the agent finishes roughly once per
## `TUN-CROWD-DIRECTOR-INTERVAL` and asks for one more.
func _lookahead() -> float:
	return _stroll * Tuning.crowd.director_interval


## **A GAWKER WALKS TO THE BODY.** Without this the cluster never forms: six NPCs
## granted a token would stand exactly where they were, and the "cluster of six
## staring at a point" a distant player is supposed to read at 25 m would be six
## people standing where they already stood.
##
## It is also what makes `TUN-CROWD-GAWK-MAX` mean anything. The cap exists so a
## corpse cannot depopulate a blend pocket — and a gawker that never left the
## pocket could not depopulate it however many tokens went out.
func _toward_the_body(index: int) -> Vector3:
	var corpse := _corpses.corpse_for(index)
	return CrowdDirector.NO_GOAL if corpse == null else corpse.position


## **THE ONE PLACE US-0047 TOUCHES BEHAVIOUR AT ALL.** A strolling clone picks
## its next anchor at random; `CloneBalance` may have picked one for it, and the
## difference between those two sentences is the whole of layer 4. Nothing else
## about the NPC changes — not its speed, not its state, not how it walks — which
## is why re-routing cannot read as clones following anybody.
func _an_anchor(index: int) -> Vector3:
	if _clones != null:
		var directed := _clones.take(index)
		if directed != CrowdDirector.NO_GOAL:
			return directed
	if _map == null or _map.idle_anchors.is_empty():
		return CrowdDirector.NO_GOAL
	var pick: int = (
		_rng.randi_range(0, _map.idle_anchors.size() - 1)
		if _rng != null
		else _map.idle_anchors.size() / 2
	)
	return _map.idle_anchors[pick]


## Directly away from whatever caused the scare, as far as the flee lasts.
##
## **AWAY FROM, NOT TOWARDS SAFETY.** A startle wave is read by distant players
## as a *direction*, and NPCs that all converged on the nearest safe corner would
## point at the corner instead of at the violence — the wave would still exist
## and would say the wrong thing, which is worse than saying nothing.
func _away_from(index: int) -> Vector3:
	var cctx := _pool.context_of(index)
	var here := _pool.body_of(index).global_position
	var away := here - cctx.startle_origin
	away.y = 0.0
	if away.length_squared() < 0.000001:
		away = Vector3.FORWARD
	var reach: float = _flee * Tuning.crowd.startle_duration
	return here + away.normalized() * reach
