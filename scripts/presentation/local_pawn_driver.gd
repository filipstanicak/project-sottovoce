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

@export var pawn_path: NodePath
@export var sampler_path: NodePath

## Where the pawn starts. `MapData.spawn_points` is authoritative; this is only
## the index into it, because spawn SELECTION is `SYS-SPAWN` (US-0062) and
## picking one here would be a rule in the wrong layer.
@export var spawn_index: int = 0

var ctx := PawnContext.new()

var _body: CharacterBody3D
var _machine: PawnStateMachine
var _sampler: InputSampler
var _history := InputHistory.new()


func _ready() -> void:
	_body = get_node_or_null(pawn_path) as CharacterBody3D
	_sampler = get_node_or_null(sampler_path) as InputSampler
	if _body == null or _sampler == null:
		Log.error("LocalPawnDriver is not wired to a pawn and a sampler", &"pawn")
		set_physics_process(false)
		return
	_machine = _body.get_node_or_null("PawnStateMachine") as PawnStateMachine
	if _machine == null:
		Log.error("the local pawn has no PawnStateMachine", &"pawn")
		set_physics_process(false)
		return

	ctx.body = _body
	ctx.reset_for_spawn(_spawn_position(), 0.0)
	# PLACED, not transitioned. `PawnContext` starts in `Respawning`, which is
	# SYS-SPAWN's state and does not exist until US-0062 — and a pawn being put
	# into the world has no state to come *from* anyway.
	if not _machine.spawn_into(ctx, PawnStateId.IDLE):
		set_physics_process(false)
	_body.global_position = ctx.position


func _physics_process(delta: float) -> void:
	var command := _sampler.sample(delta)
	_history.push(command)
	_machine.step(ctx, command, delta)
	_apply_motion(command)
	pawn_stepped.emit(ctx)


## Move the body from the velocity the state machine computed, and write back
## what actually happened. The write-back matters: a pawn that walked into a wall
## has a velocity the simulation must know about, or the next tick accelerates
## from a speed it never reached.
func _apply_motion(command: InputCommand) -> void:
	ctx.yaw = command.look_yaw
	_body.rotation.y = ctx.yaw
	_body.velocity = ctx.velocity
	if not ctx.grounded or not _body.is_on_floor():
		_body.velocity.y -= _gravity() * (1.0 / Tuning.net.client_input_rate)
	_body.move_and_slide()
	ctx.velocity = _body.velocity
	ctx.position = _body.global_position
	ctx.grounded = _body.is_on_floor()


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _spawn_position() -> Vector3:
	var map := load("res://data/maps/map_vetraio.tres") as MapData
	if map == null or map.spawn_count() == 0:
		return Vector3.ZERO
	return map.spawn_points[clampi(spawn_index, 0, map.spawn_count() - 1)]


## Unacknowledged commands, for the reconciliation US-0033 will perform.
func history() -> InputHistory:
	return _history
