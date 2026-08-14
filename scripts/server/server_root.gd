## **WHERE THE SERVER'S PIECES ARE JOINED**, and the only place. TDD-01 §3.1.
##
## `RpcRouter` does not know `MatchDirector` exists and the director does not
## know the router does. Each announces what happened and neither reaches for the
## other — which is what lets both be tested with nothing else present, and what
## keeps the topology a question you answer by reading one file.
##
## This node is that file. Adding a system means adding a line here, visibly,
## rather than discovering at runtime that nobody ticked it.
extends Node

const MAP := "res://data/maps/map_vetraio.tres"

@onready var director: MatchDirector = $MatchDirector
@onready var router: RpcRouter = $NetServer/RpcRouter
@onready var pawns: PawnHost = $World/Pawns


func _ready() -> void:
	director.ctx.map = load(MAP) as MapData
	pawns.setup(director.ctx)

	router.input_received.connect(director.enqueue_input)
	director.input_applied.connect(pawns.apply_input)

	# A pawn on join, and the router told so it can authorise that peer's input.
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Log.info("server topology wired: router -> director -> pawns", &"net")


func _on_peer_joined(peer: int) -> void:
	if pawns.spawn(peer):
		router.set_pawn_owner(peer, true)


## **EVERY OWNER OF PER-PEER STATE IS TOLD, IN ONE PLACE.** ENet reuses peer ids,
## so anything left behind is inherited by the next joiner: a stale sequence
## makes their input arrive in the past, a stale pawn flag authorises input for
## somebody else's pawn, and a stale pawn keeps simulating with nobody driving it.
func _on_peer_left(peer: int) -> void:
	pawns.despawn(peer)
	router.forget(peer)
	director.forget(peer)
