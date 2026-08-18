## **WHICH BAND EVERY NPC IS IN, AND WHAT THAT BUYS.** TDD-08 §4.1 and §12 Q2,
## ADR-0003, US-0045, US-0041. SERVER ONLY.
##
## `CrowdLod` decides a band from a point and a list of players and knows nothing
## else; this holds the *bookkeeping* — where the players are this tick, what band
## each NPC was in last tick, and the one side effect a band change has.
##
## Split out of `CrowdDirector` when the file passed 400 lines (never-do #6), the
## same way `CrowdIntent` and `CrowdFormations` were. The director owns the tick;
## this owns the distance.
##
## **RUN EVERY TICK, DELIBERATELY.** Banding on the 2 s pass instead would be
## cheaper and would mean a player walking into a plaza waits up to two seconds
## for the crowd around them to start thinking at full rate — which is a crowd
## that behaves differently *because you just arrived*, and therefore a tell.
class_name CrowdBands
extends RefCounted

## Where the players are, refilled each tick. A member rather than a local
## because a fresh `PackedVector3Array` every tick is six players' worth of
## garbage a second, and because `CloneBalance` reads the same list.
var watchers: PackedVector3Array = PackedVector3Array()

var _pool: NpcPool = null
var _steering: Steering = null

## Each active NPC's band this tick, parallel to the pool.
var _bands: PackedByteArray = PackedByteArray()


## **CALLED AFTER THE AGENTS ARE CONFIGURED, NOT BEFORE.** `Steering` captures the
## engine's own `path_max_distance` in `configure()`, so a seeding pass that ran
## first would multiply a base of **zero** and hand every agent a tolerance of
## 0 m — which is not a subtle failure but is a silent one, since an agent that
## repaths every frame still walks.
##
## **AND THE SEED IS WRITTEN THROUGH, NOT JUST RECORDED.** The first version set
## `_bands` to Far and left the agents alone, reasoning that the first evaluation
## would be a change for everybody. It is not: an NPC that is *genuinely* Far
## compares equal and is skipped, so the whole Far band kept the Near tolerance
## and the one band this criterion exists for was the one that never got it.
## Measured as Near 5.0, Mid 15.0, **Far 5.0** — trap 3's family, in the
## bookkeeping written to avoid it.
func setup(pool: NpcPool, steering: Steering) -> void:
	_pool = pool
	_steering = steering
	_bands.resize(pool.body_count())
	for index: int in _bands.size():
		_bands[index] = CrowdLod.Band.FAR
		_retune_path_validity(index, CrowdLod.Band.FAR)


## §4.1's band evaluation: ninety squared-distance compares against the players.
func evaluate(pawns: Dictionary) -> void:
	watchers = CrowdLod.player_points(pawns, watchers)
	for index: int in _pool.active_count():
		var body := _pool.body_of(index)
		if body == null:
			continue
		var band := CrowdLod.band_of(body.global_position, watchers)
		if band != _bands[index]:
			_retune_path_validity(index, band)
		_bands[index] = band


## The band `index` is in right now. Far for anything out of range, because an
## NPC nobody has banded is an NPC nobody is near.
func band_of(index: int) -> int:
	return _bands[index] if index >= 0 and index < _bands.size() else CrowdLod.Band.FAR


## **US-0041's LAST LINE: A FAR AGENT RECOMPUTES ITS ROUTE LESS OFTEN.** TDD-08
## §12 Q2's own mitigation, unblocked when US-0045 built the bands.
##
## **THE STRIDE IS THE MULTIPLIER, AND THAT IS ONE NUMBER RATHER THAN A NEW ONE.**
## How often we bother thinking about an agent and how far we let it wander off
## its path are the same question asked twice, so an agent stepped every fifteenth
## tick tolerates fifteen times the drift. Nothing is invented: the multiplier is
## `CrowdLod.STRIDE`, already documented and already tested.
##
## **NEAR IS UNCHANGED, DELIBERATELY.** Multiple 1 restores the engine's own
## default, so the agents a player can actually watch behave exactly as they did —
## and an agent walking *into* the Near band is tightened again on the tick it
## arrives, which is the half that stops a loose Far tolerance outliving the
## distance that justified it.
func _retune_path_validity(index: int, band: CrowdLod.Band) -> void:
	var agent := _pool.agent_of(index)
	if agent != null:
		_steering.tolerate_drift(agent, CrowdLod.stride_of(band))
