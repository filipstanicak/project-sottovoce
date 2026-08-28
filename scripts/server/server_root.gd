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

## Every message this server sends, and the one place a peer becomes a wire slot.
var announcer: MatchAnnouncer = null

var _fallen_reported: int = 0

@onready var director: MatchDirector = $MatchDirector
@onready var router: RpcRouter = $NetServer/RpcRouter
@onready var pawns: PawnHost = $World/Pawns
@onready var snapshots: SnapshotBuilder = $NetServer/SnapshotBuilder
@onready var lag_comp: LagCompRecorder = $NetServer/LagCompRecorder
@onready var crowd: NpcPool = $World/Crowd
@onready var crowd_director: CrowdDirector = $Systems/CrowdDirector
@onready var contracts: ContractSystem = $Systems/ContractSystem
@onready var suspicion: SuspicionSystem = $Systems/SuspicionSystem
@onready var detection: DetectionSystem = $Systems/DetectionSystem
@onready var kills: KillSystem = $Systems/KillSystem
@onready var abilities: AbilitySystem = $Systems/AbilitySystem


func _ready() -> void:
	director.ctx.map = load(MAP) as MapData
	pawns.setup(director.ctx)
	announcer = MatchAnnouncer.new(director.ctx)
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

	_wire_the_doorway()
	_wire_end_of_tick()
	director.tick_completed.connect(_log_starvation)

	# A pawn on join, and the router told so it can authorise that peer's input.
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Log.info("server topology wired: net -> router -> director -> pawns -> snapshots", &"net")


## **THE DOORWAY IS `Net` AND THE DECIDER IS THE ROUTER.** Godot addresses an RPC
## by node path and only the autoload shares one across peers, so the handlers
## live there and call `router.authorise()` first. US-0030.
func _wire_the_doorway() -> void:
	Net.bind_router(router, director.ctx.slots)
	router.input_received.connect(director.enqueue_input)
	director.input_applied.connect(pawns.apply_input)
	# **THE SAME SIGNAL, AND `SYS-KILL` DOES ITS OWN EDGE DETECTION FROM IT.**
	# `PawnContext.held_buttons` is rewritten inside `step()` at 60 Hz, so by the
	# `combat` stage every press already reads as held.
	director.input_applied.connect(kills.report_input)
	director.input_applied.connect(kills.report_stun_input)


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
	var count: int = Tuning.crowd.count_default_6p
	crowd.activate(count, director.ctx.match_seed, CrowdRoster.PLAYABLE, players)
	director.ctx.crowd = crowd
	_place_the_crowd.call_deferred(count)


## **ON THE NAVMESH, OR THEY CANNOT LEAVE.** The world's navigation map is the one
## `NavigationRegion3D` in the map scene publishes; an NPC placed off it is an NPC
## its agent can never path away from, which reads as a broken NPC rather than a
## broken placement.
##
## Placed from the map's idle anchors rather than scattered uniformly: a uniform
## spread over 120 × 120 m would put the crowd in the middle of streets and
## nobody anywhere a person would actually stand.
func _place_the_crowd(count: int) -> void:
	var map: RID = crowd.get_world_3d().navigation_map
	await _await_navigation_map(map)

	var spots := CrowdPlacement.positions(
		count, director.ctx.match_seed, director.ctx.map.idle_anchors, map
	)
	# **THE PLACEMENT DOES NOT KNOW WHO ANYBODY IS, AND THE ROSTER DOES NOT KNOW
	# WHERE ANYBODY STANDS.** Both are derived from the seed and both are right;
	# nothing joined them until US-0096, so a match could open with every Lucerna
	# in the north and a Lucerna player spawning in the south. `CrowdSeating`
	# permutes the assignment, never the positions.
	spots = CrowdSeating.seat(
		spots, crowd.roster, director.ctx.map.spawn_points, director.ctx.match_seed
	)
	for index: int in spots.size():
		crowd.set_position(index, spots[index])
	Log.info(
		(
			"crowd placed: %d NPCs across %d anchors"
			% [spots.size(), director.ctx.map.idle_anchors.size()]
		),
		&"crowd"
	)

	_start_the_crowd_system()


