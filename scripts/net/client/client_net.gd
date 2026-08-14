## **THE CLIENT'S NET WIRING, IN ONE PLACE.** TDD-01 §3.2, US-0030. CLIENT ONLY.
##
## The mirror of `server_root.gd`: `InputSender` does not know `RemotePawns`
## exists, `RemotePawns` does not know where a snapshot came from, and neither
## reaches for the other. This node is where they are joined, so the client's
## topology is a question you answer by reading one file.
##
## It also carries the one fact both of them need and neither can discover: **the
## client's own wire slot**, which arrives in `NET-S2C-WELCOME` and is what tells
## `RemotePawns` which record in the snapshot is the player themselves.
extends Node

@onready var remotes: RemotePawns = $RemotePawns


func _ready() -> void:
	Net.handshake_completed.connect(_on_handshake_completed)
	Net.handshake_rejected.connect(_on_handshake_rejected)


## **THE SLOT, NOT THE PEER ID.** `GameState.local_peer_id` holds what the server
## called us on the wire, because that is the number every other message uses to
## name a player — see `slot_table.gd`.
func _on_handshake_completed() -> void:
	remotes.set_own_slot(GameState.local_peer_id)
	Log.info("client is slot %d" % GameState.local_peer_id, &"net")


func _on_handshake_rejected(reason: Messages.Reject) -> void:
	Log.error("client refused: %s" % Handshake.reason_text(reason), &"net")
