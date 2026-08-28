## **THE `EVENT`-CHANNEL SERVER-TO-CLIENT MESSAGES, ON THEIR OWN NODE.**
## `NETWORK_PROTOCOL.md` §3, TDD-04, US-0050. A child of the `Net` autoload.
##
## **A CHILD OF AN AUTOLOAD IS AT THE SAME PATH ON EVERY PEER**, which is what lets
## an RPC surface live outside `net.gd` at all — `PingClock` was the first to use
## it and `net.gd` predicted this one: *"the C2S doorway below could move the same
## way if this file grows again."* It grew. It was **392 of its 400 lines** with
## seven more M4 event messages still to come — kill result, stun result, ability
## started and denied, prey warning, score event, phase changed — so the split
## happens at the first of them rather than the fifth.
##
## **EVERY MESSAGE HERE IS RELIABLE AND SENT ON CHANGE.** That is what separates
## this channel from `STATE`: a snapshot that is lost is replaced by a fresher one
## 33 ms later, where a lost contract is a player with nothing to do until the next
## death — which may be a minute away.
class_name EventWire
extends Node

## `NET-S2C-CONTRACT-ASSIGNED` arrived. CLIENT SIDE. **A wire slot and a reason** —
## the client resolves the slot itself and learns nothing else about who it is
## hunting until a Compass lock earns it.
signal contract_assigned(contract_slot: int, reason: int)

## `NET-S2C-KILL-RESULT` arrived. CLIENT SIDE.
##
## `bonus_group` ties this death to the `SCORE-EVENT`s it produced, so a score
## feed can group them under one heading. **It is zero until US-0064** — nothing
## appends a `ScoreEvent` yet, and a fabricated group id would be a number the
## feed later disagreed with.
signal kill_resolved(killer_slot: int, victim_slot: int, tick: int, bonus_group: int)

## `NET-S2C-STUN-RESULT` arrived. CLIENT SIDE. `lockout_ticks` is how long the
## stunned hunter is exiled from that target — **both parties are told the same
## number**, because a punishment only one side can see is one neither can plan
## around.
signal stun_resolved(stunner_slot: int, target_slot: int, valid: bool, lockout_ticks: int)

## `NET-S2C-BLEND-DENIED` arrived. CLIENT SIDE. `why` is a `BlendRefusal.Why`.
##
## **THE ONE REFUSAL IN THIS GAME THAT REPORTS ITS REASON.** A rejected kill and a
## rejected stun must be indistinguishable from each other or they become identity
## probes; a rejected blend has no such problem, because a prop's occupancy is a
## property of the level rather than of a stranger.
signal blend_denied(why: int)

## `NET-S2C-PREY-WARNING` arrived. CLIENT SIDE. **A world bearing in radians and a
## `Quantise.BUCKET_STEP` distance bucket, and nothing else.**
##
## The bearing is dequantised here so no consumer has to know the wire's step, and
## it is **world** rather than camera-relative: the client rotates it by its own
## yaw every rendered frame, because a camera-relative angle computed server-side
## would lag the mouse by the round trip on a marker whose whole job is to point.
signal prey_warned(bearing_radians: float, bucket: int)

## `NET-S2C-ABILITY-STARTED`. The tell, on the wire.
signal ability_started(caster_slot: int, ability: StringName, origin: Vector3, direction: Vector3)

## `NET-S2C-ABILITY-DENIED`. To the presser alone.
signal ability_denied(slot: int, why: int)

## `NET-S2C-SCORE-EVENT` arrived. CLIENT SIDE. **One award, already decoded into a
## `ScoreReport`** — the wire's `kind` byte, base and multiplier are resolved here
## so no consumer has to know the protocol, which is the rule `HudBridge` follows
## for the Compass's yaw byte.
signal score_reported(report: ScoreReport)


## `NET-S2C-CONTRACT-ASSIGNED`. SERVER SIDE, **to the holder only**.
##
## `contract_slot` is a wire slot, never a peer id — peer ids never travel
## (US-0029), and the mapping happens at the one call site in `server_root`.
func send_contract(peer: int, contract_slot: int, reason: int) -> void:
	if not Net.is_server:
		return
	s2c_contract_assigned.rpc_id(peer, contract_slot, reason)


