---
id: US-0048
title: M3 gate — crowd performance and anonymity
version: 0.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-16
depends_on: [BACKLOG-ROADMAP, BIBLE-PERF-BUDGET, BIBLE-RISK-REGISTER]
---

# US-0048 — M3 gate: crowd performance and anonymity

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-ANONYMITY` |
| **Systems** | `SYS-CROWD`, `SYS-NPC-AI` |
| **Estimate** | S |
| **Depends on** | US-0047 |

## Description

Run and log the M3 exit verification. The hardest gate in the project.

## Acceptance criteria

> **THE GATE IS NOT RUN. ONE OF ITS INSTRUMENTS IS BUILT.** `test_crowd_perf.gd` was written
> ahead of US-0045 on purpose: LOD exists to buy frame time, and optimising against a budget
> nobody has measured is how the upstream bandwidth miss reached 253 % while a document said
> 112 %. Everything else below still waits for US-0045, US-0046 and US-0047.

- [x] **`test_crowd_perf.gd` passes with 90 NPCs**, in the standard scenario — ninety allocated,
      `TUN-CROWD-COUNT-DEFAULT-6P` active, on the real map with the real navmesh. **It passes on
      the frame deadline and misses TDD-08 §11.2's table**, which is amended with the measured
      figures rather than reworded. See below.
- [ ] p99 client frame time at or under 16.6 ms with peak crowd density.
- [ ] Server tick p99 at or under 8.0 ms.
- [ ] `test_crowd_bandwidth.gd` within 96 kbit/s down.
- [ ] `test_clone_animation_parity.gd` and `test_footstep_parity.gd` pass for all four personas.
- [ ] `test_clone_local_min.gd` passes over a clustered 3-minute match.
- [ ] Startle waves read directionally to a human observer.
- [ ] Feel check: the crowd feels alive — a tester still looks at NPCs unprompted after minute 4.
- [ ] Risk register re-scored: RISK-CROWD-PERF, RISK-ANONYMITY-LEAK, RISK-ANIM-SCOPE.
- [ ] Tag `m3-crowd` pushed.

## What the first measurement of the project's largest assumption says

ADR-0001 accepted GDScript-across-ninety-agents as a risk and gave it a fallback ladder. This is
the first time it has been measured.

| | Budget (§11.2) | Measured, 78 NPCs, no LOD |
|---|---|---|
| Spatial hash rebuild | ≤ 0.15 ms | **0.054 ms** |
| `NpcBrain.step()` × all 78 | ≤ 0.50 ms for ~34 | **0.046 ms** |
| Everything inside `CrowdDirector.tick()` | — | **mean 0.54, p95 0.81, max 1.12 ms** |
| Crowd movement, per **physics** frame | ≤ 0.60 ms for ~34 | **5.69 ms** (2.97 avoidance + 2.72 bodies) |
| **Server total per net tick** | **≤ 1.75 ms** | **≈ 12 ms** |
| Physics frame, wall clock | — | **16.77 ms** full, 16.58 with no crowd at all |

**Three findings, in the order they matter.**

**1. The decisions are almost free; the movement is not.** The whole crowd stage — hash, brains,
goals, repath queue, formations — is 0.54 ms and inside budget. Movement is 5.69 ms a physics
frame and there are two per tick.

**2. US-0045's LOD as specified would save almost nothing.** TDD-08 §4.1 bands the *brain* rate,
and the brains are **0.046 ms** — under 1 % of the crowd's cost, and a tenth of what §11.2
budgets for a third as many of them. The lever that matters is avoidance and body movement, which
no band in §4.1 touches. **This is exactly why the instrument was built first**, and US-0045
should be designed against these numbers rather than against the table.

**3. The server keeps up, and that is the load-bearing fact.** Physics is paced to
`TUN-NET-CLIENT-INPUT-RATE`; a physics frame with the full crowd takes 16.77 ms of wall clock
against 16.58 with no crowd. `TUN-PERF-SERVER-TICK-BUDGET` is not being met by §11.2's
accounting; the frame deadline is, with headroom. So the test asserts the **wall clock** and
reports the rest — a red suite over a budget table that describes its author's expectations is
a suite nobody reads.

## The instrument had to be checked before its number was believed

The first version asserted on `Performance.TIME_PHYSICS_PROCESS` alone and reported **31 ms per
physics frame** — a 17× miss, and entirely plausible. The wall clock, unmeasured at the time,
was a flat 16.7 ms in every configuration including no crowd at all. The monitor is not evidence
on its own, and a decomposition run (full / no avoidance / no crowd) produced 7.0 / 4.1 / 1.4 ms
against the same 16.7 ms wall clock in all three.

Trap 3's family, in a profiler: a reading that cannot be cross-checked reports whatever it
reports.

## Test notes

`test_crowd_perf.gd` measures the **server**. §11.1's client budget is animation-dominated —
1.20 ms of its 1.90 is `AnimationTree` updates — and there is no `NpcView`, no mesh and no
animation in the project, so any client figure today would measure the absence of the expensive
part. The test asserts that absence explicitly, so it goes red the day `npc_view.tscn` lands and
the client half becomes measurable.

If the crowd budget is missed, work the fallback ladder in PERFORMANCE_BUDGET section 6 IN ORDER.
Reducing crowd count is last, and never below 60.

## Notes

The 0.10 ms crowd margin is the tightest in the corpus. This gate is where the project's largest
unvalidated assumption — GDScript performance across 90 agents — is first measured.
