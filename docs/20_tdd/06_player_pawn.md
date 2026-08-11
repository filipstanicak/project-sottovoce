---
id: TDD-06-PAWN
title: "TDD Chapter 6 — Player Pawn"
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-01-ARCHITECTURE, TDD-03-TICK, TDD-04-NET, GDD-02-PLAYER, ADR-0008]
---

# TDD Chapter 6 — Player Pawn

> **Context restated.** Project Sottovoce is a 4–6 player social-stealth game. The pawn moves on
> a speed ladder — blend-walk 1.4, stroll 2.2, jog 3.4, run 4.5, sprint 6.2 m/s — where anything
> above stroll accrues **suspicion**, and the decay cliff sits exactly at stroll. Traversal is
> *assisted, not simulated*: one contextual input resolves to vault, mantle, climb, drop or gap
> jump, with ~0.45 s of combined forgiveness, because the player's attention belongs on the
> crowd rather than on their own footwork. The pawn has fifteen states.
>
> **The hard constraint:** this code runs **identically on the server and in client
> prediction**. Any nondeterminism here is a prediction divergence, which surfaces as the game
> appearing to break its own rules, intermittently, only under load.
>
> **Implements:** `SYS-PAWN`, `SYS-TRAVERSAL`, `SYS-INPUT`.

---

## 1. Node composition

Three scenes, one shared script set. Composition over inheritance
([`../30_bible/SCENE_AND_NODE_CONVENTIONS.md`](../30_bible/SCENE_AND_NODE_CONVENTIONS.md)).

```
pawn_server.tscn                        SERVER — no visuals, no camera, no audio
└── PawnServer : CharacterBody3D
    ├── CollisionShape3D                capsule, r 0.35, h 1.8
    ├── PawnStateMachine                the 14 states (§2)
    ├── TraversalProbes                 3 forward + 1 down raycast (§4)
    └── PawnContext                     all mutable per-pawn data (RefCounted, not a node)

pawn_local.tscn                         CLIENT — the predicted local pawn
└── PawnLocal : CharacterBody3D
    ├── CollisionShape3D                IDENTICAL shape and layers to PawnServer
    ├── PawnStateMachine                THE SAME SCRIPT — prediction requires it
    ├── TraversalProbes                 THE SAME SCRIPT
    ├── PersonaVisuals                  mesh + AnimationTree
    ├── CameraMount : Node3D            CameraRig attaches here
    └── FootstepEmitter

pawn_remote.tscn                        CLIENT — interpolated only
└── PawnRemote : Node3D                 NOT a CharacterBody3D — it never simulates
    ├── PersonaVisuals                  mesh + AnimationTree
    ├── InterpolationTarget             consumes SnapshotInterpolator output
    └── FootstepEmitter
```

### 1.1 The three rules of this composition

| # | Rule | Why |
|---|---|---|
| 1 | **`PawnServer` and `PawnLocal` share `PawnStateMachine`, `TraversalProbes` and the collision shape verbatim.** | Reconciliation replays buffered inputs through the identical code path the server used. A divergence in shape, layer mask or step logic is a divergence in prediction |
| 2 | **`PawnRemote` is not a physics body and has no state machine.** | Remote pawns are interpolated 100 ms in the past (ADR-0002). Simulating them would produce a second, wrong, answer |
| 3 | **`PawnContext` is a `RefCounted`, not a node.** | It is passed by reference into `PawnState.step()`, which must be callable from a unit test with no scene tree |

### 1.2 Collision layers

| Layer | Contains | Probed by traversal? |
|---|---|---|
| 1 `WORLD` | Static map geometry, climbable façades, vaultable furniture | **Yes — and only this** |
| 2 `PAWN` | Player capsules | No |
| 3 `NPC` | Crowd capsules | No |
| 4 `TRIGGER` | Blend props, zone volumes, spawn markers | No (queried separately) |

**Traversal probes mask `WORLD` only.** This is a determinism requirement, not an optimisation:
static geometry is identical on every peer by construction, while NPC and player positions are
interpolated on clients and authoritative on the server. A probe that could hit a moving body
would resolve differently on the two machines and produce a different traversal
([`03_core_loop_and_tick.md`](03_core_loop_and_tick.md) §3.3).

---

## 2. The state machine

### 2.1 Pattern: state objects, not `enum` + `match`

