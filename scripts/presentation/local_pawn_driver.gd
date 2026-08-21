## Drives the local pawn from sampled input, once per physics frame.
##
## **THIS IS THE WIRE FROM THE KEYBOARD TO THE SPEED LADDER.** Everything before
## it existed and did nothing: the six locomotion states have integrated motion
## since US-0015, but no `InputCommand` ever reached them, so launching the game
## showed a static map.
##
## The loop is the client half of TDD-03 §1.2, minus the network: sample, buffer
## for reconciliation, predict. Sending and reconciling arrive in M2 — until then
## the "prediction" is simply the simulation, which is exactly what makes it
## testable by a human now. `InputHistory` is filled anyway, because a buffer
## that starts being filled later is a buffer whose first use is also its first
## test.
##
## Presentation, not `scripts/pawn/`: it reaches for nodes, the clock and the
## scene tree. The deterministic part it calls into does not.
class_name LocalPawnDriver
extends Node

## Emitted after each step, for the camera and the HUD. Past tense: it is a fact
## that already happened, not a request.
signal pawn_stepped(ctx: PawnContext)

## Emitted once per physics frame with the command this loop just took, before it
## is stepped on. The camera listens; the net client will.
##
## **IT IS DECLARED HERE, NOT ON `InputSampler`, BECAUSE THIS IS THE ONLY CALLER
## OF `sample()`.** It used to be the sampler's, emitted from a `_physics_process`
## the sampler ran alongside this one — so input was sampled twice a frame and
## every counter behind it ran at 120 Hz. `SprintGate` is what showed it:
## `TUN-SPEED-SPRINT-HOLD` is 0.4 s of deliberate friction (GDD-02 §1.5) and it
## was opening in 0.21. A signal whose emitter is not the thing that produced the
## value is an invitation to produce it somewhere else too.
signal command_sampled(command: InputCommand)

@export var pawn_path: NodePath
@export var sampler_path: NodePath

## Where the pawn starts. `MapData.spawn_points` is authoritative; this is only
## the index into it, because spawn SELECTION is `SYS-SPAWN` (US-0062) and
## picking one here would be a rule in the wrong layer.
@export var spawn_index: int = 0

var ctx := PawnContext.new()

## The unacked command ring, and the pieces the reconciler must replay through.
##
## **EXPOSED, NOT PRIVATE.** `Reconciler` re-runs buffered commands through the
## *same* machine, probes and body this loop predicted with — a second set would
## be a second answer, which is the one thing reconciliation cannot tolerate.
var history := InputHistory.new()
var machine: PawnStateMachine
var probes: TraversalProbes

var _body: CharacterBody3D
var _sampler: InputSampler


func _ready() -> void:
	_body = get_node_or_null(pawn_path) as CharacterBody3D
	_sampler = get_node_or_null(sampler_path) as InputSampler
	if _body == null or _sampler == null:
		Log.error("LocalPawnDriver is not wired to a pawn and a sampler", &"pawn")
		set_physics_process(false)
		return
	machine = _body.get_node_or_null("PawnStateMachine") as PawnStateMachine
	if machine == null:
		Log.error("the local pawn has no PawnStateMachine", &"pawn")
		set_physics_process(false)
		return
	probes = _body.get_node_or_null("TraversalProbes") as TraversalProbes
	if probes == null:
		Log.error("the local pawn has no TraversalProbes", &"pawn")
		set_physics_process(false)
		return

	ctx.body = _body
	ctx.reset_for_spawn(_spawn_position(), 0.0)
	# PLACED, not transitioned. `PawnContext` starts in `Respawning`, which is
	# SYS-SPAWN's state and does not exist until US-0062 — and a pawn being put
	# into the world has no state to come *from* anyway.
	if not machine.spawn_into(ctx, PawnStateId.IDLE):
		set_physics_process(false)
	_body.global_position = ctx.position
	# A spawn is a teleport, and the engine would otherwise draw the pawn sliding in
	# from wherever the node last was. See `Reconciler._snap_and_replay`.
	_body.reset_physics_interpolation()
	_attach_feel_readout()


