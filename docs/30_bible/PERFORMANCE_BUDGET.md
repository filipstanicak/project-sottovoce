---
id: BIBLE-PERF-BUDGET
title: Performance Budget
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TUN-INDEX, TDD-08-CROWD, TDD-04-NET, ADR-0001, ADR-0007]
---

# Performance Budget

> **Context restated.** Project Sottovoce runs 60–90 animated NPCs plus up to 6 players at
> 1080p/60 on desktop, in GDScript, with a dedicated headless server. The crowd is not
> decoration — NPC positions determine blend validity, open-ground suspicion and line of sight —
> so **crowd count cannot be traded away for frame time** without trading away the game.
>
> **The headline:** the client frame budget balances at **15.5 ms of 16.6 ms**, and the crowd
> alone takes 2.0 ms of it with **0.10 ms of margin**. This is the tightest constraint in the
> project and the reason `RISK-CROWD-PERF` is tracked at medium probability.

---

## 1. The client frame budget

`TUN-PERF-FRAME-BUDGET` **16.6 ms** = 60 fps at 1080p on the reference machine.

| System | Budget | Tunable | Chapter |
|---|---|---|---|
| **Render** | 9.00 ms | `TUN-PERF-RENDER-BUDGET` | — |
| **Crowd** (animation + interpolation) | 2.00 ms | `TUN-PERF-CROWD-BUDGET` | [TDD-08](../20_tdd/08_crowd_system.md) §11.1 |
| **Gameplay** (mirrors, pawn, camera) | 2.00 ms | `TUN-PERF-GAMEPLAY-BUDGET` | [TDD-06](../20_tdd/06_player_pawn.md), [TDD-07](../20_tdd/07_suspicion_and_detection.md) |
| **Net** (deserialise, interpolate, reconcile) | 1.50 ms | `TUN-PERF-NET-BUDGET` | [TDD-04](../20_tdd/04_networking.md) §13 |
| **UI** | 1.00 ms | `TUN-PERF-UI-BUDGET` | [TDD-11](../20_tdd/11_ui_architecture.md) §10 |
| **Sub-total** | **15.50 ms** | | |
| **Margin** | **1.10 ms** | | 6.6 % |

### 1.1 Where the margin actually is

The 1.10 ms is not evenly distributed. Measured against the per-chapter allocations:

| Area | Allocated | Claimed by chapters | Slack |
|---|---|---|---|
| Crowd | 2.00 | 1.90 | **0.10** |
| Gameplay | 2.00 | 0.35 | 1.65 |
| Net (typical) | 1.50 | 0.90 | 0.60 |
| Net (reconciling) | 1.50 | 1.40 | 0.10 |
| UI | 1.00 | 0.85 | 0.15 |

**The crowd and a reconciliation storm are the two places with no room.** They are also the two
that spike together: packet loss causes reconciliation replay, and packet loss correlates with
network conditions that do not affect crowd cost — so the worst case is 1.90 + 1.40 = 3.30 ms of
a 3.50 ms combined allocation, with 0.20 ms spare.

---

## 2. The server tick budget

`TUN-PERF-SERVER-TICK-BUDGET` **8.0 ms** per 33 ms tick.

| System | Budget | Chapter |
|---|---|---|
| Snapshot build (6 clients: cull, delta, quantise) | 1.20 ms | [TDD-04](../20_tdd/04_networking.md) §13 |
| Crowd (hash, LOD, ~34 brain steps, steering, navigation) | 1.75 ms | [TDD-08](../20_tdd/08_crowd_system.md) §11.2 |
| Suspicion + detection (incl. nearest-NPC queries) | 0.61 ms | [TDD-07](../20_tdd/07_suspicion_and_detection.md) §8 |
| Pawn substeps (6 × 2) + probes | 0.55 ms | [TDD-06](../20_tdd/06_player_pawn.md) §9 |
| Scoring, kill/stun, contract | 0.23 ms | [TDD-10](../20_tdd/10_scoring_and_match_state.md) §11 |
| Abilities | 0.24 ms | [TDD-09](../20_tdd/09_ability_system.md) §11 |
| Input ingest + lag-comp record | 0.25 ms | |
| Orchestration | 0.05 ms | |
| **Total** | **4.88 ms of 8.0 ms** | |
| **Margin** | **3.12 ms** | **39 %** |

### 2.1 Why the server budget is deliberately generous

8.0 ms of a 33 ms tick is only 24 % utilisation. That is intentional:

> **A server that is *usually* on time produces intermittent, unreproducible feel bugs.**

A late tick delays every client's snapshot, which manifests as remote players stuttering and
kills failing — symptoms players report as "lag" and engineers investigate as netcode. The
generous headroom means the server is never the variable.

---

## 3. Memory budget