Per ADR-0008. Fifteen states, each with its own movement integration, camera FOV target,
suspicion contribution, animation and legal transitions. An `enum`-and-`match` implementation
would be ~700 lines in one file with one 400-line function — a direct violation of the 400-line
file and 40-line function limits, and the classic shape of an unmaintainable controller.

```gdscript
## Base class for every pawn state. STATELESS with respect to the pawn:
## all mutable data lives in PawnContext, so ONE instance of each state is
## shared across every pawn on the server. Fifteen objects total, not
## fifteen per player.
class_name PawnState
extends RefCounted

enum { PRIORITY_NORMAL = 0, PRIORITY_COMBAT = 10, PRIORITY_FATAL = 20 }

## Called once on entry. MUST reset ctx.state_timer_ticks.
## Never assume it is paired with a matching exit().
func enter(ctx: PawnContext) -> void:
    ctx.state_timer_ticks = 0

func exit(ctx: PawnContext) -> void:
    pass

## The deterministic step. Returns the StringName of the requested next state,
## or &"" to remain.
##
## MUST be a pure function of (ctx, input, delta).
## MUST NOT call: randf, randi, Time.*, get_node, get_tree, or any autoload
## except Tuning. Enforced by test_pawn_determinism_grep.gd.
func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
    return &""

## Suspicion generated per second in this state. Read from Tuning, never a literal.
func suspicion_rate(ctx: PawnContext) -> float:
    return 0.0

func camera_fov(ctx: PawnContext) -> float:
    return Tuning.camera.fov_stroll

func interrupt_priority() -> int:
    return PRIORITY_NORMAL

## Whether a lower-priority transition may interrupt right now.
func is_interruptible(ctx: PawnContext) -> bool:
    return true
```

### 2.2 The transition table is centralised

The state-object pattern's real weakness is that the transition graph exists only in the
reader's head. That is fixed by declaring it in one place:

```gdscript
class_name PawnStateMachine
extends Node

## Legal edges. THE authority on the graph, asserted against the Mermaid diagram
## in GDD-02 §3 by test_pawn_transitions.gd, edge for edge.
const TRANSITIONS: Dictionary = {
    &"Idle":       [&"BlendWalk", &"Stroll", &"Blended", &"KillAnim", &"StunAnim",
                    &"Stunned", &"Dead", &"Vault", &"Climb", &"Drop"],
    &"BlendWalk":  [&"Idle", &"Stroll", &"Blended", &"KillAnim", &"StunAnim",
                    &"Stunned", &"Dead", &"Vault", &"Climb", &"Drop"],
    # ... all fifteen
    &"KillAnim":   [&"Idle", &"Stunned", &"Dead"],
    &"Stunned":    [&"Idle", &"Dead"],
    &"Dead":       [&"Respawning"],
    &"Respawning": [&"Idle"],
}

## step() REQUESTS a transition; the machine VALIDATES it.
## An illegal request asserts in debug and push_errors + is ignored in release.
##
## A state's OWN exit is not an interruption and is not gated on
## is_interruptible() — US-0019: gating it made every uninterruptible state
## permanent, and both Vault and KillAnim are uninterruptible by design.
func _request(ctx: PawnContext, to: StringName, priority: int) -> bool:
    if to.is_empty():
        return false
    var from := ctx.state_id
    if not TRANSITIONS[from].has(to):
        assert(false, "Illegal transition %s -> %s (TDD-06 §2.2)" % [from, to])
        push_error("Illegal transition %s -> %s" % [from, to])
        return false
    if not _states[from].is_interruptible(ctx) and priority <= _states[from].interrupt_priority():
        return false
    _states[from].exit(ctx)
    ctx.state_id = to
    _states[to].enter(ctx)
    return true
```

### 2.3 The three interrupt rules

| # | Rule | Implementation |
|---|---|---|
| 1 | **A kill can be stopped, but only before it lands.** | `KillAnim.is_interruptible()` returns `ctx.state_timer_ticks < Tuning.ticks(&"TUN-KILL-CORPSE-SPAWN-DELAY")` (27 ticks of 42). After the contact frame the victim is dead and the remainder is follow-through |
| 2 | **Nothing interrupts `Stunned`.** | `is_interruptible()` returns `false`; `interrupt_priority()` is `PRIORITY_COMBAT`, so only `PRIORITY_FATAL` (death) passes |
| 3 | **`Blended` yields to everything.** | `is_interruptible()` returns `true`. Blend protects anonymity, never the body |

### 2.4 A representative state

