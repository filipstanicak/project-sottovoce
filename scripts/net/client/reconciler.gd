## **THE SIMULATION SNAPS; THE VISUAL BLENDS.** TDD-04 §4.2, US-0033.
## CLIENT ONLY.
##
## That sentence is the whole design, and TDD-04 calls it the most important one
## in the chapter. **If the simulation blended**, every later prediction would run
## from a position the server never had, and the error would compound instead of
## converging — a client that drifts further from the truth the harder it tries
## to hide the correction.
##
## So on a divergence the context is snapped to the server's answer exactly, every
## unacknowledged command is replayed through the same `PawnMotion` the server
## used, and the *difference between where the pawn was drawn a moment ago and
## where it now is* is handed to the visuals as an offset that decays over
## `TUN-NET-RECONCILE-SMOOTH-TIME`. The player sees a slide; the simulation sees
## a snap.
##
## **IT RECONCILES ON A PHYSICS FRAME, NOT ON ARRIVAL.** A replay calls
## `move_and_slide()` and re-casts the traversal probes, and both are only valid
## inside the physics step — Godot delivers RPCs on the idle frame. The snapshot
## is held and answered from `pawn_stepped`, which also guarantees the replay
## happens *after* this frame's prediction rather than racing it.
class_name Reconciler
extends Node

## A correction was applied. Carries the error in metres and whether it was large
## enough to replay, so the HUD and the tests can tell a nudge from a snap.
signal corrected(error: float, replayed: bool)

@export var driver_path: NodePath

## Cumulative, never reset: a connection-health figure, and a counter that resets
## hides a stall.
var replays: int = 0
var forced: int = 0

## **THE LAST COMPARISON'S RESULT, IN METRES.** How far the server's answer was
## from what this client predicted *for the same command* — not from where the
## client is now, which is always further along and is not an error.
##
## Kept because a test that wants "do the two peers agree" had nothing to read
## and reached for the live position difference instead, which measures the
## prediction lead and is non-zero when everything is perfect.
var last_error: float = 0.0

var _driver: LocalPawnDriver
var _visuals: Node3D
var _pending: Snapshot = null
var _offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	_driver = get_node_or_null(driver_path) as LocalPawnDriver
	if _driver == null:
		Log.error("Reconciler is not wired to a driver", &"net")
		return
	_driver.pawn_stepped.connect(_on_pawn_stepped)
	Net.snapshot_received.connect(_on_snapshot_received)


## Hold it. Answering here would run physics queries on an idle frame.
func _on_snapshot_received(snapshot: Snapshot) -> void:
	_pending = snapshot


## The visuals are found on first use, not in `_ready()`.
##
## Node order decides which `_ready()` runs first, and this node sits above
## `LocalPawnDriver` in `client_root.tscn` — so the driver has no body yet when
## this one starts. Resolving lazily is order-independent, which is worth more
## than saving one null check per frame.
func _resolve_visuals() -> void:
	if _visuals != null or _driver.ctx.body == null:
		return
	_visuals = _driver.ctx.body.get_node_or_null("PersonaVisuals") as Node3D


func _on_pawn_stepped(_ctx: PawnContext) -> void:
	_resolve_visuals()
	if _pending != null:
		_reconcile(_pending)
		_pending = null
	_decay_visual_offset()


## Compare, and correct if the server disagrees by more than the threshold.
func _reconcile(snapshot: Snapshot) -> void:
	var history := _driver.history
	var predicted := history.state_at(snapshot.last_acked_seq)
	history.ack(snapshot.last_acked_seq)
	if predicted == null:
		# Nothing to compare against — a snapshot acking a command already
		# discarded, or one from before this client sent anything. Not an error,
		# and not a reason to snap: the next snapshot will have a match.
		return

	var authoritative := PredictedState.from_snapshot(snapshot)
	var error := authoritative.error_against(predicted)
	last_error = error
	if error <= Tuning.net.reconcile_threshold:
		corrected.emit(error, false)
		return
	_snap_and_replay(authoritative)
	corrected.emit(error, true)


## **THE SNAP.** The context takes the server's answer exactly, then every
## unacked command is re-run through the identical code path that produced the
## prediction in the first place — which is why `PawnMotion` was extracted in
## US-0028 rather than copied.
func _snap_and_replay(authoritative: PredictedState) -> void:
	var ctx := _driver.ctx
	var drawn := ctx.position
	authoritative.apply_to(ctx)
	for command: InputCommand in _driver.history.unacked():
		PawnMotion.advance(
			ctx, _driver.machine, _driver.probes, ctx.body, command, MatchContext.step_dt()
		)
	# Where the pawn WAS drawn, minus where it now is. Handing the difference to
	# the visuals is what turns a snap into a slide.
	_offset += drawn - ctx.position
	replays += 1


## Decay the visual offset toward zero over `TUN-NET-RECONCILE-SMOOTH-TIME`.
##
## **THE VISUALS MOVE, THE BODY DOES NOT.** `PersonaVisuals` is a child of the
## collider, so a local offset draws the pawn away from where it is simulated
## without the simulation ever learning about it.
func _decay_visual_offset() -> void:
	if _visuals == null:
		return
	var smooth: float = maxf(Tuning.net.reconcile_smooth_time, 0.001)
	var step := MatchContext.step_dt() / smooth
	_offset = _offset.lerp(Vector3.ZERO, clampf(step, 0.0, 1.0))
	if _offset.length() < Tuning.net.quant_pos:
		_offset = Vector3.ZERO
	_visuals.position = _offset


## How far the drawn pawn currently is from the simulated one. For the tests, and
## for the readout that will show a player their own correction rate.
func visual_offset() -> Vector3:
	return _offset