## `NET-S2C-CONTRACT-ASSIGNED`. CLIENT SIDE.
##
## **IT CARRIES A SLOT AND A REASON AND THERE IS NOWHERE TO PUT ANYTHING ELSE.**
## GDD-03 §6 makes the crowd's whole value the fact that a contract is one of about
## seventy-eight candidates until a Compass lock earns better; a persona field here
## would collapse that to twelve, silently, in every match.
@rpc("authority", "call_remote", "reliable", Messages.Channel.EVENT)
func s2c_contract_assigned(contract_slot: int, reason: int) -> void:
	contract_assigned.emit(contract_slot, reason)


## `NET-S2C-KILL-RESULT`. SERVER SIDE, **to the killer and the victim only**.
##
## **THIS IS THE MESSAGE THAT IS NOT A KILL FEED**, and the recipient list is the
## whole of never-do #12 in one line. Broadcasting it would tell every living
## player how the contract cycle had just shifted — for free, instantly, and to
## people who were nowhere near it. Working out that somebody died, from a crowd
## startling two streets away, is the inference the design is made of.
func send_kill(peer: int, killer_slot: int, victim_slot: int, tick: int, group: int) -> void:
	if not Net.is_server:
		return
	s2c_kill_result.rpc_id(peer, killer_slot, victim_slot, tick, group)


@rpc("authority", "call_remote", "reliable", Messages.Channel.EVENT)
func s2c_kill_result(killer_slot: int, victim_slot: int, tick: int, bonus_group: int) -> void:
	kill_resolved.emit(killer_slot, victim_slot, tick, bonus_group)


## `NET-S2C-STUN-RESULT`. SERVER SIDE, **to the stunner and the target only**.
##
## Never broadcast, for `send_kill`'s reason: a global stun feed would tell every
## living player that a hunt had just been broken somewhere, for free.
func send_stun(
	peer: int, stunner_slot: int, target_slot: int, tick: int, valid: bool, lockout: int
) -> void:
	if not Net.is_server:
		return
	s2c_stun_result.rpc_id(peer, stunner_slot, target_slot, tick, valid, lockout)


## `NET-S2C-STUN-RESULT`. CLIENT SIDE.
##
## **A REFUSAL CARRIES NO TARGET AT ALL.** `server_root` sends `SlotTable.NO_SLOT`
## on every rejection, so a prey cannot press stun at a stranger and read the
## answer to learn whether that stranger is hunting them. `valid` is the only
## thing a failed press reports, and every refusal costs the same
## `TUN-STUN-INVALID-STAGGER` — the indistinguishability is the rule, and
## `StunVerdict` carries the argument for it.
@rpc("authority", "call_remote", "reliable", Messages.Channel.EVENT)
func s2c_stun_result(
	stunner_slot: int, target_slot: int, _tick: int, valid: bool, lockout_ticks: int
) -> void:
	stun_resolved.emit(stunner_slot, target_slot, valid, lockout_ticks)


## `NET-S2C-BLEND-DENIED`. SERVER SIDE, **to the requester alone**.
##
## Broadcasting it would announce that somebody just tried to hide, and where —
## which is the inference a hunter is supposed to have to earn.
func send_blend_denied(peer: int, why: int) -> void:
	if not Net.is_server:
		return
	s2c_blend_denied.rpc_id(peer, why)


## `NET-S2C-BLEND-DENIED`. CLIENT SIDE.
@rpc("authority", "call_remote", "reliable", Messages.Channel.EVENT)
func s2c_blend_denied(why: int) -> void:
	blend_denied.emit(why)


## `NET-S2C-PREY-WARNING`. SERVER SIDE, **to the prey alone**.
##
## **THE QUANTISATION IS THE WIRE'S JOB AND HAPPENS HERE**, at `Quantise.YAW_STEP`
## — the same step the hunter's own Compass bearing rides in every snapshot. The
## prey must not be given a *finer* bearing than the hunter is: one ring, one
## precision, or a player would learn that the instrument means two different
## things depending on which way it points.
func send_prey_warning(peer: int, bearing_radians: float, bucket: int) -> void:
	if not Net.is_server:
		return
	s2c_prey_warning.rpc_id(peer, Quantise.yaw_to_u8(bearing_radians), bucket)


## `NET-S2C-PREY-WARNING`. CLIENT SIDE.
##
## **TWO FIELDS, AND NEITHER OF THEM NAMES ANYBODY.** GDD-03 §9.1: the warning says
## *where*, never *who*. A persona, a wire slot or a colour here would collapse the
## crowd from seventy-eight candidates to one, permanently and for free, and
## `ASM-0030`'s Compass lock — the only thing in the game that earns an identity —
## would have nothing left to earn. `test_warning_names_nobody.gd` refuses it.
@rpc("authority", "call_remote", "reliable", Messages.Channel.EVENT)
func s2c_prey_warning(bearing_byte: int, bucket: int) -> void:
	prey_warned.emit(Quantise.u8_to_yaw(bearing_byte), bucket)


