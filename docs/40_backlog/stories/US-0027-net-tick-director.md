---
id: US-0027
title: MatchDirector and the net tick
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-14
depends_on: [TDD-03-TICK, TDD-01-ARCHITECTURE]
---

# US-0027 — MatchDirector and the net tick

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-TRANSPORT` |
| **Systems** | — |
| **Estimate** | M |
| **Depends on** | US-0026 |

## Description

The 30 Hz net tick derived from the 60 Hz physics clock, and explicit system tick ordering.

Ordering is declared in one file rather than left to scene-tree order, because scene-tree order
is an invisible dependency that breaks when somebody drags a node.

## Derived, not timed

The tick is **a count of physics frames divided by two**. A director that accumulated `delta` and
fired when it passed 33.3 ms would drift, would fire twice in a frame after a hitch, and would
produce a different tick count on two machines running the same match. Counting is exact,
reproducible, and identical on the server and in a client's replay — 10 000 frames are 5 000
ticks, with no drift to measure.

`ctx.elapsed()` is derived from the tick for the same reason. A clock read from `Time` drifts
from the tick count under load, and then *how long is left* has two answers: one the players see
and one the scoring uses.

**The physics rate is part of the contract.** The net tick is a division of it, so an engine
running physics at 30 or 120 silently halves or doubles the server's rate — every `TUN-` duration
in seconds still converts correctly and every one in ticks does not. `project.godot` pins it,
`test_project_settings_pinned.gd` guards the pin, and the director logs an error if the two ever
disagree at runtime.

## The pawn substep is the one thing that is not 30 Hz

And it is not an optimisation. Prediction replays buffered inputs through the same state machine
the server used; a server integrating **once** at `dt = 1/30` while the client predicted **twice**
at `dt = 1/60` diverges on every acceleration curve, and at `TUN-SPEED-ACCEL` 18 m/s² that
divergence is immediate and permanent. The server steps once per received `InputCommand`, at the
input rate, exactly as the client did.

**The queue is capped and drops the oldest.** A client that stalls for two seconds and then dumps
its backlog must not buy a hundred substeps of catch-up in one tick — that is a hitch for
everyone else and a speed advantage for the player who lagged. The cap is
`TUN-NET-INPUT-BUFFER-SIZE`, the same 32 commands the client's own reconciliation ring holds:
beyond it the oldest input cannot be reconciled anyway.

## Signals, not calls — again

`RpcRouter` does not know `MatchDirector` exists, and the director does not know the router does.
`server_root.gd` joins them, and it is the only place that knows the topology. Adding a system
means adding a visible line there rather than discovering at runtime that nobody ticked it.

Same reasoning as US-0026: a file that must be edited every time something is added is a file
where each edit is a chance to get the order wrong.

## Decisions taken here

### `game_system.gd` and `match_context.gd` are not in Core

TDD-01 §6's file table puts them in `scripts/core/`. **`GameSystem extends Node` and Core is pure
by law** — `test_core_is_pure.gd` refuses it, and CLAUDE.md's folder map states it. `MatchContext`
holds live pawns, which is server state rather than a value type. Both live in
`scripts/systems/`; TDD-01's own §1.3 draws the line where the guard does. `MatchPhase` and
`SystemOrder` *are* pure and stay in Core, which is what lets the order be compared against the
document by a guard.

### Three stages are positions, not systems

`ingest`, `pawn` and `snapshot` occupy places in the order because *when* they happen matters,
but nothing may register a `GameSystem` under them — the router drains into the queues as
messages arrive, the pawn substep is not a system, and US-0030 builds the snapshot. Registering
under one would run it in the right place by accident and hide the fact that nothing owns it.

### The clock advances outside play; nothing else does

`ctx.tick` increments in the lobby too. A monotonic tick that stopped there would restart every
match at a different number, and every duration measured in ticks would mean something different
depending on how long the lobby sat. Systems and substeps do not run —
`MatchPhase.is_simulating()` gates them, and **warmup counts as simulating while `is_playing()`
does not**, which is the same distinction `Authority` draws for input.

## Acceptance criteria

- [x] Net tick fires every second physics frame — exactly 30 per 60, no drift over 10 000 frames.
      Asserted by counting 5 000 ticks out of 10 000 frames, because an accumulator passes a
      one-second test and fails this one: float error is invisible until it has been added up
      five thousand times.
- [x] Pawn integration substeps at 60 Hz, once per received `InputCommand`. Asserted on the `dt`
      itself, not only on the count — a single step of twice the length lands somewhere else on
      any curve that is not linear.
- [x] All other systems tick once per net tick at `dt = 1/30`.
- [x] System order is an explicit array, matching TDD-01 §4. **Parsed from the diagram**, so the
      document is the authority and the code is what must follow.
- [x] `MatchContext.tick` is monotonic from match start.
- [x] Nothing gameplay-relevant runs in `_process`. — a source scan over
      `scripts/systems`, `scripts/net` and `scripts/server`.

## What the new guard found on its first run

**`Net._process`**, written four hours earlier in US-0025 — the once-a-second ping heartbeat.
Harmless-looking, and wrong for the guard's own reason: a heartbeat driven by rendered frames
samples RTT 144 times a second on one machine and 12 during a hitch, feeding a smoothing filter
whose effective window is therefore different on every machine. Moved to `_physics_process`.

The rule against *self-ticking* was also too broad as first written — it would have banned the
transport's heartbeat along with it. It is about `GameSystem`s, which is what it always meant:
a system that ticks itself runs at the physics rate and in scene-tree order, and both failures
are silent.

## Test notes

| Test | Asserts |
|---|---|
| `test_match_director.gd` | 30 per 60; **no drift over 10 000 frames**; the tick is monotonic and advances outside play; substeps run at the input rate and once per command; the queue drops the oldest |
| `test_system_tick_order.gd` | Systems registered **backwards** tick in the declared order; once per net tick; no stage, a non-system stage and a duplicated stage are all refused |
| `test_system_order_matches_the_diagram.gd` | The declared order is TDD-01 §4's, parsed from the mermaid source |
| `test_no_gameplay_in_process.gd` | Nothing server-side declares `_process`; no system ticks itself |

Both guards were falsified against planted violations: swapping crowd and suspicion in
`SystemOrder`, and a `GameSystem` with its own `_physics_process`. Both caught.

## Notes

Pawn substepping at 60 Hz is forced by prediction: a server integrating once at dt=1/30 while the
client predicts twice at dt=1/60 diverges on every acceleration curve, and at 18 m/s² that
divergence is immediate and permanent.
