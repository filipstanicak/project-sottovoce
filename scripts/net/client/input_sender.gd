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
class_name InputSender
extends Node

@export var driver_path: NodePath

var _sent: int = 0


func _ready() -> void:
	var driver := get_node_or_null(driver_path) as LocalPawnDriver
	if driver == null:
		Log.error("InputSender is not wired to a driver", &"net")
		return
	driver.command_sampled.connect(_on_command_sampled)


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


## How many commands have gone upstream. For the integration test and the
## feel readout; nothing gameplay reads it.
func sent_count() -> int:
	return _sent