```gdscript
## Sprint. The most expensive state in the game: Noticed in 1.2 s, Exposed in 2.8 s.
class_name StateSprint
extends PawnState

func step(ctx: PawnContext, input: InputCommand, delta: float) -> StringName:
    # Slowing down is NEVER gated. Checked first, every frame, from every state.
    if input.buttons & InputBits.SLOW:
        return &"BlendWalk"
    if not (input.buttons & InputBits.SPRINT):
        return &"Run"
    if input.move.length_squared() < 0.01:
        return &"Idle"

    Locomotion.accelerate_toward(ctx, input, Tuning.movement.sprint, delta)

    if input.buttons & InputBits.TRAVERSE:
        var resolved := TraversalResolver.resolve(ctx)
        if not resolved.is_empty():
            return resolved
    return &""

func suspicion_rate(_ctx: PawnContext) -> float:
    return Tuning.suspicion.gain_sprint          ## 25.0/s

func camera_fov(_ctx: PawnContext) -> float:
    return Tuning.camera.fov_sprint              ## 72 deg
```

**`Locomotion` and `TraversalResolver` are static Core helpers**, shared by every state. This is
what keeps each state file at 30–80 lines: the states express *policy* (which speed, which
transitions), the helpers express *mechanism* (how acceleration integrates).

### 2.5 `PawnContext`

```gdscript
## All mutable per-pawn data. Passed by reference into PawnState.step().
## RefCounted, not a Node, so states are unit-testable with no scene tree.
##
## GOD-OBJECT WATCH: currently 17 fields. TDD-01 open question 2 sets the
## ceiling at ~25, after which this splits into PawnMotion + PawnCombat.
class_name PawnContext
extends RefCounted

# --- Identity ---
var peer_id: int
var persona: StringName

# --- Motion (predicted) ---
var position: Vector3
var velocity: Vector3
var yaw: float
var grounded: bool

# --- State machine (predicted) ---
var state_id: StringName
var state_timer_ticks: int

# --- Traversal (predicted) ---
var probe_result: ProbeResult
var traverse_buffer_ticks: int
var ledge_magnet_ticks: int

# --- Gameplay (SERVER-AUTHORITATIVE — mirrored on the client, NEVER predicted) ---
var suspicion: float
var tier: int
var blend_state: int
var stun_lockout_until_tick: int

# --- Body ---
var body: CharacterBody3D                        ## null in unit tests; states must tolerate it
```

**The `body` field being nullable is deliberate.** It lets `step()` run in a pure unit test with
no physics, exercising every transition and every suspicion rate. Only `Locomotion` touches
`body`, and only when it is non-null.

---

## 3. Input buffering

Two independent buffers, for different reasons.

| Buffer | Size | Purpose | Lives on |
|---|---|---|---|
| **Reconciliation buffer** | `TUN-NET-INPUT-BUFFER-SIZE` 32 commands (~530 ms) | Replay unacked inputs after a server correction | Client only |
| **Action buffer** | `TUN-TRAVERSE-INPUT-BUFFER` 0.20 s / `TUN-ABILITY-INPUT-BUFFER` 0.20 s | Forgive an input pressed slightly *early* | Both — it is part of `step()` |

The action buffer must be inside `PawnContext` and inside `step()`, because it changes the
simulation result. A client-only action buffer would mean the client predicting a vault the
server never performed.

```gdscript
## Called every step, from PawnStateMachine.step(), BEFORE the state runs — so a
## press and its consumption can land on the same tick. Implemented as
## PawnInputBuffer (US-0016).
##
## Tuning.STEP_ticks, not Tuning.ticks. This counter advances once per step(),
## which runs at 60 Hz; the 30 Hz conversion would forgive 0.10 s while every
## document says 0.20. See TDD-03 §1.1 — the two tick domains.
static func tick(ctx: PawnContext, input: InputCommand) -> void:
    if input.traverse:
        ctx.traverse_buffer_ticks = Tuning.step_ticks(&"TUN-TRAVERSE-INPUT-BUFFER")  # 12 ticks
    elif ctx.traverse_buffer_ticks > 0:
        ctx.traverse_buffer_ticks -= 1

## CONSUMING: a buffered input must fire exactly once, or it re-triggers on the
## next legal frame and vaults the player somewhere they did not ask for.
static func consume_traverse(ctx: PawnContext) -> bool:
    if ctx.traverse_buffer_ticks > 0:
        ctx.traverse_buffer_ticks = 0
        return true
    return false
```