## US-0024's feel-gate readout, in debug builds only.
##
## **LOADED, NEVER REFERENCED BY A SCENE.** The three release presets exclude
## `scripts/debug/*`, so a `.tscn` naming that script would ship a scene pointing
## at a file that is not there. Two guards, because either alone is a way to
## break an export: `has_feature("debug")` is false in a release build, and the
## existence check covers a debug build assembled with the folder stripped
## anyway. `test_no_scene_references_debug.gd` guards the other direction.
func _attach_feel_readout() -> void:
	const PATH := "res://scripts/debug/feel_readout.gd"
	if not OS.has_feature("debug") or not ResourceLoader.exists(PATH):
		return
	(load(PATH) as GDScript).attach(self, self)
	_attach_net_readout()


## US-0045's netcode readout, in debug builds only and by the same two guards.
##
## **IT EXISTS BECAUSE A JITTER WAS DIAGNOSED WRONGLY THREE TIMES FROM PROSE.**
## The person who can feel a correction had no way to read its direction, and the
## direction is the whole diagnosis: along the heading is a step-count
## disagreement, across it is the server integrating a different input.
func _attach_net_readout() -> void:
	const NET_PATH := "res://scripts/debug/net_readout.gd"
	if not OS.has_feature("debug") or not ResourceLoader.exists(NET_PATH):
		return
	(load(NET_PATH) as GDScript).attach(self, self)
	_attach_district_map()


## A coloured district and a map of it, in debug builds only and by the same two
## guards. **NOT A MINIMAP**: never-do #12 forbids one as a permanent design law,
## and this cannot ship — `scripts/debug/` is excluded from all three release
## presets and `test_no_scene_references_debug.gd` refuses any scene naming it.
func _attach_district_map() -> void:
	const MAP_PATH := "res://scripts/debug/district_map.gd"
	if not OS.has_feature("debug") or not ResourceLoader.exists(MAP_PATH):
		return
	(load(MAP_PATH) as GDScript).attach(self, self)


func _physics_process(delta: float) -> void:
	# THE ONLY CALL TO sample() IN THE PROJECT. See the signal below it.
	var command := _sampler.sample(delta)
	# Announced before step(), which is where the sampler used to announce it from
	# its own loop — so the camera still reads the look on the same side of the
	# state machine it always did.
	command_sampled.emit(command)
	# **THE SAME CODE THE SERVER RUNS**, not a copy of it — ADR-0008 requires the
	# state machine to match, and stepping it is only half of a tick. US-0028.
	PawnMotion.advance(ctx, machine, probes, _body, command, delta)
	# **BUFFERED AFTER THE STEP, WITH WHAT THE STEP PRODUCED.** The history's job
	# is to answer "what did we think was true once the server had this command",
	# and the answer does not exist until the command has been applied.
	history.push(command, PredictedState.capture(ctx))
	pawn_stepped.emit(ctx)


func _spawn_position() -> Vector3:
	var map := load("res://data/maps/map_vetraio.tres") as MapData
	if map == null or map.spawn_count() == 0:
		return Vector3.ZERO
	return map.spawn_points[clampi(spawn_index, 0, map.spawn_count() - 1)]


## Whether the player may aim the camera right now. `CameraRig` asks; the answer
## belongs to the pawn's current state, which is where GDD-02 §4 puts it.
func camera_controlled() -> bool:
	return machine == null or machine.camera_controlled(ctx)


## The FOV rung the pawn is on. Asked for by `CameraRig` and answered by the
## state, the same delegation as above and for the same reason: GDD-02 §4.2 binds
## the lens to the SPEED STATE, and a rig deciding it from `ctx.velocity` would
## drift from the state table on every acceleration ramp.
func camera_fov() -> float:
	return CameraFov.default_fov() if machine == null else machine.camera_fov(ctx)
