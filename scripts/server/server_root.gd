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

@onready var director: MatchDirector = $MatchDirector
@onready var router: RpcRouter = $NetServer/RpcRouter


func _ready() -> void:
	router.input_received.connect(director.enqueue_input)
	Net.peer_left.connect(director.forget)
	Log.info("server topology wired: router -> director", &"net")
