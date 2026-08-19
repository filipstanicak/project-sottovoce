## **THE CULL BOUNDARY MUST NOT CHATTER.** US-0030, US-0031, US-0045.
##
## An NPC crossing `TUN-NET-NPC-CULL-RADIUS` is created and freed on the client.
## Doing that repeatedly is not a bandwidth problem, it is a **visible** one: a
## body appearing and vanishing at 70 m is exactly the popping that culling is
## supposed to be too far away to show.
##
## Leaving is decided at the radius; re-admission one `readmit_margin()` inside it.
## This file drives both cases the crowd actually produces — an NPC parked on the
## line with the centimetre of jitter RVO gives a standing body, and one walking
## straight out through it.
##
## **BOTH CASES HERE ARE SERVER-SIDE, AND A LIVE WATCH SHOWED CHURN THAT NEITHER
## OF THEM COULD SEE.** It was not the server: `SnapshotAssembler` cached the one
## farewell record it was ever sent and re-presented it in every later snapshot,
## so `NpcView` created and freed a body **once per snapshot** from a record the
## server sent once. This file was green throughout and was right to be — the
## boundary it tests is quiet. `test_a_departing_npc_is_created_and_freed_exactly_once`
## in `test_npc_view.gd` is the half that was missing. TDD-04 §7.1.3.
extends GutTest

const MAP_DATA := "res://data/maps/map_vetraio.tres"
const ALICE := 4001

var _ctx: MatchContext
var _host: PawnHost
var _builder: SnapshotBuilder
var _pool: NpcPool


func before_each() -> void:
	_ctx = MatchContext.new()
	_ctx.map = load(MAP_DATA) as MapData
	_ctx.phase = MatchPhase.Phase.ACTIVE
	_host = PawnHost.new()
	add_child_autofree(_host)
	_host.setup(_ctx)
	_pool = NpcPool.new()
	add_child_autofree(_pool)
	_pool.preallocate(1)
	_pool.activate(1, 1, CrowdRoster.PLAYABLE, 6)
	_ctx.crowd = _pool
	_builder = SnapshotBuilder.new()
	add_child_autofree(_builder)
	_builder.setup(_ctx, _host, null)
	await get_tree().physics_frame


func test_an_npc_parked_on_the_radius_does_not_chatter() -> void:
	var here := Vector3(20.0, 0.0, 20.0)
	_ctx.slots.assign(ALICE)
	_host.spawn(ALICE)
	_host.context_for(ALICE).position = here
	var reach: float = Tuning.net.npc_cull_radius
	# **HELD FIRST.** An NPC that was never admitted is trivially quiet; the case
	# that chatters is one already being drawn that drifts onto the boundary.
	_pool.set_position(0, here + Vector3(10.0, 0.0, 0.0))
	_ctx.tick = 1
	assert_gt(_builder.build_for(ALICE).npcs.size(), 0, "the NPC was never admitted")
	_builder.note_ack(ALICE, 1)
	var sent := 0
	for tick: int in range(2, 62):
		# A centimetre of jitter either side of the radius, which is what RVO does
		# to a standing NPC.
		# Walking outward at stroll, one tick at a time, straight through the line.
		var step: float = Tuning.crowd.npc_speed_stroll / Tuning.net.snapshot_rate
		var out := reach - 0.3 + float(tick - 2) * step
		_pool.set_position(0, here + Vector3(out, 0.0, 0.0))
		_ctx.tick = tick
		if _builder.build_for(ALICE).npcs.size() > 0:
			sent += 1
		_builder.note_ack(ALICE, tick)
	gut.p("an NPC walking out through the cull radius was sent %d times in 60 ticks" % sent)
	assert_lt(sent, 12, "the cull chatters as an NPC walks out")
