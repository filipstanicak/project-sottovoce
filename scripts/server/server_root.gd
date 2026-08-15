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
@onready var snapshots: SnapshotBuilder = $NetServer/SnapshotBuilder
@onready var lag_comp: LagCompRecorder = $NetServer/LagCompRecorder
@onready var crowd: NpcPool = $World/Crowd


func _ready() -> void:
	director.ctx.map = load(MAP) as MapData
	pawns.setup(director.ctx)
	_seed_the_match()
	_stand_the_crowd_up()

	# **THE MATCH STARTS IMMEDIATELY, AND THAT IS A PLACEHOLDER.** `SYS-MATCH`
	# owns the phase — lobby, warmup, the 8-minute clock and the final minute —
	# and it is M4's. Until it exists there is no lobby to leave, and a server
	# stuck in LOBBY would authorise no input and simulate nothing, which would
	# make M2 unobservable. Both the director and the router are told, because
	# the router refuses input on a phase it was never given.
	director.ctx.phase = MatchPhase.Phase.ACTIVE
	router.set_phase(MatchPhase.Phase.ACTIVE)

	# **THE DOORWAY IS `Net` AND THE DECIDER IS THE ROUTER.** Godot addresses an
	# RPC by node path and only the autoload shares one across peers, so the
	# handlers live there and call `router.authorise()` first. US-0030.
	Net.bind_router(router, director.ctx.slots)
	router.input_received.connect(director.enqueue_input)
	director.input_applied.connect(pawns.apply_input)

	_wire_end_of_tick()

	# A pawn on join, and the router told so it can authorise that peer's input.
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Log.info("server topology wired: net -> router -> director -> pawns -> snapshots", &"net")


## **THE SEED, FROM `--seed` OR THE CLOCK.** `LaunchConfig` has parsed `--seed`
## since M0 and, until now, only **logged** it — the flag existed and changed
## nothing. It reaches `MatchContext` here, so a deterministic run is actually
## deterministic.
##
## Without the flag the server picks one and **logs it**, which is what makes a
## surprising match reproducible afterwards. `SYS-MATCH` will own this at M4 and
## send it in `NET-S2C-MATCH-START`; the protocol already has the field.
func _seed_the_match() -> void:
	var config := LaunchConfig.parse(OS.get_cmdline_user_args(), Tuning.match_rules.max_players)
	director.ctx.match_seed = (
		config.seed_value if config.seed_value >= 0 else int(Time.get_unix_time_from_system())
	)
	director.ctx.rng = RandomNumberGenerator.new()
	director.ctx.rng.seed = director.ctx.match_seed
	Log.info("match seed %d" % director.ctx.match_seed, &"crowd")


## **ALLOCATE THE CROWD BEFORE ANYTHING TICKS.** US-0039 built the pool and
## nothing instantiated one, so ninety bodies existed in tests and nowhere else —
## its first acceptance criterion was unticked for exactly that.
##
## `activate()` needs the personas players chose, and there is **no lobby**
## (`NET-C2S-LOADOUT` is M4's), so every persona is treated as in use. That is
## the safe direction: GDD-03 §6.3 rule 5 makes a player with no clones a marked
## man, and clones of an unplayed persona are explicitly harmless.
func _stand_the_crowd_up() -> void:
	crowd.preallocate()
	var players: int = Tuning.match_rules.max_players
	crowd.activate(
		Tuning.crowd.count_default_6p, director.ctx.match_seed, CrowdRoster.PLAYABLE, players
	)
	director.ctx.crowd = crowd


## **EVERYTHING THAT ANSWERS "WHERE WAS THE WORLD AT TICK N".** Both consumers
## hang off `tick_completed`, and they must hang off the **same** signal or a
## rewind and the snapshot it resolves against describe different moments.
##
## It was `net_ticked` until US-0035, while this file claimed "last in the tick".
## Full account on `MatchDirector.tick_completed`.
func _wire_end_of_tick() -> void:
	snapshots.setup(director.ctx, pawns, router)
	director.tick_completed.connect(snapshots.send_all)
	router.snapshot_acked.connect(snapshots.note_ack)

	# Recording only. Nothing reads the history until kill and stun exist in M4.
	lag_comp.setup(director.ctx, pawns)
	director.tick_completed.connect(lag_comp.record)


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
	snapshots.forget(peer)