The ability buffer is the same shape against `TUN-ABILITY-INPUT-BUFFER` and a separate counter.
Sharing one would let a traverse eat an ability the player also pressed.

---

## 4. Traversal probes

### 4.1 Probe layout

Three forward rays plus one down ray. All mask `WORLD` only (§1.2).

```
                     origin heights (m)          length
  CHEST  ●─────────────────────▶  1.35           0.90    TUN-TRAVERSE-PROBE-LENGTH
  WAIST  ●─────────────────────▶  0.85           0.90
  FOOT   ●─────────────────────▶  0.25           0.90
                │
  GAP           ▼ from 0.6 m ahead, down 5.0 m           distinguishes gap from drop
```

**Heights are measured from the pawn's FEET**, and the body origin is the feet: both pawn scenes
raise the capsule by half its height so it sits on the origin rather than straddling it.
`MapData.spawn_points` is measured the same way. US-0017 found the two disagreeing — the pawn had
been falling through the map since US-0016, and the probes were the first thing to notice,
because they reported no floor under a pawn standing in the middle of the district.

Three more down-casts are needed beyond the four drawn, and each answers a question §7.2 asks:

| Cast | From | Answers |
|---|---|---|
| Obstacle top | `TUN-TRAVERSE-MANTLE-MAX-HEIGHT` above the feet, one step past the hit | `obstacle_top` — **the vault/mantle decision** |
| Clear beyond | the same height, two steps past | `clear_beyond` — is there anywhere to land |
| Climb top | `TUN-TRAVERSE-CLIMB-MAX-HEIGHT` above the feet | `surface_height` — how tall the façade is |

The climb cast starts higher on purpose. A cast that begins *inside* geometry is not reported by
Godot at all: the ray passes through and hits whatever is beyond. Casting from mantle height at a
4 m façade therefore measured the floor behind it and returned an obstacle top of **0.0** — which
satisfies `<= TUN-TRAVERSE-VAULT-MAX-HEIGHT`, and would have made every façade in Vetraio a vault
into a wall. `TraversalProbes` rejects any "top" at or below foot height for the same reason.

The gap probe **marches**, at `TUN-TRAVERSE-GAP-PROBE-STEP`, from
`TUN-TRAVERSE-GAP-PROBE-AHEAD` out to `TUN-TRAVERSE-GAP-MAX`. A single cast at 0.6 m can only
report "no ground right here", which distinguishes nothing: every gap and every drop look
identical at 0.6 m. Ground found further out than a safe drop below is not a far side either —
it is what you fall to, not what you jump to.

### 4.2 Resolution, in pseudocode

Normative. The **first match wins**, and the order is the order in
[`../10_gdd/02_player_controller.md`](../10_gdd/02_player_controller.md) §7.2.

```
static func resolve(ctx: PawnContext) -> StringName:
    if not Locomotion.consume_traverse(ctx):
        return ""

    p = ctx.probe_result                      # refreshed once per physics frame

    # 1. LEDGE GRAB — forgiveness goes first, always.
    #    Catching a ledge you are falling past must beat everything else.
    if not ctx.grounded and p.ledge_within(TUN-TRAVERSE-MAGNET-RADIUS 0.6):
        if ctx.ledge_magnet_ticks > 0:        # TUN-TRAVERSE-MAGNET-WINDOW 0.25 s = 8 ticks
            return "Climb"                    # enters at the grabbed ledge

    # 2. GAP JUMP — ground exists across a crossable gap.
    if p.foot_clear and not p.ground_ahead:
        if p.gap_distance <= TUN-TRAVERSE-GAP-MAX 3.2:
            return "Drop"                     # Drop state handles the ballistic arc
        # else fall through to 3

    # 3. DROP — no landing within range.
    if p.foot_clear and not p.ground_ahead:
        return "Drop"

    # 4. VAULT — waist-height obstacle with clear space beyond.
    #    BEFORE mantle: a low wall you can go OVER must not become one you climb ONTO.
    if p.waist_hit and p.obstacle_top <= TUN-TRAVERSE-VAULT-MAX-HEIGHT 1.1:
        if p.clear_beyond:
            return "Vault"

    # 5. MANTLE — reachable ledge.
    if p.waist_hit and p.obstacle_top <= TUN-TRAVERSE-MANTLE-MAX-HEIGHT 2.3:
        return "Vault"                        # Vault state branches on height internally

    # 6. CLIMB — climbable façade within one stratum.
    #    LAST, because climbing is the most expensive option and must never be
    #    selected when a cheaper one applies.
    if p.chest_hit and p.surface_is_climbable:
        if p.surface_height <= TUN-TRAVERSE-CLIMB-MAX-HEIGHT 9.0:
            return "Climb"

    # 7. NO MATCH — input consumed, no animation, SILENCE.
    #    A failed traverse must never look like a bug, and must never flail.
    return ""
```

