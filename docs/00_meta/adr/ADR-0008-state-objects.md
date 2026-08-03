---
id: ADR-0008
title: State objects over enum state machines
version: 1.0.0
status: accepted
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0001, ADR-0002]
supersedes: none
---

# ADR-0008 — State objects over enum state machines for the player pawn

## Context

The player pawn has fourteen states:

`Idle · Blend · Stroll · Jog · Sprint · Climb · Vault · Drop · Blended · KillAnim ·
StunAnim · Stunned · Dead · Respawning`

Each carries non-trivial per-state behaviour: its own movement integration, its own camera
FOV target (`TUN-CAM-FOV-*`), its own suspicion contribution
(`TUN-SUSPICION-GAIN-JOG/RUN/SPRINT/CLIMB`), its own animation, its own set of legal
transitions, and its own interrupt priority. Several are non-interruptible for a fixed
duration (`KillAnim` at `TUN-KILL-ANIM-DURATION`, `Stunned` at `TUN-STUN-FREEZE`).

Two additional constraints:

1. **The state machine is shared between client and server.** Client prediction (ADR-0002)
   replays the pawn's step function against buffered inputs. The state machine must be a
   pure, deterministic function of (state, input, tuning, world) with no frame-rate
   dependence and no hidden mutation.
2. **The file-length limit is 400 lines** and the function-length limit is 40
   ([`../../30_bible/CODING_STANDARDS.md`](../../30_bible/CODING_STANDARDS.md)). Fourteen
   states with per-state physics in one `match` block would be roughly 700 lines in a single
   file with one enormous function — a direct violation, and the classic shape of an
   unmaintainable controller.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **State objects: one `PawnState` subclass per state, held by a `StateMachine` component** | Each state is a small, separately testable file; transitions are declared, not scattered; adding a state adds a file rather than editing a monolith; naturally satisfies the length limits. | More files; one virtual dispatch per tick (negligible for one pawn); the transition graph is spread across the states unless deliberately centralised. | **Chosen** |
| `enum` + `match` in `_physics_process` | Fastest to write; all logic visible at once; zero indirection. | Becomes a 700-line file with a 400-line function; every state's code can touch every other state's variables; testing one state requires the whole pawn. | Rejected |
| Godot `AnimationTree` state machine driving gameplay | Visual authoring; already exists in-engine. | Couples gameplay logic to the animation graph, which is exactly backwards — animation should follow state, not define it. Also unusable in a headless server. | Rejected |
| Pushdown automaton (state stack) | Elegant for "return to previous state" cases (e.g. Vault → back to whatever you were doing). | Only two states genuinely need it, and a stack makes prediction replay harder to reason about because the *stack* is now part of the replayed state. | Rejected; see Consequences |

## Decision

**One class per state, all extending `PawnState`, owned by a `PawnStateMachine` component
on the pawn.**

```gdscript
## Base class for every player pawn state. Stateless with respect to the pawn:
## all mutable data lives on the pawn or in the context passed to step().
class_name PawnState
extends RefCounted

## Called once when this state becomes active. Never assume it is paired with exit().
func enter(ctx: PawnContext) -> void:
    pass

## Called once when leaving. Must not itself request a transition.
func exit(ctx: PawnContext) -> void:
    pass

## The deterministic step. Returns the StringName of the next state, or &"" to stay.
## MUST be a pure function of (ctx, input, delta). No randomness, no wall clock,
## no scene-tree lookups. This is replayed during prediction reconciliation.
func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
    return &""

## Suspicion generated per second while in this state. Read from Tuning; never a literal.
func suspicion_rate(ctx: PawnContext) -> float:
    return 0.0

## Camera FOV target for this state.
func camera_fov(ctx: PawnContext) -> float:
    return Tuning.camera.fov_stroll

## Interrupt priority. A transition requested by a higher-priority source
## (stun, death) preempts a non-interruptible state.
func interrupt_priority() -> int:
    return PawnState.PRIORITY_NORMAL

## Whether a lower-priority transition may interrupt this state right now.
func is_interruptible(ctx: PawnContext) -> bool:
    return true
```

Supporting rules:

