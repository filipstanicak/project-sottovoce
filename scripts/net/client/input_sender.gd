## **THE CLIENT'S HALF OF THE 60 Hz INPUT RATE.** TDD-04 §6.1, TDD-01 §3.2.
## CLIENT ONLY.
##
## One `NET-C2S-INPUT` per sampled command, unreliable, on the `STATE` channel.
## Unreliable is the design: a retransmitted input arrives after a fresher one
## and the server has already moved past it — the **sequence gate** drops it, and
## the missing tick is covered by `MatchDirector` repeating the last command.
##
## It sends nothing but the command `LocalPawnDriver` already sampled. There is
## no second sampler and no second rate: `command_sampled` is emitted by the only
## caller of `InputSampler.sample()`, which is what trap 12 exists to preserve.
##
## **IT ALSO SENDS `NET-C2S-ABILITY-REQUEST`, WHICH NOTHING SENT UNTIL 2026-09-02.**
## The RPC, its authority row, its router hop and `SYS-ABILITY` behind it were all
## built at US-0066 — and pressing Q or F did **literally nothing** for three
## stories, because no client ever called it.
class_name InputSender
extends Node

## **THE TWO ABILITY SLOTS, IN BIT ORDER.** `AbilitySystem.loadout` is indexed by
## slot and `TUN-ABILITY-SLOTS-ACTIVE` is two, so the index into this array **is**
## the slot the server will look up.
const ABILITY_BITS: Array[int] = [InputBits.ABILITY_1, InputBits.ABILITY_2]

## **FURTHER THAN ANY ABILITY REACHES, SO THE SERVER'S OWN CLAMP DECIDES.**
## `AbilityRules.aim` treats the direction's **length** as the requested distance
## and clamps it to the ability's reach — and a client cannot know which ability
## is in which slot, because the loadout is the server's. Sending a long vector
## means *"as far as this one allows"*.
##
## **THE COST IS THAT A PLAYER CANNOT AIM SHORT**, which matters only for
## Cinderfall's throw: a Lunge always dashes its full distance, and there is no
## HUD indicator to aim a throw with anyway. Owed when one exists.
const AIM_REACH := 1000.0

@export var driver_path: NodePath

var _sent: int = 0
var _requested: int = 0
var _driver: LocalPawnDriver = null

## The buttons the previous command held. **Edge-detected here rather than on the
## server**, unlike kill and stun: those ride `InputCommand` and `KillSystem` keeps
## its own `_held` map, where an ability is a separate reliable message and there is
## no per-tick stream for the server to compare against.
var _held: int = InputBits.NONE


func _ready() -> void:
	_driver = get_node_or_null(driver_path) as LocalPawnDriver
	if _driver == null:
		Log.error("InputSender is not wired to a driver", &"net")
		return
	_driver.command_sampled.connect(_on_command_sampled)


## **EVERY SAMPLED COMMAND, WITHOUT A GATE OF ITS OWN.** Sending only commands
## that "changed" would look like a saving and would break the repeat rule: the
## server fills a tick it heard nothing in by repeating the last command, and a
## client that stopped sending while standing still would keep walking on the
## server for as long as it stood there.
func _on_command_sampled(command: InputCommand) -> void:
	if Net.is_server:
		return
	Net.send_input(command)
	_sent += 1
	_send_ability_presses(command)


## **THE LINK THAT DID NOT EXIST.** `NET-C2S-ABILITY-REQUEST`, its authority row,
## its router hop, `SYS-ABILITY`, `CinderfallEffect`, `LungeEffect` and `Lunging`
## were all built and **nothing on the client ever sent the message**, so pressing
## Q or F did literally nothing. Reported from the controls, which is the only
## place it could be: `tools/ability_probe.tscn` calls `report_request` directly on
## the server and cannot see this hop, which is the gap US-0074 lost an
## integration run to.
##
## **ON THE PRESS EDGE, NOT THE HOLD.** `InputCommand.buttons` is held state at
## 60 Hz; a held F would be sixty casts a second, every one of them refused by the
## cooldown and every one of them a reliable packet.
func _send_ability_presses(command: InputCommand) -> void:
	var pressed := InputBits.newly_pressed(command.buttons, _held)
	_held = command.buttons
	if pressed == InputBits.NONE or _driver == null:
		return
	# **THE AIM IS THE LOOK, NOT THE BODY.** `CameraArm.forward` is the project's
	# one yaw-to-vector conversion; a second would be the two-sign-convention
	# defect the Compass shipped with (US-0072).
	var aim := CameraArm.forward(command.look_yaw) * AIM_REACH
	for slot: int in ABILITY_BITS.size():
		if not InputBits.is_set(pressed, ABILITY_BITS[slot]):
			continue
		_request(slot, _driver.ctx.position, aim)
		_requested += 1


## **THE RPC STAYS ON `Net` AND ONLY THE WRAPPER LIVES HERE.** An RPC resolves by
## **node path**, so `c2s_ability_request` has to be declared on the autoload that
## exists at the same path on every peer — US-0030's lesson, when the whole
## authority chokepoint was unreachable because the router was not at a shared
## path. What does not have to live there is the four lines that call it, and
## `net.gd` is at 398 of its 400: its own comment has said since M4 that *"the C2S
## doorway below could move the same way if this file grows again"*.
##
## **RELIABLE, UNLIKE THE INPUT STREAM.** A dropped `NET-C2S-INPUT` is covered by
## the server repeating the last command; a dropped ability press is a 30 s
## cooldown the player spent on nothing.
func _request(slot: int, origin: Vector3, direction: Vector3) -> void:
	if not Net.is_client_connected():
		return
	Net.c2s_ability_request.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, slot, origin, direction)


## How many commands have gone upstream. For the integration test and the
## feel readout; nothing gameplay reads it.
func sent_count() -> int:
	return _sent


## How many ability presses have gone upstream. The counter exists because the
## whole path had no caller and nothing could have said so.
func requested_count() -> int:
	return _requested