### 4.2.1 Seven cases, four states

`resolve()` returns a state id, and two pairs collapse into one: gap jump and drop both enter
`Drop`, vault and mantle both enter `Vault`. That makes the ordering above **untestable from the
return value alone** — a test that saw only the state could not tell case 2 from case 3.

`TraversalResolver` therefore exposes `classify() -> Case` beside `resolve() -> StringName`. The
design specifies an ordering, so the code exposes one. `classify()` is side-effect free, so a
tell or an animation anticipation can ask what a traverse *would* do without consuming the
player's press; only `resolve()` spends it.

### 4.3 Forgiveness

| Window | Tunable | Ticks | Forgives |
|---|---|---|---|
| Early press | `TUN-TRAVERSE-INPUT-BUFFER` 0.20 s | **12** | Pressing before the obstacle is in probe range |
| Late press | `TUN-TRAVERSE-MAGNET-WINDOW` 0.25 s | **15** | Pressing after you have passed the ledge |
| Lateral | `TUN-TRAVERSE-MAGNET-RADIUS` 0.6 m | — | Not being aligned with the ledge |
| Gap facing | `TUN-TRAVERSE-GAP-ALIGN-ARC` ±20° | — | Not facing exactly across the gap |

**Combined ~0.45 s.** Enormous by action-game standards, and correct: a missed ledge must be a
*decision* error, never a *timing* error.

> The tick counts are `Tuning.step_ticks()` at 60 Hz, not `Tuning.ticks()` at the 30 Hz net
> tick — these counters advance once per `step()`. This table said 6 and 8 until US-0017;
> those were the 30 Hz figures, which is the same mistake §1.1 of
> [`03_core_loop_and_tick.md`](03_core_loop_and_tick.md) records four merged call sites making.

### 4.4 The level-design contract

Traversal resolution assumes geometry is never built in a boundary band
([`../10_gdd/05_level_design.md`](../10_gdd/05_level_design.md) §4.1). `test_map_metrics.gd`
scans committed map geometry and fails the build on any traversable surface inside one, because
geometry at 1.10 m would resolve as vault or mantle depending on sub-centimetre position — which
reads to a player as the game being broken.

---

## 5. Locomotion

```gdscript
## Shared acceleration integration. Static, pure, Core.
## Deceleration is FASTER than acceleration (24 vs 18 m/s^2) so that
## "stop and blend" is always instantly available. The asymmetry is the
## design thesis written into the acceleration curve.
static func accelerate_toward(ctx: PawnContext, input: InputCommand,
                              target_speed: float, delta: float) -> void:
    var wish := Vector3(input.move.x, 0.0, input.move.y).rotated(Vector3.UP, ctx.yaw)
    var desired := wish.normalized() * target_speed * minf(wish.length(), 1.0)

    # Backpedal is slower: retreating from a hunter is possible but not the answer.
    if wish.dot(Vector3.FORWARD.rotated(Vector3.UP, ctx.yaw)) < 0.0:
        desired *= Tuning.movement.backpedal_mult          # 0.55

    var rate := Tuning.movement.accel if desired.length() > ctx.velocity.length() \
                else Tuning.movement.decel                 # 18.0 / 24.0
    ctx.velocity = ctx.velocity.move_toward(desired, rate * delta)
```

---

## 6. Interfaces

```gdscript
## Advances one pawn by one substep. Called at 60 Hz on both peers.
func PawnStateMachine.step(ctx: PawnContext, input: InputCommand, delta: float) -> void

## Refreshed once per physics frame, before step(). Masks WORLD only.
func TraversalProbes.refresh(ctx: PawnContext) -> ProbeResult

## First-match-wins resolution (§4.2). Pure given a ProbeResult.
static func TraversalResolver.resolve(ctx: PawnContext) -> StringName

## Snapshot the predictable subset for the reconciliation buffer.
func PawnContext.capture_predicted() -> PredictedState

## Overwrite the predictable subset from an authoritative snapshot.
## Does NOT touch server-authoritative gameplay fields (suspicion, tier, blend).
func PawnContext.apply_authoritative(state: PredictedState) -> void
```

