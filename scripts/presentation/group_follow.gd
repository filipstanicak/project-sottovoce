## **THE CLIENT WALKS THE PLAYER ALONG WITH THEIR GROUP.** US-0107. CLIENT ONLY.
##
## While the server says the player is blended in a walking group and the player
## is not moving or acting themselves, every sampled command is rewritten to walk
## them to their slot (`GroupFollowSteer`) and marked `FOLLOW`. **Touching the
## stick hands control straight back**: the player walks where they like, and
## walking out of the slot's tolerance ends the blend on the server, which is the
## reference's way out of a group.
##
## Called by `LocalPawnDriver` between sampling and announcing the command, so the
## camera, the sender and the prediction all see the same command — `InputSender`
## sends it the moment it is announced.
class_name GroupFollow
extends RefCounted

var _kind: int = BlendKind.Kind.NONE
var _slot := Vector3.ZERO
var _slot_velocity := Vector3.ZERO
var _slot_tick := -1
## The newest snapshot read, kept apart from `_slot_tick`, which a non-group snapshot
## clears. **Snapshots ride an unordered channel**: a group snapshot arriving after
## the one that ended the blend switched the walking back on (review of #253).
var _seen_tick := -1


## Read the owner's blend and slot off each snapshot. The slot's velocity is taken
## from consecutive snapshots, because the group's pace varies (`CrowdFormations`).
func observe(snapshot: Snapshot) -> void:
	if snapshot.server_tick <= _seen_tick:
		return
	_seen_tick = snapshot.server_tick
	_kind = snapshot.blend_state
	if _kind != BlendKind.Kind.GROUP:
		_slot_tick = -1
		_slot_velocity = Vector3.ZERO
		return
	if _slot_tick >= 0 and snapshot.server_tick > _slot_tick:
		var seconds := float(snapshot.server_tick - _slot_tick) / Tuning.net.server_tick
		_slot_velocity = (snapshot.blend_slot - _slot) / seconds
	_slot = snapshot.blend_slot
	_slot_tick = snapshot.server_tick


## Rewrite `command` to walk a player standing at `here` along with their group,
## if they are in one and keeping their hands off. `lead` is how far ahead of the
## slot's last measurement the command will land on the server: the round trip.
func steer(command: InputCommand, here: Vector3, lead: float) -> void:
	if _kind != BlendKind.Kind.GROUP or _slot_tick < 0:
		return
	if command.wants_movement() or (command.buttons & InputBits.HANDS_ON) != 0:
		return
	var steered := GroupFollowSteer.steer(here, _slot, _slot_velocity, lead, command.look_yaw)
	# Quantised here as the sampler quantises, so the pawn predicts with exactly
	# the value the server will receive (NETWORK_PROTOCOL §2).
	command.move = InputCodec.quantise_move(steered[0])
	command.slow = steered[1]
	command.follow = true


## A new connection is a new server whose ticks start again: forget everything.
func reset() -> void:
	_kind = BlendKind.Kind.NONE
	_slot_tick = -1
	_seen_tick = -1
	_slot_velocity = Vector3.ZERO


func is_following() -> bool:
	return _kind == BlendKind.Kind.GROUP and _slot_tick >= 0
