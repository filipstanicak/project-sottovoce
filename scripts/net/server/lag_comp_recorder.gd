## **WHAT GOES INTO THE RING, GATHERED ONCE A TICK.** TDD-04 §8.2, US-0035.
## SERVER ONLY.
##
## The wiring half of lag compensation. `LagCompHistory` is pure and holds the
## arithmetic; this walks the world and hands it transforms, which is the part
## that needs a `PawnHost` and, from M3, a crowd.
##
## Split for the reason the router learned in US-0026: a buffer whose contents
## arrive through a global cannot be *asked a question* in a test. The ring is
## fed plain arrays, so every assertion about rewinding is written against data a
## test chose rather than against a world it had to stand up.
##
## **NPCs ARE ABSENT AND THAT IS A GAP, NOT A DECISION.** §8.2 rewinds NPC
## positions too — they determine LOS occlusion and blend membership, and
## validating against a *current* crowd when the attacker acted against a *past*
## one reintroduces exactly the error lag compensation exists to remove. There is
## no crowd until M3. `_gather()` is where they join, and US-0035 leaves its NPC
## criterion unticked rather than claiming a pool that does not exist.
class_name LagCompRecorder
extends Node

var _ctx: MatchContext
var _pawns: PawnHost


func setup(ctx: MatchContext, pawns: PawnHost) -> void:
	_ctx = ctx
	_pawns = pawns


## Connected to `MatchDirector.tick_completed` — **the end of the tick**, the
## same signal the snapshot builder is driven by. The two must share a timeline
## or every M4 rewind is a tick further into the past than it asked for.
func record(ctx: MatchContext, _dt: float) -> void:
	if _ctx == null or _pawns == null or ctx.lag_comp == null:
		return
	var ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var yaws := PackedFloat32Array()
	_gather(ids, positions, yaws)
	ctx.lag_comp.record(ctx.tick, ids, positions, yaws)


## **KEYED BY PEER, NOT BY WIRE SLOT.** The slot is what a snapshot names a player
## by, and it is reused the moment somebody leaves — a rewind that resolved a kill
## against slot 3 could name the player who inherited it rather than the one who
## was there. Peers are what the server's own state is keyed by everywhere else.
func _gather(
	ids: PackedInt32Array, positions: PackedVector3Array, yaws: PackedFloat32Array
) -> void:
	for peer: int in _ctx.pawns.keys():
		var pawn := _pawns.context_for(peer)
		if pawn == null:
			continue
		ids.append(peer)
		positions.append(pawn.position)
		yaws.append(pawn.yaw)