---

## 7. Files this chapter creates

| Path | Purpose |
|---|---|
| `scenes/pawn/pawn_server.tscn` · `pawn_local.tscn` · `pawn_remote.tscn` | The three compositions |
| `scripts/pawn/pawn_state_machine.gd` | Machine + `TRANSITIONS` |
| `scripts/pawn/pawn_state.gd` | Base class |
| `scripts/pawn/pawn_context.gd` | `PawnContext` |
| `scripts/pawn/states/*_state.gd` | **15 eventually** — one per state; `vault_state.gd` covers vault and mantle both. **Ten exist**, plus `locomotion_state.gd`, which is a shared base and not a state |
| `scripts/pawn/traversal/traversal_probes.gd` | Probe casting |
| `scripts/pawn/traversal/traversal_resolver.gd` | §4.2 resolution, the magnet window and auto-align |
| `scripts/pawn/probe_result.gd` | `ProbeResult` |
| `scripts/pawn/traversal/probe_layout.gd` | Pure probe geometry — where the casts go |
| `scripts/core/collision_layers.gd` | The four layer masks, mirrored from `[layer_names]` |
| `scripts/core/math/locomotion.gd` | Shared acceleration |
| `scripts/pawn/pawn_input_buffer.gd` | The action buffer (§3), inside `step()` |
| `scripts/net/protocol/input_bits.gd` | Button bitfield constants |
| `scripts/net/protocol/input_actions.gd` | The action table: `INPUT-` ID → bit, kind, bindings |
| `scripts/net/client/input_history.gd` | The reconciliation buffer (§3), client only |
| `scripts/presentation/input_sampler.gd` | The only file that touches `Input`. **No loop of its own** — `sample()` is called, never self-driven |
| `scripts/presentation/input_rebinder.gd` | The only file that writes `InputMap` |
| `scripts/presentation/local_pawn_driver.gd` | Drives `step()` at 60 Hz from sampled input. **The only caller of `sample()`**, and the owner of `command_sampled` |

---

## 8. Test hooks

| Test | Asserts |
|---|---|
| `test_pawn_transitions.gd` | `TRANSITIONS` matches the GDD-02 §3 Mermaid diagram edge for edge |
| `test_pawn_states_exist.gd` | Exactly 14 `PawnState` subclasses; each is referenced by `TRANSITIONS` |
| `test_pawn_state_enter_resets_timer.gd` | Every state's `enter()` sets `state_timer_ticks = 0` |
| `test_pawn_states_stateless.gd` | No `PawnState` subclass declares a `var` holding per-pawn data |
| `test_pawn_determinism.gd` | The same command sequence from the same context produces bit-identical results twice |
| `test_pawn_determinism_grep.gd` | No file under `scripts/pawn/` contains `randf`, `randi`, `Time.`, `get_node`, `get_tree`, or an autoload other than `Tuning` |
| `test_slow_always_available.gd` | `→ BlendWalk` succeeds within one tick from **every** locomotion state at **every** speed |
| `test_kill_interrupt_window.gd` | `KillAnim` is stun-interruptible before tick 27 and not after |
| `test_stunned_uninterruptible.gd` | `Stunned` rejects everything below `PRIORITY_FATAL` for its full 120 ticks |
| `test_blended_yields.gd` | A blended pawn can be killed and stunned normally |
| `test_traversal_resolution.gd` | All seven §4.2 cases in priority order, **including case 7's silence** |
| `test_traversal_forgiveness.gd` | A traverse 0.20 s early or 0.25 s late still resolves |
| `test_vault_state.gd` | Durations, costs, interrupt rules, and a trajectory that goes OVER the wall |
| `test_state_may_end_itself.gd` | An uninterruptible state can still complete — Vault and KillAnim both |
| `test_climb_state.gd` | A climb is priced per METRE: 9 m is 3.2 s and +38.6, a third of that for 3 m |
| `test_drop_state.gd` | The stratum arithmetic — balcony→street clean, roof→balcony staggers |
| `test_roof_toll.gd` | Every locomotion state pays `TUN-SUSPICION-GAIN-ROOF` above the stratum, and none recovers |
| `test_traversal_case_states.gd` | Every case names a state the graph can enter from locomotion |
| `test_traversal_resolution_geometry.gd` | The seven cases resolve from **real** geometry, not a hand-filled struct |
| `test_traversal_assists_geometry.gd` | The gap fan and the ledge probes fire against real bodies |
| `test_pawn_input_buffer.gd` | The action buffer arms, decays, expires and is consumed exactly once — at the **step** rate |
| `test_step_counters_use_step_ticks.gd` | Nothing under `scripts/pawn/` compares a 60 Hz counter against the 30 Hz conversion |
| `test_client_boot_walks.gd` | **A key press moves the pawn**, through the real scene and the real bindings |
| `test_input_sampled_once.gd` | One command per physics frame, and `TUN-SPEED-SPRINT-HOLD` opens on the tick it specifies — it read **13 of 24** while input was sampled twice |
| `test_input_sampled_by_one_caller.gd` | `sample()` has exactly one caller and `InputSampler` declares no `_physics_process` |
| `test_probes_mask_world_only.gd` | Probe masks exclude `PAWN` and `NPC` layers |
| `test_probe_layout.gd` | Origins, reach, facing and the gap march are the tunables |
| `test_probe_result.gd` | A cleared result reads as *unknown*, never as a vaultable kerb |
| `test_traversal_probes_geometry.gd` | The casts see real bodies at 0.9 m, 1.8 m, 4 m and across a 2 m gap |
| `test_pawn_context_size.gd` | `PawnContext` has ≤ 25 fields (TDD-01 open question 2) |
| `test_pawn_no_literals.gd` | No bare numeric literal under `scripts/pawn/` except 0, 1, −1 |
| `test_pawn_file_lengths.gd` | No file under `scripts/pawn/` exceeds 400 lines; no function exceeds 40 |
| `test_local_server_pawn_parity.gd` | `pawn_local.tscn` and `pawn_server.tscn` have identical collision shape, layers and state-machine script |