## **REGISTERED HERE, AND NOT A LINE EARLIER.** `MatchDirector.register()` is what
## puts a system into `SystemOrder`'s order — a `CrowdDirector` node sitting in the
## scene with nobody calling it would configure ninety agents and tick none of
## them, which is the exact shape of US-0039's ticked-but-false criterion.
## Registering it *after* placement matters too: a crowd ticked while still
## stacked at the origin would plan ninety paths from a corner and then be
## teleported off every one of them.
##
## **AND THE PROCESSIONS SET OFF.** After registration, because `setup()` is what
## builds the circuits from `MapData`; after placement, because a group forms
## around whoever is nearest its slots.
func _start_the_crowd_system() -> void:
	director.register(crowd_director)
	crowd_director.form_groups()
	director.register(contracts)
	contracts.setup(director.ctx)
	contracts.contract_issued.connect(announcer.contract_issued)

	# **AFTER THE CROWD, AND `SystemOrder` IS WHAT MAKES THAT TRUE** rather than
	# this line's position: a system registered backwards still ticks in the
	# document's order. The order here is only the reading order.
	director.register(suspicion)
	suspicion.blend.blend_refused.connect(announcer.blend_refused)
	director.register(detection)
	detection.prey_warned.connect(announcer.prey_warned)
	# **BEFORE `combat`**: a Cinderfall thrown this tick must already block kills
	# when the kill stage runs, and `SystemOrder` is what makes that true.
	director.register(abilities)
	abilities.setup(director.ctx)
	router.ability_requested.connect(abilities.report_request)
	abilities.ability_started.connect(_on_ability_started)
	abilities.ability_denied.connect(announcer.ability_denied)
	director.register(kills)
	kills.setup(director.ctx)
	# **ADR-0015: A KILL NEEDS A CLEAR LINE.** Bound rather than reached for —
	# `KillRules` is pure Core and `has_los` is `SYS-DETECTION`'s single ray site.
	kills.sight = detection.clear_line
	# **WHAT A KILL IS WORTH, BOUND RATHER THAN REACHED FOR** (US-0065). `SYS-BLEND`
	# is handed over because `SCORE-BLENDED` asks it a question.
	kills.scoring = KillScoring.new(suspicion.blend)
	_wire_the_combat_answers()


## Every message the two combat systems produce, and the one payment a stun earns.
## **Split from `_start_the_crowd_system` for the length guard**, and the seam is
## honest: above is *register the systems in the document's order*, here is *what
## anybody is told when one of them decides something*.
func _wire_the_combat_answers() -> void:
	kills.killed.connect(_on_killed)
	kills.kill_rejected.connect(announcer.kill_rejected)
	kills.stun.stunned.connect(announcer.stunned)
	# **A STUN IS PAID FOR HERE RATHER THAN INSIDE `SYS-STUN`**, which decides and
	# announces; nothing about scoring is decided in it.
	kills.stun.stunned.connect(_pay_for_stun)
	kills.stun.stun_rejected.connect(announcer.stun_rejected)


## **WAIT FOR THE MAP, OR EVERY NPC LANDS AT THE ORIGIN.** A query before the
## navigation server's first synchronisation is an error, and the fallback answer
## is `Vector3.ZERO` — so the whole crowd would stack in one corner of the
## district, and it would read as a placement bug rather than a timing one.
##
## Two iterations, measured: the first registers the region, the second rasterises
## it. `map_force_update()` on its own does nothing. Bounded, so a genuinely
## broken map starts the server late rather than never. Same wait as
## `test_navmesh_coverage.gd`, for the same reason.
func _await_navigation_map(map: RID) -> void:
	var started: int = NavigationServer3D.map_get_iteration_id(map)
	for _i: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) >= started + 2:
			break


## **EVERYTHING THAT ANSWERS "WHERE WAS THE WORLD AT TICK N".** Both consumers
## hang off `tick_completed`, and they must hang off the **same** signal or a
## rewind and the snapshot it resolves against describe different moments.
##
## It was `net_ticked` until US-0035, while this file claimed "last in the tick".
## Full account on `MatchDirector.tick_completed`.
func _wire_end_of_tick() -> void:
	snapshots.abilities = abilities
	snapshots.setup(director.ctx, pawns, router)
	director.tick_completed.connect(snapshots.send_all)
	router.snapshot_acked.connect(snapshots.note_ack)

	# Recording only. Nothing reads the history until kill and stun exist in M4.
	lag_comp.setup(director.ctx, pawns)
	director.tick_completed.connect(lag_comp.record)

	# **THE SCORE LOG IS DRAINED LAST, LIKE THE SNAPSHOT AND FOR THE SAME REASON.**
	# Every bonus a tick pays is appended by the `combat` stage; a courier on
	# `net_ticked` would send the previous tick's, so a kill and the points for it
	# would reach the player 33 ms apart with nothing saying why.
	director.tick_completed.connect(announcer.flush_score)


## **HOW OFTEN THE INPUT QUEUE RAN DRY**, once every ten seconds and only while it
## is happening. A starved tick repeats the peer's last command, which is a step
## the client never predicted — felt as a tug toward the previous input. US-0028's
## repeat is correct for a *lost* command; this line is how you find out whether it
## is firing for merely *late* ones.
## **A CROWD THAT FALLS OUT OF THE WORLD SAYS SO.** `CrowdRescue` puts a fallen NPC
## back rather than letting the district quietly drain, and the count must be zero
## on a map whose routes are walkable — so a line here is a level-data defect
## reporting itself. Logged once per rise, not per tick.
func _log_the_fallen() -> void:
	var fallen := crowd_director.rescued_from_the_void()
	if fallen == _fallen_reported:
		return
	_fallen_reported = fallen
	Log.warn(
		(
			(
				"crowd fell out of the world: %d put back so far — a route crosses ground "
				+ "that does not exist (test_circuit_separation.gd)"
			)
			% fallen
		),
		&"crowd"
	)