## `NET-S2C-ABILITY-STARTED`. SERVER SIDE, **to everybody who could perceive it**.
##
## **THIS IS DESIGN LAW 3 ON THE WIRE, AND IT IS THE ONE BROADCAST IN THIS FILE.**
## Every other message here has a recipient list that is the rule — a kill result
## goes to two people because a global kill feed would convert an inference into a
## fact. A tell is the opposite: *no ability resolves without the victim having had
## a perceivable chance to read it*, so the failure mode is somebody **not** being
## told. The radius is the ability's own `TUN-<ABIL>-TELL-AUDIO-RADIUS`.
##
## **RELIABLE, AND THAT IS NOT THE DEFAULT CHOICE FOR A COSMETIC.** A dropped
## snapshot costs one frame of smoothness; a dropped tell costs the victim their
## only warning, and TDD-09's own note says tell latency is a netcode issue rather
## than a balance one — *if Lunge proves unstunnable in practice, check delivery
## time before touching tunables.*
func send_ability_started(
	peer: int, caster_slot: int, ability: StringName, origin: Vector3, direction: Vector3
) -> void:
	if not Net.is_server:
		return
	s2c_ability_started.rpc_id(peer, caster_slot, ability, origin, direction)


@rpc("authority", "call_remote", "reliable", Messages.Channel.EVENT)
func s2c_ability_started(
	caster_slot: int, ability: StringName, origin: Vector3, direction: Vector3
) -> void:
	ability_started.emit(caster_slot, ability, origin, direction)


## `NET-S2C-ABILITY-DENIED`. SERVER SIDE, **to the presser alone**.
##
## **IT CARRIES ITS REASON, UNLIKE THE STUN REFUSAL**, and the difference is who
## the reason is about. A stun refusal that named its reason would be a free
## identity probe; every reason here is a fact about the presser's own kit, their
## own cooldown, their own state. There is nothing in it to learn about anybody
## else, which is what makes it safe to be helpful.
func send_ability_denied(peer: int, slot: int, why: int) -> void:
	if not Net.is_server:
		return
	s2c_ability_denied.rpc_id(peer, slot, why)


@rpc("authority", "call_remote", "reliable", Messages.Channel.EVENT)
func s2c_ability_denied(slot: int, why: int) -> void:
	ability_denied.emit(slot, why)


## `NET-S2C-SCORE-EVENT`. SERVER SIDE, **to the player who earned it and to nobody
## else**.
##
## **THE RECIPIENT IS A FIELD OF THE EVENT, WHICH IS WHAT MAKES "NO GLOBAL KILL
## FEED" STRUCTURAL RATHER THAN REMEMBERED.** Every other message in this file
## takes a recipient list its caller assembled; this one takes `ScoreEvent.actor_id`,
## so there is no list to widen by accident. Never-do #12 forbids a global feed
## because "X killed Y" broadcast to everyone hands every player the shape of the
## contract cycle for free.
##
## **THE PAYLOAD IS `NETWORK_PROTOCOL.md` §4's ROW UNCHANGED, AND PACKED.**
## `ScoreWire` owns the layout and says why it is bytes rather than arguments.
func send_score(peer: int, event: ScoreEvent, actor_slot: int, subject_slot: int) -> void:
	if not Net.is_server:
		return
	s2c_score_event.rpc_id(peer, ScoreWire.pack(event, actor_slot, subject_slot))


## `NET-S2C-SCORE-EVENT`. CLIENT SIDE.
##
## **RELIABLE, AND THE CHANNEL TABLE SAYS WHY IN ONE SENTENCE**: *a lost
## `SCORE-EVENT` is a score that never existed.* There is no later snapshot
## carrying it and no total to reconcile against — the log is the only record, so
## a dropped packet is a bonus the player earned and was never told about.
##
## **A MALFORMED ROW IS DROPPED IN SILENCE.** The alternative is emitting a report
## the server never sent, and the score feed is the game's teacher: a line it
## invents teaches something false.
@rpc("authority", "call_remote", "reliable", Messages.Channel.EVENT)
func s2c_score_event(row: PackedByteArray) -> void:
	var report := ScoreWire.unpack(row)
	if report == null:
		Log.error("malformed score row: %d bytes" % row.size(), &"net")
		return
	score_reported.emit(report)