1. **The transition table is centralised**, not scattered. `PawnStateMachine` holds a
   declared `Dictionary` of legal `from → [to]` edges. `step()` *requests* a transition; the
   machine *validates* it. An illegal request is an `assert` in debug and a `push_error` plus
   ignore in release. Without this, the transition graph exists only in the reader's head,
   which is the main weakness of the state-object pattern.
2. **`PawnContext` carries everything mutable** — velocity, position, suspicion accumulator,
   timers, the tuning reference, the traversal probe results. State objects hold no per-pawn
   data, so a single instance of each state is shared across all pawns on the server. Fourteen
   objects total, not fourteen per player.
3. **Non-interruptible states declare it** via `is_interruptible()` returning false with a
   timer, rather than by other code knowing not to interrupt them. `KillAnim` refusing
   interruption is a property of `KillAnim`, stated once.
4. **Interrupt priority is explicit**: `PRIORITY_NORMAL < PRIORITY_COMBAT < PRIORITY_FATAL`.
   A stun (COMBAT) preempts `Vault` (NORMAL) but not `Dead` (FATAL). This is the one piece of
   cross-state knowledge that genuinely must be global, so it is a declared constant, not an
   emergent property of transition ordering.
5. **No pushdown stack.** The two cases that would want it (Vault and Drop returning to the
   prior locomotion state) instead resolve by re-deriving the locomotion state from current
   input and speed on exit. Re-derivation is deterministic and keeps the replayed state a
   single `StringName`, which materially simplifies prediction reconciliation.

## Consequences

### Positive
- Each state file is 30–80 lines and is unit-testable in isolation: construct a
  `PawnContext`, call `step()`, assert the returned transition and the mutated context. No
  scene, no network, no engine loop.
- Prediction replay is a loop over buffered inputs calling `step()`. Because `step()` is pure,
  replay is exact.
- The 400-line and 40-line limits are satisfied naturally rather than fought.
- Adding a post-MVP state (e.g. a swim state, a carry state) is a new file plus two rows in
  the transition table. Nothing existing is edited.
- Shared state instances mean the server's 6 pawns and 90 NPCs do not multiply object count.

### Negative — stated honestly
- **Fourteen small files instead of one large one.** For a reader trying to understand the
  whole machine at once, this is worse, not better. Mitigated by the centralised transition
  table and by the Mermaid diagram in
  [`../../10_gdd/02_player_controller.md`](../../10_gdd/02_player_controller.md) §3 being
  normative rather than illustrative.
- The `PawnContext` object risks becoming a god-object of loosely related fields. It must be
  reviewed for cohesion at every milestone; if it exceeds ~25 fields, split it.
- Stateless state objects mean any per-state timer must live in the context, which is
  slightly awkward (`ctx.state_timer`) and easy to forget to reset in `enter()`. A test
  asserts that every state's `enter()` resets `state_timer`.
- Virtual dispatch per tick per pawn. Irrelevant at six pawns; noted only so nobody
  "optimises" it later without a measurement.

### Neutral / follow-on
- NPCs use a *different*, simpler mechanism (ADR-0003's flat HFSM) deliberately. NPCs are
  numerous and simple; pawns are few and complex. Using one pattern for both would penalise
  whichever side it was not designed for. This asymmetry is intentional and should not be
  "unified" without an ADR.

## Compliance

- [ ] Exactly one class per state under `scripts/pawn/states/`, each extending `PawnState`.
- [ ] No state class declares a `var` holding per-pawn data.
- [ ] `PawnStateMachine.TRANSITIONS` declares every legal edge; `test_pawn_transitions.gd`
      asserts it matches the Mermaid diagram in GDD Part 2 §3, edge for edge.
- [ ] `step()` contains no call to `randf`, `randi`, `Time.*`, `get_node`, or any autoload
      other than `Tuning`. Checked by grep in CI.
- [ ] `test_pawn_prediction_determinism.gd` runs the same input sequence twice from the same
      context and asserts bit-identical results.
- [ ] Every state's `enter()` resets `ctx.state_timer`; asserted by `test_pawn_states.gd`.
- [ ] No file under `scripts/pawn/` exceeds 400 lines.

## Revisit trigger

Reopen if the number of pawn states exceeds ~20 (at which point a hierarchical grouping
becomes worthwhile), or if prediction reconciliation proves unstable for the traversal
states — the fallback there is making Vault/Mantle/Drop server-confirmed rather than
predicted, which is a change to ADR-0002, not to this one.
