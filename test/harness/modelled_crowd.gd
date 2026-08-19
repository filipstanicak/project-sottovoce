## **A REAL CROWD WITH MODELLED NAVIGATION.** Test support for US-0031 and US-0048.
##
## Real `NpcBrain`s decide who strolls and who stands; only the path between two
## anchors is modelled, as a straight line at `TUN-CROWD-NPC-SPEED-STROLL`. That
## split is the point: **the idle/walk mix is what every bandwidth number turns
## on**, because a strolling NPC covers 4.7 cm per tick against a 1 cm position
## quantum and therefore changes its record every single tick. How gracefully it
## steers changes nothing about that.
##
## **A STRAIGHT LINE CANNOT FLATTER A BANDWIDTH FINDING.** It is shorter than the
## path a navmesh would produce, so a modelled NPC arrives sooner and stands still
## longer than a real one. Every figure measured through this is a lower bound.
##
## **EXTRACTED WHEN THE SECOND FILE NEEDED IT**, not before. `test_crowd_bandwidth.gd`
## had it inline; `test_crowd_wire_cost.gd` then had to measure the NPC delta, and a
## delta measured against a **motionless** crowd reports that everything is free —
## which is the exact shape of vacuous success this project has shipped six times.
## Copying forty lines to get it would have left two walk models to keep in step.
class_name ModelledCrowd
extends RefCounted

var _pool: NpcPool
var _map: MapData
var _rng: RandomNumberGenerator
var _goals: PackedVector3Array
var _count: int = 0


func setup(pool: NpcPool, map: MapData, rng: RandomNumberGenerator, count: int) -> void:
	_pool = pool
	_map = map
	_rng = rng
	_count = count
	_goals = PackedVector3Array()
	_goals.resize(count)
	for index: int in count:
		_pool.set_position(index, _map.idle_anchors[index % _map.idle_anchors.size()])
		_pool.context_of(index).rng = _rng
		_goals[index] = CrowdDirector.NO_GOAL


## One net tick of the whole crowd.
func step() -> void:
	var dt := MatchContext.net_dt()
	var stride: float = Tuning.crowd.npc_speed_stroll * dt
	var arrive: float = Tuning.crowd.anchor_arrive_radius
	for index: int in _count:
		var brain := _pool.brain_of(index)
		var cctx := _pool.context_of(index)
		brain.step(cctx, dt)
		cctx.clear_events()
		if brain.state != NpcBrain.State.STROLL:
			continue
		if _goals[index] == CrowdDirector.NO_GOAL:
			_goals[index] = _next_anchor(index)
		_walk(index, brain, cctx, stride, arrive)


## Run far enough that the idle/walk mix is the crowd's steady state rather than
## its opening arrangement. `TUN-CROWD-IDLE-DURATION-MAX` is 25 s, so a few
## hundred ticks is more than a full cycle.
func settle(ticks: int) -> void:
	for _i: int in ticks:
		step()


## How many of the crowd are walking right now — the number every downstream
## figure turns on, exposed so a test can assert the scenario is not frozen.
func walking() -> int:
	var moving := 0
	for index: int in _count:
		if _pool.brain_of(index).state == NpcBrain.State.STROLL:
			moving += 1
	return moving


## Move one strolling body a tick along its line, and tell the brain when it
## arrives — otherwise nobody ever stands still and the idle fraction is a
## constant zero, which would make the crowd look maximally expensive.
func _walk(index: int, brain: NpcBrain, cctx: CrowdContext, stride: float, arrive: float) -> void:
	var body := _pool.body_of(index)
	var to := _goals[index] - body.global_position
	to.y = 0.0
	if to.length() <= arrive:
		brain.handle(NpcBrain.Event.REACHED_ANCHOR, cctx)
		cctx.clear_events()
		_goals[index] = CrowdDirector.NO_GOAL
		return
	body.global_position += to.normalized() * stride


func _next_anchor(index: int) -> Vector3:
	var anchors := _map.idle_anchors
	return anchors[(index * 7 + int(_rng.randi_range(0, anchors.size() - 1))) % anchors.size()]
