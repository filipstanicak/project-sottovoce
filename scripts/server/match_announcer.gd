## **THE ONE PLACE A PEER ID BECOMES A WIRE SLOT, AND THE ONE PLACE WHO HEARS
## WHAT IS DECIDED.** US-0029, US-0064. SERVER ONLY.
##
## Split out of `server_root.gd` when that file passed 400 lines (never-do #6).
## **The seam is real rather than a line count**: standing a server up and deciding
## which peer is told about an event are two jobs, and every method here is the
## second one. What is left in `ServerRoot` is boot, wiring, and the cross-system
## consequences of a death.
##
## **PEER IDS NEVER TRAVEL.** Godot hands out 32-bit randoms and every protocol row
## declares `peer_id:u8`, so `SlotTable` maps between them — and it maps *here*,
## once, rather than at each call site. A message built somewhere else with a raw
## peer id would decode as a plausible wrong player.
##
## **THE RECIPIENT LIST IS THE RULE, NOT THE PAYLOAD.** Most of what this class
## protects is who is *not* told: a prey warning that reached the pursuer would
## tell them they had been made, and a stun refusal that reached the target would
## say *that player believes you are hunting them*. Each method carries the
## argument for its own recipients.
class_name MatchAnnouncer
extends RefCounted

var _ctx: MatchContext


func _init(ctx: MatchContext) -> void:
	_ctx = ctx


## **`NET-S2C-CONTRACT-ASSIGNED` CARRIES THE SLOT AND THE REASON AND NOTHING
## ELSE**: no persona, no position, no tier. The crowd's entire value is that a
## contract is one of about seventy-eight candidates until you earn better, and a
## field on this message is the cheapest possible way to give that away.
func contract_issued(peer: int, contract: int, reason: int) -> void:
	Net.events.send_contract(peer, _ctx.slots.slot_of(contract), reason)


## A landed kill reaches the two players in it and nobody else. There is no global
## kill feed (never-do #12) — a death is something you infer from the crowd.
func kill_landed(killer: int, victim: int) -> void:
	var a := _ctx.slots.slot_of(killer)
	var b := _ctx.slots.slot_of(victim)
	for peer: int in [killer, victim]:
		Net.events.send_kill(peer, a, b, _ctx.tick, 0)


## **A REJECTED KILL IS ANSWERED, BECAUSE SILENCE IS THE WORST ANSWER.** GDD-02 §9
## failure mode 7: *players press kill in range, nothing happens, and they blame
## the game — whatever the cause, the fix is feedback.*
##
## It rides `NET-S2C-KILL-RESULT` with a **victim slot of zero**, which US-0029
## reserves to mean nobody. No new message and no new field: "your press did not
## land" is exactly what a kill result naming no victim says, and a separate whiff
## message would be a second way to say one thing.
##
## **THE ANIMATION DOES NOT EXIST.** There are no animation clips in this project
## on either rig, so what arrives is the event and not yet the gesture.
func kill_rejected(killer: int, _verdict: int, _target: int) -> void:
	Net.events.send_kill(killer, _ctx.slots.slot_of(killer), SlotTable.NO_SLOT, _ctx.tick, 0)


## **THE PREY WARNING GOES TO THE PREY AND TO NOBODY ELSE.** US-0059, GDD-03 §9.1.
##
## The recipient list is the whole rule. Broadcasting it would tell every living
## player that somebody, somewhere, had gone careless — which is the inference the
## crowd is for. Sending it to the *pursuer* would tell them they had been made,
## and a hunter who knows they have been seen is a hunter who can simply wait.
##
## **NO SLOT IS MAPPED HERE, WHICH IS THE DIFFERENCE FROM EVERY OTHER METHOD IN
## THIS FILE.** The others translate a peer into a wire slot because they name
## somebody. This one names nobody, so there is nothing to translate — and that
## absence is the anonymity rule expressed as a missing line of code rather than
## as a comment.
func prey_warned(prey: int, bearing: float, bucket: int) -> void:
	Net.events.send_prey_warning(prey, bearing, bucket)


## **A LANDED STUN REACHES THE TWO PLAYERS IN IT AND NOBODY ELSE.** US-0061.
##
## Both are told the same `lockout_ticks`: the hunter learns the length of their
## exile and the prey learns how much time they just bought. GDD-03 §10.2 makes
## that number the difference between counterplay and a four-second delay, so a
## prey who could not see it would have no way to judge whether the stun was worth
## the risk of turning round.
func stunned(stunner: int, target: int, lockout_ticks: int) -> void:
	var a := _ctx.slots.slot_of(stunner)
	var b := _ctx.slots.slot_of(target)
	for peer: int in [stunner, target]:
		Net.events.send_stun(peer, a, b, _ctx.tick, true, lockout_ticks)


## **A REFUSAL GOES TO THE STUNNER ALONE, AND NAMES NOBODY.**
##
## Telling the *target* that somebody tried to stun them would say "that player
## believes you are hunting them", which is a free read on a stranger's suspicion
## of you. And `SlotTable.NO_SLOT` rather than the peer they swung at, so the
## answer cannot be compared across presses — every refusal looks the same, which
## is what stops the stun button being an identity probe.
func stun_rejected(stunner: int, _verdict: int, _target: int) -> void:
	Net.events.send_stun(
		stunner, _ctx.slots.slot_of(stunner), SlotTable.NO_SLOT, _ctx.tick, false, 0
	)


## **US-0054's THIRD CRITERION, ON THE WIRE.** *"Refused with distinct feedback,
## not silence"* — `NET-C2S-BLEND-REQUEST` had no answer of any kind until now, so
## a press at an occupied hay cart and a press at an empty street produced exactly
## the same nothing. **The one refusal in this game that reports its reason**: a
## prop's occupancy is level geometry with somebody in it, never a fact about a
## stranger, so it cannot be used as an identity probe.
func blend_refused(peer: int, why: int) -> void:
	Net.events.send_blend_denied(peer, why)


## `NET-S2C-ABILITY-STARTED`. **THE ONE BROADCAST IN THIS CLASS**, and the reason
## is design law 3: *no ability resolves without the victim having had a
## perceivable chance to read it*. Every other method here has a recipient list
## that exists to withhold something; this one has a list that exists to make sure
## nobody near enough is left out.
##
## The radius is the ability's own `TUN-<ABIL>-TELL-AUDIO-RADIUS`, measured to each
## living pawn. **A tell sent to the whole lobby would be a global ability feed** —
## never-do #12's shape — telling somebody two streets away that a hunt was under
## way, which is the inference the crowd is for.
func ability_started(
	ctx: MatchContext, caster: int, ability: StringName, origin: Vector3, direction: Vector3
) -> void:
	var data: AbilityData = Tuning.ability_data(ability)
	if data == null:
		return
	var radius := maxf(data.tell_audio_radius, 0.0)
	var slot := _ctx.slots.slot_of(caster)
	for peer: int in ctx.pawn_contexts.keys():
		var pawn := ctx.pawn_contexts[peer] as PawnContext
		if CombatTargets.is_dead(pawn):
			continue
		if peer != caster and pawn.position.distance_to(origin) > radius:
			continue
		Net.events.send_ability_started(peer, slot, ability, origin, direction)


## `NET-S2C-ABILITY-DENIED`. To the presser alone, **carrying its reason** — every
## one of them is a fact about the presser's own kit, cooldown, state or aim, so
## there is nothing in it to learn about a stranger. That is what separates it from
## the stun refusal, which must say nothing.
func ability_denied(peer: int, slot: int, why: int) -> void:
	Net.events.send_ability_denied(peer, slot, why)
