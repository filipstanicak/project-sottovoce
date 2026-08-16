## **HOW OFTEN AN NPC THINKS, BY HOW CLOSE ANYBODY IS TO IT.** TDD-08 §4.1,
## ADR-0003, US-0045. SERVER ONLY, and PURE — points in, a band out.
##
## **LOD CHANGES THE RATE, NEVER THE LOGIC.** An NPC at 60 m runs the *same* state
## machine, less often. A crowd whose behaviour changed with observer distance
## would be a crowd that lies, and the crowd is an information channel — a player
## who learned that distant civilians behave differently would have learned a way
## to tell distance without looking.
##
## **AND "LESS OFTEN" MUST NOT MEAN "SLOWER".** A brain stepped every fifteenth
## tick decrements its timer every fifteenth tick, so an idle pause of 8–25 s
## becomes 120–375 s unless the step is told how many ticks it stands for. That is
## not a rate change; it is a *behaviour* change with a rate change's name on it,
## and it is what `NpcBrain.step()`'s `stride` argument exists to prevent.
##
## **WHAT THIS BUYS, MEASURED RATHER THAN ASSUMED.** §4.1 claims a 2.6× reduction
## and calls it "the difference between fitting the budget and not". US-0048
## measured the budget first: the brains are **0.046 ms of a 5.7 ms crowd**, so
## this saves under 1 %. It is built because ADR-0003 requires it, because the
## bands are what US-0041's far-band path validity needs, and because other
## systems will want to know how far away a player is — **not** because it is what
## makes the crowd affordable. TDD-08 §11.2.1 records what actually does.
class_name CrowdLod
extends RefCounted

enum Band { NEAR, MID, FAR }

## Ticks between brain steps, per band. §4.1's table: 30 Hz, 10 Hz, 2 Hz.
const STRIDE: Array[int] = [1, 3, 15]


## Which band `point` is in, from the nearest player. **Squared distances**: the
## comparison is against ninety NPCs every tick, and a square root per NPC buys
## nothing an ordering does not already give.
##
## **NO PLAYERS MEANS FAR, NOT NEAR.** An empty server has nobody to be fooled by
## a slow crowd, and the alternative — treating "no observers" as maximum
## fidelity — would make the emptiest server the most expensive one.
static func band_of(point: Vector3, players: PackedVector3Array) -> Band:
	var nearest := INF
	for player: Vector3 in players:
		var dx := point.x - player.x
		var dz := point.z - player.z
		nearest = minf(nearest, dx * dx + dz * dz)
	var near: float = Tuning.perf.crowd_lod_near
	var mid: float = Tuning.perf.crowd_lod_mid
	if nearest <= near * near:
		return Band.NEAR
	if nearest <= mid * mid:
		return Band.MID
	return Band.FAR


static func stride_of(band: Band) -> int:
	return STRIDE[band]


## Is `index` due to think on `tick`?
##
## **STAGGERED BY INDEX, OR A THIRD OF THE CROWD THINKS ON THE SAME TICK.** With
## `tick % stride` alone, every Mid NPC steps together every third tick and every
## Far one every fifteenth: the saving would be real and the *spike* would be
## worse than the flat cost it replaced. Offsetting by the NPC's own index spreads
## each band evenly across its own period.
static func due(band: Band, tick: int, index: int) -> bool:
	var stride := STRIDE[band]
	return stride <= 1 or (tick + index) % stride == 0


## Where every player is, flattened for `band_of`. Horizontal, like every other
## radius in the design: a player on the 3.5 m balcony is not further from the
## crowd below in any sense a band should care about.
static func player_points(pawns: Dictionary, into: PackedVector3Array) -> PackedVector3Array:
	into.resize(pawns.size())
	var at := 0
	for peer: int in pawns:
		var body := pawns[peer] as Node3D
		if body != null:
			into[at] = body.global_position
			at += 1
	if at != into.size():
		into.resize(at)
	return into
