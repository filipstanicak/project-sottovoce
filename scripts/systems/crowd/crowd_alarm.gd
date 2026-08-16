## **THE STARTLE WAVE.** GDD-03 §6.4, TDD-08 §3.1–3.2, US-0044. SERVER ONLY.
##
## **A WAVE MUST READ AS A DIRECTION, NOT AS A RADIUS.** That sentence is the
## whole design and every decision here follows from it. A hard-edged 12 m circle
## of fleeing civilians tells a distant player only *how far* something was; a
## decaying probabilistic wave tells them *which way*, because propagation carries
## furthest along the line NPCs were already running. A player thirty metres away
## who never saw the kill can infer roughly where it happened, and that inference
## is the entire point of the mechanic.
##
## **TWO HOPS, AND THE SECOND ONE DOES NOT PROPAGATE.** Round one is everybody
## inside the radius; round two is whoever round one scares. `has_propagated`
## stops an NPC firing twice within a wave, and the round structure stops the wave
## crossing the district — a startle in a dense market that cascaded to the canal
## would say "something happened *somewhere*", which is worse than saying nothing.
##
## **STARTLE ALWAYS WINS AND IS NEVER REFUSED.** It is a global interrupt in
## `NpcBrain.TRANSITIONS`, enterable from every state. An NPC gawking at a corpse
## abandons it; a formation dissolves. Both are accepted costs of the channel
## being *reliable*: an information channel that sometimes does not fire is worse
## than none, because players stop reading it.
class_name CrowdAlarm
extends RefCounted

## How many NPCs the last wave startled, by round. `[direct, propagated]` — read
## by the tests that assert the two-hop cap, and there is no other way to see the
## shape of a wave from outside.
var last_wave: PackedInt32Array = PackedInt32Array([0, 0])


## Scare everybody within `radius` of `origin`, then let them scare their
## neighbours once. Returns how many NPCs were startled in total.
##
## **THE CALLER SUPPLIES THE RADIUS**, because the two sources are different
## events with different reach: `TUN-CROWD-STARTLE-RADIUS-VIOLENCE` 12 m for a
## kill or a stun, `TUN-CROWD-STARTLE-RADIUS-SPRINT` 5 m for somebody running
## past. A single radius would make sprinting past a market as loud as murdering
## somebody in it.
func startle_at(origin: Vector3, radius: float, hash: SpatialHash, pool: NpcPool) -> int:
	var direct := _scare(hash.query(origin, radius), origin, pool)
	var propagated := _propagate(direct, hash, pool)
	last_wave = PackedInt32Array([direct.size(), propagated])
	return direct.size() + propagated


## Round two. Every NPC round one caught gets **one** chance to scare each
## neighbour within `TUN-CROWD-STARTLE-RADIUS-SPRINT`, at
## `TUN-CROWD-STARTLE-PROPAGATION`.
##
## The probability is what makes the edge soft, and the softness is what carries
## direction: an NPC on the far side of the origin has fewer already-fleeing
## neighbours to be scared by than one on the near side, so the wave thins
## unevenly and leans the way people are running.
func _propagate(seeds: PackedInt32Array, hash: SpatialHash, pool: NpcPool) -> int:
	var reach: float = Tuning.crowd.startle_radius_sprint
	var chance: float = Tuning.crowd.startle_propagation
	var caught := 0
	for seed: int in seeds:
		var brain := pool.brain_of(seed)
		var body := pool.body_of(seed)
		if brain == null or body == null or brain.has_propagated:
			continue
		brain.has_propagated = true
		var here := body.global_position
		for other: int in hash.query(here, reach):
			var cctx := pool.context_of(other)
			if cctx == null or cctx.rng == null or other == seed:
				continue
			# **THE SEEDED GENERATOR, NEVER `randf`.** A wave that differed between a
			# match and its replay would make every recorded playtest unreadable, and
			# rule 8 forbids the global RNG outside presentation.
			if cctx.rng.randf() >= chance:
				continue
			if _scare_one(other, here, pool):
				caught += 1
	return caught


## Set the flag on everyone in `who` who is not already fleeing, and returns the
## ones that were actually newly startled.
##
## **ALREADY-FLEEING NPCs ARE NOT COUNTED AS A NEW HOP.** Re-startling one is
## legal and restarts its timer — `NpcBrain` says so deliberately — but letting it
## seed another propagation round would turn overlapping waves into a chain
## reaction with no cap at all.
func _scare(who: PackedInt32Array, origin: Vector3, pool: NpcPool) -> PackedInt32Array:
	var caught := PackedInt32Array()
	for npc: int in who:
		if _scare_one(npc, origin, pool):
			caught.append(npc)
	return caught


func _scare_one(npc: int, origin: Vector3, pool: NpcPool) -> bool:
	var cctx := pool.context_of(npc)
	var brain := pool.brain_of(npc)
	if cctx == null or brain == null:
		return false
	var fresh := brain.state != NpcBrain.State.STARTLE
	cctx.startle_flag = true
	cctx.startle_origin = origin
	return fresh


## **THE ONCE-A-SECOND SWEEP FOR SOMEBODY RUNNING PAST**, GDD-03 §6.4. Returns
## how many NPCs it startled.
##
## **"SPRINTING" IS READ FROM SPEED, NOT FROM A STATE NAME.** A pawn's state lives
## on `PawnContext`, which a `GameSystem` cannot reach — only what is on
## `MatchContext` is reachable, and pawn state lands there with `SYS-SUSPICION`
## (US-0051). Speed is enough and arguably better: the speed ladder is monotonic
## by invariant 2, so **nothing but a sprint exceeds `TUN-SPEED-RUN`**, and design
## law 1 says speed is spent anonymity however you came by it.
func sweep_for_sprinters(ctx: MatchContext, hash: SpatialHash, pool: NpcPool) -> int:
	var threshold: float = Tuning.movement.run
	var radius: float = Tuning.crowd.startle_radius_sprint
	var startled := 0
	for peer: int in ctx.pawns:
		var body := ctx.pawns[peer] as CharacterBody3D
		if body == null:
			continue
		var flat := Vector2(body.velocity.x, body.velocity.z)
		if flat.length() > threshold:
			startled += startle_at(body.global_position, radius, hash, pool)
	return startled
