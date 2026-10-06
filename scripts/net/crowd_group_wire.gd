## **`NET-S2C-CROWD-GROUPS`: WHICH CIVILIANS FORM A GROUP.** US-0107,
## NETWORK_PROTOCOL §3. A child of `EventWire`, so it is at the same path on every
## peer.
##
## Flat `[npc, tag, ...]` pairs of `BlendGroupTag`s: the whole table when `full`,
## only what changed otherwise. **Every player is told the same tags**, because
## they are facts about civilians (`CrowdGroups`); the recipient is one peer at a
## time only so that a player arriving mid-match can be sent the whole table while
## everybody else is sent the change.
class_name CrowdGroupWire
extends Node

## `NET-S2C-CROWD-GROUPS` arrived. CLIENT SIDE.
signal crowd_groups_received(full: bool, pairs: PackedByteArray)


## SERVER SIDE, to one player.
func send_crowd_groups(peer: int, full: bool, pairs: PackedByteArray) -> void:
	if not Net.is_server:
		return
	s2c_crowd_groups.rpc_id(peer, full, pairs)


## CLIENT SIDE. An odd-length list is not pairs and is dropped whole rather than
## read one byte out of step.
@rpc("authority", "call_remote", "reliable", Messages.Channel.EVENT)
func s2c_crowd_groups(full: bool, pairs: PackedByteArray) -> void:
	if pairs.size() % 2 == 0:
		crowd_groups_received.emit(full, pairs)