| Item | Budget | Notes |
|---|---|---|
| Persona meshes + textures (4 × ~8 000 tris, 1024²) | 180 MB | Shared between players and clones — **the clone rule pays for itself here** |
| Filler archetypes (5, shared atlas) | 60 MB | |
| Map geometry + textures | 220 MB | |
| Audio (all events + stems) | 90 MB | |
| Animation (~195 clips) | 40 MB | |
| Runtime (pools, buffers, snapshots) | 60 MB | |
| Engine + GDScript overhead | 150 MB | |
| **Total** | **~800 MB** | Target ≤ 1.5 GB |

### 3.1 Runtime allocations worth naming

| Item | Size | Note |
|---|---|---|
| `LagCompHistory` | ~23 KB | 15 ticks × 96 entities × 16 B |
| `ScoreEvent` log | ~24 KB/match | ~600 events × 40 B. **No pruning needed** |
| `speed_history` (per pawn) | 1.2 KB | 300 floats for `SCORE-PATIENT`'s 10 s window |
| Snapshot ring (per client) | ~40 KB | |
| NPC pool | pre-allocated | **Never instantiated mid-match** |

---

## 4. Bandwidth budget

| Direction | Budget | Measured (worst case) | Status |
|---|---|---|---|
| Down | 96 kbit/s | ~83.5 kbit/s | **87 % — fits, 13 % headroom** |
| Up | 16 kbit/s | ~18 kbit/s | **⚠ MISSES** |

### 4.1 The upstream miss

**The cause is packet overhead, not payload** — 28 bytes of UDP/ENet header carrying 9 bytes of
input, 60 times a second.

| Fix | Cost |
|---|---|
| Coalesce two input commands per packet | Halves packet rate to 30 Hz, preserves the 60 Hz sample rate. Adds up to **16 ms latency for the first command in each pair**, against an 80 ms feel budget |

`test_upstream_bandwidth.gd` is written to **fail until this is resolved**, deliberately, rather
than the budget being widened to match reality.

### 4.2 Downstream composition

| Component | Bytes/s | Share |
|---|---|---|
| Near NPCs (~45, 30 Hz, 55 % changed) | 5 197 | 50 % |
| Far NPCs (~30, 10 Hz, 70 % changed) | 1 470 | 14 % |
| Remote pawns (5) | 2 100 | 20 % |
| Own pawn + gameplay + compass + match | 540 | 5 % |
| Headers, reliable events | 290 | 3 % |
| ENet + UDP/IP overhead | 840 | 8 % |
| **Total** | **10 437** | **≈ 83.5 kbit/s** |

**NPCs are 64 % of downstream traffic.** That is the price of ADR-0007's decision to
server-replicate the crowd rather than derive it client-side, and it was accepted because a
divergent NPC position is a *gameplay* divergence — a player who believes they are blended and is
not.

---

## 5. Profiling procedure

### 5.1 The reference machine

Every budget in this document is against one machine. Pin it, record it, and change it only
deliberately.

| Component | Spec |
|---|---|
| CPU | 6-core desktop, ~2020 mid-range |
| GPU | Discrete, ~2020 mid-range |
| RAM | 16 GB |
| Storage | SSD |
| Display | 1920 × 1080 @ 60 Hz |
| OS | Windows 11 and Ubuntu 22.04 — **both**, because the server ships on Linux |

### 5.2 The standard profiling scenario

Reproducibility matters more than realism. Same scenario, every time.

```bash
godot --headless -- --server --port 27015 --seed 20260803
# then 3 clients:
godot -- --connect 127.0.0.1:27015
```

| Parameter | Value |
|---|---|
| Seed | **Fixed** — identical clone roster every run |
| Players | 6 (3 human, 3 scripted input replay) |
| Crowd | 90 — `TUN-CROWD-COUNT-MAX`, not the 6-player default |
| Location | Piazza del Vetro at peak density — the worst case |
| Duration | 60 s, discarding the first 10 |
| Network | Typical profile (90 ms RTT, 1 % loss) |

### 5.3 What to measure

| Metric | Tool | Threshold |
|---|---|---|
| Frame time **p50 / p95 / p99** | `show budget` console overlay | p99 ≤ 16.6 ms |
| Per-system frame time | Same overlay, per §1 | Each within its row |
| Server tick time p99 | Server log | ≤ 8.0 ms |
| Bytes/s per client | `test_crowd_bandwidth.gd` | ≤ 96 kbit/s down |
| Peak memory | OS monitor | ≤ 1.5 GB |
| Allocations per frame | Godot profiler | **0 in `NpcBrain.step()` and `PawnState.step()`** |

> **p99, not mean.** A game decided in 0.4 s contest windows is ruined by the 1 % of frames that
> hitch, and a mean frame time hides them completely.

