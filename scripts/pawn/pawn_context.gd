## All mutable per-pawn data. TDD-06 §1 and §2.
##
## A `RefCounted`, NOT a node, so `PawnState.step()` can be called from a unit
## test with no scene tree. That is the whole reason the state pattern is worth
## its ceremony: fifteen states with per-state physics are testable in isolation
## only if the thing they mutate is a plain object.
##
## THE PREDICTED / AUTHORITATIVE SPLIT BELOW IS LOAD-BEARING. Motion and the
## state machine are replayed during reconciliation and must be deterministic.
## Suspicion, tier, blend state and the stun lockout come from the server and are
## NEVER predicted — a client-side estimate drifts, and a HUD that disagrees with
## the server is worse than no HUD (CLAUDE.md never-do #3).
class_name PawnContext
extends RefCounted

# --- Identity ---
var peer_id: int = 0
var persona: StringName = &""

# --- Motion (PREDICTED) ---
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var grounded: bool = true

# --- State machine (PREDICTED) ---
var state_id: StringName = PawnStateId.RESPAWNING

## Ticks since the current state was entered. INTEGER, never an accumulated
## float, because accumulated float error diverges between server and client.
##
## **INCREMENTED ONCE PER `step()`, SO IT COUNTS 60 Hz TICKS.** States compare it
## against `Tuning.step_ticks()`. Comparing it against `Tuning.ticks()`, which
## converts at the 30 Hz net tick, halves every duration silently — see
## `Tuning.step_ticks` for the four that shipped that way.
var state_timer_ticks: int = 0

# --- Traversal (PREDICTED) ---
var probe_result: ProbeResult = ProbeResult.new()
var traverse_buffer_ticks: int = 0
var ability_buffer_ticks: int = 0
var ledge_magnet_ticks: int = 0

# --- Gameplay (SERVER-AUTHORITATIVE — mirrored, NEVER predicted) ---
var suspicion: float = 0.0
var tier: int = 0
var blend_state: int = 0
var stun_lockout_until_tick: int = 0

## The physics body, or NULL in a unit test. EVERY STATE MUST TOLERATE NULL —
## that is what keeps `step()` callable without a scene tree, and a state that
## dereferences it unguarded silently makes itself untestable.
var body: CharacterBody3D = null


## True when a body is attached and motion should be integrated against it.
func has_body() -> bool:
	return body != null


## Reset for a fresh life. Called on respawn; suspicion goes to zero because
## GDD-02 §3.1 says a life never begins already accruing it.
func reset_for_spawn(at: Vector3, facing: float) -> void:
	position = at
	velocity = Vector3.ZERO
	yaw = facing
	grounded = true
	state_timer_ticks = 0
	suspicion = 0.0
	tier = 0
	blend_state = 0
	traverse_buffer_ticks = 0
	ability_buffer_ticks = 0
	ledge_magnet_ticks = 0
	probe_result.clear()