func _log_starvation(_ctx: MatchContext, _dt: float) -> void:
	_log_the_fallen()
	if director.ctx.tick % 300 != 0 or director.starved_ticks == 0:
		return
	Log.info(
		(
			"input starvation: %d repeats over %d ticks (%.1f %%)"
			% [
				director.starved_ticks,
				director.ctx.tick,
				float(director.starved_ticks) / float(director.ctx.tick) * 100.0
			]
		),
		&"net"
	)


func _on_peer_joined(peer: int) -> void:
	if pawns.spawn(peer):
		router.set_pawn_owner(peer, true)
		contracts.report_join(peer, director.ctx)
		# **A PLACEHOLDER LOADOUT, AND IT SAYS SO.** `NET-C2S-LOADOUT` and the lobby
		# are US-0071's; until then every player carries the two MVP actives, because
		# a pipeline nobody can reach is a pipeline nobody can test.
		abilities.loadout[peer] = [Ids.ABIL_CINDERFALL, Ids.ABIL_LUNGE]


## The tell. Broadcast rather than addressed — see `MatchAnnouncer.ability_started`.
func _on_ability_started(
	peer: int, ability: StringName, origin: Vector3, direction: Vector3
) -> void:
	announcer.ability_started(director.ctx, peer, ability, origin, direction)


## **EVERY OWNER OF PER-PEER STATE IS TOLD, IN ONE PLACE.** ENet reuses peer ids,
## so anything left behind is inherited by the next joiner: a stale sequence
## makes their input arrive in the past, a stale pawn flag authorises input for
## somebody else's pawn, and a stale pawn keeps simulating with nobody driving it.
## **EVERY CONSEQUENCE OF A DEATH, IN THE TICK IT RESOLVES.** `SYS-KILL` decides
## and announces; nothing about the crowd, the cycle or suspicion is decided in
## it. The contract repair runs first because `SystemOrder` puts the `contract`
## stage immediately after `combat`, and the invariant is that nobody is
## contractless at a tick boundary.
func _on_killed(killer: int, victim: int, at: Vector3) -> void:
	contracts.report_death(victim, killer, director.ctx)
	# **THE SAME SIGNAL THAT REGISTERS THE CORPSE**, two lines below, which is what
	# makes GDD-02 §3's `Dead --> Respawning: corpse spawned` edge true rather than
	# approximately true. `SYS-SPAWN` is `SYS-CONTRACT`'s, so the placement and the
	# cycle insertion land in one tick.
	contracts.spawn.report_death(victim, killer, director.ctx)
	suspicion.blend.report_damage(victim, director.ctx)
	crowd_director.register_corpse(at, director.ctx.tick, victim)
	crowd_director.startle_at(at)
	_charge_for_witnesses(killer, at)
	abilities.on_death(victim)
	announcer.kill_landed(killer, victim)


## US-0052's last criterion: `TUN-SUSPICION-GAIN-WITNESSED-KILL` applies only if
## another PLAYER had line of sight.
##
## **PRESENT-TENSE, NOT REWOUND.** A witness did not *act*, so there is nothing of
## theirs to compensate for — what they see is the animation and the corpse, now —
## and rewinding their position would charge the killer for somebody who has since
## walked away. The victim is not a witness to their own death and the killer is
## not a witness to their own act.
func _charge_for_witnesses(killer: int, at: Vector3) -> void:
	for peer: int in director.ctx.pawn_contexts.keys():
		if peer == killer:
			continue
		var pawn := director.ctx.pawn_contexts[peer] as PawnContext
		if pawn.state_id == PawnStateId.DEAD:
			continue
		if not detection.clear_line(pawn.position, at):
			continue
		director.ctx.impulses.queue(killer, Tuning.suspicion.gain_witnessed_kill)
		return


func _pay_for_stun(stunner: int, target: int, _lockout_ticks: int) -> void:
	if kills.scoring != null:
		kills.scoring.pay_for_stun(director.ctx, stunner, target)


func _on_peer_left(peer: int) -> void:
	contracts.report_disconnect(peer, director.ctx)
	director.ctx.score_windows.forget(peer)
	abilities.forget(peer)
	contracts.spawn.forget(peer)
	detection.warning.forget(peer)
	kills.forget(peer)
	pawns.despawn(peer)
	router.forget(peer)
	director.forget(peer)
	snapshots.forget(peer)