### 5.4 When a budget is missed

1. **Measure before changing anything.** Confirm which row is over, on the reference machine, in
   the standard scenario.
2. Check the offending chapter's own fallback ladder first.
3. Only then consider cross-system reallocation — and record it here plus in `DECISION_LOG.md`.
4. **Never** reduce crowd count before exhausting the LOD ladder (§6).

---

## 6. The crowd fallback ladder

The one budget likely to be missed, so its response is pre-decided.

| # | Lever | Cost |
|---|---|---|
| 1 | Coarsen LOD bands (Mid 45 → 35 m) | Risks the silhouette-fairness constraint — LOD must never change silhouette or gait inside `TUN-COMPASS-RANGE-MAX` 60 m. **Measure before committing** |
| 2 | Reduce Mid-band animation fidelity | Must not change silhouette or gait |
| 3 | Drop Far-band animation entirely (impostors) | Beyond Compass range, so no gameplay information is lost. **The safest lever** |
| 4 | Move `Steering` to C# or GDExtension | ADR-0001's named response. Steering is the numeric inner loop; the FSM is not |
| 5 | Reduce `TUN-CROWD-COUNT-MAX` below 90 | **Last.** Never below `TUN-CROWD-COUNT-MIN` 60, a hard design floor |

> **Lever 5 appears first in most people's instincts and is listed last on purpose.** Crowd
> density is the game's substrate; cutting it trades the design's identity for frame time. If the
> ladder is exhausted and 60 NPCs still will not fit, that is an ADR-0001 revisit — the engine
> and language choice — not a design compromise.

---

## 7. Budget ownership

Each budget row has an owner who is notified when it is exceeded. **An unowned budget is a budget
nobody defends.**

| Budget | Owner | Test |
|---|---|---|
| Render | Art | Manual profiling |
| Crowd | Tech | `test_crowd_perf.gd` |
| Gameplay | Tech | `test_gameplay_perf.gd` |
| Net | Tech | `test_net_perf.gd`, `test_crowd_bandwidth.gd` |
| UI | UI | `test_ui_perf.gd` |
| Server tick | Tech | `test_server_tick_perf.gd` |
| Memory | Tech | Manual |
| Build time | Tech | `test_import_time.gd`, `test_suite_time.gd` |

---

## 8. Build-time budgets

Not runtime, but they decide whether the loop is used.

| Item | Budget | Why |
|---|---|---|
| Cold headless import | 90 s | Runs on every push; above ~2 min it stops being a fast gate |
| Unit + arch suites | 45 s | Must be runnable before every commit, or it will not be |
| Integration suite | 180 s | PR only |
| Full CI, cached | 6 min | **Above ~10 min people stop waiting and start merging optimistically** |

---

## 9. Acceptance criteria

- [ ] The reference machine is pinned and recorded.
- [ ] `show budget` reports per-system frame time matching §1's rows.
- [ ] p99 client frame time ≤ 16.6 ms in the standard scenario.
- [ ] p99 server tick ≤ 8.0 ms.
- [ ] `test_crowd_perf.gd` passes with 90 NPCs — **an M3 exit criterion**.
- [ ] Zero allocations in `NpcBrain.step()` and `PawnState.step()` after warm-up.
- [ ] Downstream bandwidth ≤ 96 kbit/s per client.
- [ ] Upstream miss tracked with a **failing** test until coalescing lands.
- [ ] Peak memory ≤ 1.5 GB.
- [ ] Every budget row has a named owner and an automated test where possible.
- [ ] Profiling runs on Windows **and** Linux.

---

## 10. Open questions

| # | Question | Position | Needed by |
|---|---|---|---|
| 1 | Crowd margin is 0.10 ms of 2.0. Is that survivable on real hardware? | Unknown until 90 NPCs exist. `test_crowd_perf.gd` is an M3 exit criterion and §6 is the response | M3 |
| 2 | Crowd worst-case and reconciliation worst-case leave 0.20 ms combined. Both spike under different conditions — do they ever spike together? | Packet loss drives reconciliation; crowd cost is loss-independent. They *can* coincide. Test explicitly at the Poor latency profile with peak density | M3 |
| 3 | Render is 9.0 ms — 54 % of the frame — and is the least-specified row. | Art has not started. Revisit when the first art pass exists; the number is a placeholder informed by nothing | M6 |
| 4 | Is one reference machine enough, given Windows and Linux both ship? | Profile on both from M2. If they diverge more than ~10 %, two budgets are needed | M2 |
| 5 | Godot 4.7.1's GDScript performance on 90 agents is the project's largest unvalidated assumption. | ADR-0001 accepted this risk explicitly with a fallback ladder. **First real measurement is M3** | M3 |
