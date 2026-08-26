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

## `NET-S2C-PREY-WARNING` arrived. CLIENT SIDE. **A world bearing in radians and a
## `Quantise.BUCKET_STEP` distance bucket, and nothing else.**
##
## The bearing is dequantised here so no consumer has to know the wire's step, and
## it is **world** rather than camera-relative: the client rotates it by its own
## yaw every rendered frame, because a camera-relative angle computed server-side
## would lag the mouse by the round trip on a marker whose whole job is to point.
signal prey_warned(bearing_radians: float, bucket: int)


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