`test_local_server_pawn_parity.gd` is the chapter's highest-value test: it catches the failure
where someone tweaks the local pawn's capsule for camera reasons and silently breaks prediction
for everyone.

---

## 9. Performance budget contribution

| Item | Budget | Notes |
|---|---|---|
| **Client** (against `TUN-PERF-FRAME-BUDGET` 16.6 ms) | | |
| Local pawn `step()` (1 per physics frame) | ≤ 0.10 ms | |
| Traversal probes (4 raycasts, 60 Hz) | ≤ 0.08 ms | Static geometry only, so no broadphase churn |
| `move_and_slide` | ≤ 0.12 ms | |
| Reconciliation replay (worst, 32 commands) | ≤ 0.60 ms | Counted in `TUN-PERF-NET-BUDGET` |
| **Client total (typical)** | **≤ 0.30 ms** | |
| **Server** (against `TUN-PERF-SERVER-TICK-BUDGET` 8.0 ms, per 33 ms tick) | | |
| 6 pawns × 2 substeps | ≤ 0.30 ms | |
| 6 pawns × 4 probes × 2 substeps | ≤ 0.25 ms | |
| **Server total** | **≤ 0.55 ms** | |

---

## 10. Open questions

| # | Question | Position | Needed by |
|---|---|---|---|
| 1 | Probes refresh once per **physics frame** but `step()` runs twice per net tick on the server. The second substep uses first-substep probe data — up to 16 ms stale. | Accept. At sprint that is 10 cm, well inside the 0.6 m magnet radius, and refreshing per substep would double probe cost for no perceptible gain. Revisit only if traversal feels unreliable at speed | M1 |
| 2 | Should `Vault` and `Mantle` be separate states? They currently share `StateVault`, branching on height internally. | Keep merged while the branch stays under 10 lines. If mantle acquires distinct camera or interrupt behaviour, split it | M1 |
| 3 | `PawnContext` holds server-authoritative fields (`suspicion`, `tier`, `blend_state`) that are never predicted. Should those live in a separate mirrored object so it is structurally impossible to predict them? | **Probably yes**, and this is the cleanest available guard against ADR-0002 rule 5 eroding. Deferred to the M4 review, when the field count is also reassessed | M4 |
| 4 | Gap jump currently routes into `Drop`, which handles the ballistic arc. Is that legible enough, or does a jump need its own state for animation reasons? | Merged for now. Animation can branch on `ctx.velocity.y > 0` at entry without a new state | M1 |
