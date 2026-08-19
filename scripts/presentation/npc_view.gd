## **THE CROWD, AS THE SERVER LAST DESCRIBED IT.** TDD-08 §9, TDD-04 §7.2.
## CLIENT ONLY.
##
## Until this existed the district was empty on every client: NPC records had
## reached the wire since US-0030 and **nothing instantiated a body for them**.
## Four unticked criteria across US-0044, US-0045 and US-0047 name "a rendered
## clone" as their blocker; this is the thing they were waiting for.
##
## **ABSENCE MEANS "NO UPDATE", NOT "GONE" — THE OPPOSITE OF `RemotePawns`.** That
## class frees a slot the snapshot stopped mentioning, and is right to: every pawn
## is offered every tick, so silence is departure. An NPC is culled by distance
## (US-0030), sent at a tenth of the rate beyond `TUN-NET-NPC-RATE-LOD-RADIUS`
## (US-0031) and omitted entirely while its record is unchanged. **Freeing on
## absence here would delete most of the crowd on most ticks**, and freeing on a
## timeout would delete exactly the NPCs standing still at an anchor, which is the
## crowd's most common state.
##
## **SO IT CULLS BY DISTANCE, THE SAME RULE THE SERVER USED**, from the last
## position it was told — and **deliberately a little later than the server**. The
## margin is `TUN-NET-INTERP-BUFFER` x `TUN-SPEED-SPRINT`: this view draws the
## world one buffer in the past, so the client's own pawn and the crowd it is
## measuring against are offset by at most a sprint over that window. **Erring the
## other way would drop an NPC the server still believes is held**, and a standing
## one would then never be mentioned again.
##
## The server closes the other half: a cull invalidates that NPC's delta baseline,
## so one that leaves and returns is re-sent in full. Without that, this class
## could not safely free anything at all.
##
## **EVERY NPC WEARS A GREYBOX BODY, AND THAT IS NOT A PLACEHOLDER DECISION TO
## MAKE LIGHTLY.** `CrowdRoster` derives identity from `match_seed`, and a client
## is never told the seed — `NET-S2C-MATCH-START` carries it and `SYS-MATCH` is
## M4's. **Guessing a persona would be worse than showing none**: clone identity
## is the mechanic the whole game rests on, and a body wearing the wrong one is an
## anonymity leak that looks exactly like correct behaviour.
class_name NpcView
extends Node3D

## An NPC index was first drawn, or dropped for leaving the client's reach. Past
## tense: the node already exists, or is already gone.
signal npc_appeared(index: int)
signal npc_dropped(index: int)

var _bodies: Dictionary = {}
var _interpolator := SnapshotInterpolator.new()
var _clock := RenderClock.new()
var _last_seen: Dictionary = {}
var _observer := Vector3.ZERO


func _ready() -> void:
	Net.snapshot_received.connect(apply_snapshot)


## Where the local player is, for the client-side cull. Fed from the own-pawn
## block of the snapshot rather than from the predicted pawn, so the distance this
## class measures is the one the server measured against.
func set_observer(at: Vector3) -> void:
	_observer = at


## Record what the snapshot said. **Nothing moves here** — moving is the clock's
## job, and doing it on arrival would make the crowd advance at whatever rate the
## wire happened to deliver.
func apply_snapshot(snapshot: Snapshot) -> void:
	if snapshot == null:
		return
	var server_time := float(snapshot.server_tick) / Tuning.net.server_tick
	_clock.observe(server_time)
	set_observer(snapshot.own_position)
	for record: Array in snapshot.npcs:
		var index: int = record[0]
		if not _bodies.has(index):
			_spawn(index)
		_last_seen[index] = record[1] as Vector3
		_interpolator.push(index, server_time, record[1] as Vector3, record[2] as float)
	_drop_what_left()


## Draw every NPC where it was `TUN-NET-INTERP-BUFFER` ago.
##
## **`_physics_process`, NOT `_process`**, for the reason `RemotePawns` gives:
## interpolating on rendered frames puts a moving transform on a clock the
## player's hardware chooses, and the fixed clock is already twice the snapshot
## rate. Mixed 30 Hz and 10 Hz streams both work because the interpolator is
## **timestamp-based**; a fixed-interval one would make the two rates fight.
func _physics_process(delta: float) -> void:
	_clock.advance(delta)
	if not _clock.started():
		return
	var at := _clock.render_time()
	for index: int in _bodies:
		var placed: Array = _interpolator.sample(index, at)
		if placed.is_empty():
			continue
		var body := _bodies[index] as Node3D
		body.global_position = placed[0] as Vector3
		body.rotation.y = placed[1] as float


## The client's own cull, one margin wider than the server's.
func _drop_what_left() -> void:
	var reach: float = Tuning.net.npc_cull_radius + drop_margin()
	var beyond := reach * reach
	for index: int in _bodies.keys():
		var at: Vector3 = _last_seen.get(index, _observer)
		var dx := at.x - _observer.x
		var dz := at.z - _observer.z
		if dx * dx + dz * dz <= beyond:
			continue
		(_bodies[index] as Node).queue_free()
		_bodies.erase(index)
		_last_seen.erase(index)
		_interpolator.forget(index)
		npc_dropped.emit(index)


## **DERIVED FROM TWO EXISTING TUNABLES, NEVER CHOSEN.** This view is one
## `TUN-NET-INTERP-BUFFER` behind the world, so the furthest the observer and a
## drawn NPC can have drifted apart in that window is one `TUN-SPEED-SPRINT`.
## Public because the assertion that matters is that it is **positive** — a client
## culling at or inside the server's radius drops NPCs the server still believes
## it holds.
func drop_margin() -> float:
	return Tuning.net.interp_buffer / 1000.0 * Tuning.movement.sprint


func _spawn(index: int) -> void:
	var body := GreyboxBody.new()
	body.name = "Npc_%d" % index
	add_child(body)
	_bodies[index] = body
	npc_appeared.emit(index)


func count() -> int:
	return _bodies.size()


func has_npc(index: int) -> bool:
	return _bodies.has(index)
