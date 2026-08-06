## Base class for every pawn state. TDD-06 §2.1, ADR-0008.
##
## STATELESS WITH RESPECT TO THE PAWN. All mutable data lives in `PawnContext`,
## so ONE instance of each state is shared across every pawn on the server —
## fifteen objects total, not fifteen per player. A subclass that declares a
## `var` has made every pawn on the server share it, and the symptom is one
## player's vault ending another player's climb. `test_pawn_states_stateless.gd`
## asserts no subclass declares one.
##
## `step()` MUST be a pure function of (ctx, input, delta). It must not call
## `randf`, `randi`, `Time.*`, `get_node`, `get_tree`, or any autoload except
## `Tuning` — this code is replayed during prediction reconciliation, and
## anything that reads the wall clock or the tree produces a different answer on
## the replay than it did the first time. `test_pawn_determinism_grep.gd`
## enforces it.
class_name PawnState
extends RefCounted

enum { PRIORITY_NORMAL = 0, PRIORITY_COMBAT = 10, PRIORITY_FATAL = 20 }

## Remain in the current state. Returned by `step()` far more often than not, so
## it is named rather than being a bare `&""` at forty call sites.
const STAY := &""


## Called once on entry. MUST reset `ctx.state_timer_ticks`.
##
## NEVER ASSUME IT IS PAIRED WITH A MATCHING exit(). A FATAL-priority transition
## can take a pawn out of any state without ceremony, so `enter()` must leave the
## context valid on its own rather than relying on cleanup that may not run.
##
## A subclass that overrides this MUST call `super(ctx)`.
func enter(ctx: PawnContext) -> void:
	ctx.state_timer_ticks = 0


func exit(_ctx: PawnContext) -> void:
	pass


## Whether this state writes `ctx.position` itself rather than integrating a
## velocity. False for everything except traversal.
##
## **A TRAVERSAL IS A FIXED DISPLACEMENT AGAINST STATIC GEOMETRY**, planned once
## and interpolated (ANIMATION_SPEC §4). The driver must move the body TO that
## position rather than running `move_and_slide()` and reading back where the
## physics engine put it — which, with the velocity frozen, is nowhere. A vault
## that computed a perfect arc and never moved the pawn is exactly what that
## looks like, and no unit test can see it.
func drives_position() -> bool:
	return false


## Whether the player may still aim the camera in this state. GDD-02 §4.
##
## **TRUE FOR EVERYTHING EXCEPT BEING STUNNED**, deliberately and including the
## kill animation, the vault and the drop. Those take away your *movement*, and
## taking away the look as well would mean the game deciding what you get to
## witness during the seconds you have least control — in a game whose whole
## subject is watching and being watched.
##
## `Stunned` is the exception because helplessness is the mechanic there: design
## law 5 says the prey must have teeth, and the teeth are that a reckless hunter
## loses the ability to *look* as well as to move.
func camera_controlled() -> bool:
	return true


## The deterministic step. Returns the id of the requested next state, or STAY.
##
## It REQUESTS; the machine VALIDATES. A state does not know the transition
## graph, which is what keeps the graph in one readable place (TDD-06 §2.2).
func step(_ctx: PawnContext, _input: InputCommand, _delta: float) -> StringName:
	return STAY


## Suspicion generated per second in this state. READ FROM TUNING, never a
## literal — every gameplay number lives in `data/tuning/default/*.tres`.
func suspicion_rate(_ctx: PawnContext) -> float:
	return 0.0


func camera_fov(_ctx: PawnContext) -> float:
	return Tuning.camera.fov_stroll


func interrupt_priority() -> int:
	return PRIORITY_NORMAL


## Whether a lower-priority transition may interrupt right now.
##
## Time-based, not a constant, for the states where it changes mid-animation:
## `KillAnim` is interruptible by COMBAT only before its contact frame.
func is_interruptible(_ctx: PawnContext) -> bool:
	return true


## The id this state is registered under. Every subclass overrides it, and the
## machine asserts the registry key matches — a state registered under the wrong
## name produces transitions that silently go somewhere else.
func id() -> StringName:
	return STAY
