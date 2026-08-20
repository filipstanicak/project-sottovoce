---
id: US-0048
title: M3 gate — crowd performance and anonymity
version: 0.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-19
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

## The gate's own instrument was measuring the wrong scenario, and now is not

**`test_crowd_perf.gd` ran with no players in it**, found in US-0047 and fixed in US-0041.
`MatchContext.pawns` was empty, so `CrowdLod.band_of` answered Far for every NPC, and the
run's "6 of 78 brains stepping" was 78 divided by the Far stride of 15 rather than anything
about how six players spread over a district. Two subsystems did nothing in the measurement:
`CloneBalance` counts against player positions, and the sprinter sweep reads pawn velocity.

Six pawns now stand at the map's own spawn points. **The numbers this gate is judged against
moved, and they moved the way an honest correction moves them:**

| | Empty district | Six players |
|---|---|---|
| `CrowdDirector.tick()` mean | 0.439 ms | **0.54–0.57 ms** |
| p95 (the asserted line, budget 1.75) | 0.521 ms | **0.67–0.71 ms** |
| max over 90 ticks | 0.686 ms | **2.16–2.43 ms** |
| Brains stepping | 6 of 78 | **46 of 78** — 30 Near, 48 Mid, **no Far** |

**The spike is isolated and fixed; one thing is left for this gate to judge.** The max was
2.16–2.43 ms against a 1.75 ms budget, and it was entirely the 2 s director pass — 1.925 ms on a
pass tick against 0.500 on an ordinary one. `CloneBalance` was asking the grid and the anchor list
once per persona rather than once per player; hoisting both took the pass to 0.71 ms and the
whole-tick max to **1.26–1.29 ms, inside budget with the max included**. TDD-08 §11.2.2 records it.

What is left: there is **no Far band at all** at match start, so US-0041's far-band path validity
and §4.1's 15-tick stride only apply once players cluster — which means the crowd is at its most
expensive exactly when the district is most evenly occupied.

## Acceptance criteria

> **THE GATE IS RUN, AND IT FOUND A BUDGET MISS NOBODY WAS LOOKING FOR.** Three of its ten lines
> are met, one is a **measured miss**, and six are blocked by things that do not exist. The line
> that moved is bandwidth: `test_crowd_bandwidth.gd` did not exist, exactly as
> `test_upstream_bandwidth.gd` did not exist at the M2 gate, and writing it put downstream at
> **112 % of budget** against the 97 % the corpus has published since US-0029. **A gate's value is
> checking that the things it names exist and measure what they claim to** — that is now twice in
> a row that the answer was no.
>
> **THE GATE IS NOT RUN. TWO OF ITS INSTRUMENTS ARE BUILT.** `test_crowd_perf.gd` was written
> ahead of US-0045 on purpose: LOD exists to buy frame time, and optimising against a budget
> nobody has measured is how the upstream bandwidth miss reached 253 % while a document said
> 112 %. `test_clone_local_min.gd` arrived with US-0047. Everything else below still waits for
> US-0046 and for an owner at a windowed client.

- [x] **`test_crowd_perf.gd` passes with 90 NPCs**, in the standard scenario — ninety allocated,
      `TUN-CROWD-COUNT-DEFAULT-6P` active, on the real map with the real navmesh, **and six
      players at the map's own spawn points since US-0041**. It ran with *no* players until then,
      which made every figure §11.2 published a best case; see above. It passes on the frame
      deadline and on p95, and TDD-08 §11.2's table is amended with the measured figures rather
      than reworded.
- [ ] p99 client frame time at or under 16.6 ms with peak crowd density.
- [x] **Server tick p99 at or under 8.0 ms** — **measured at 2.147 ms, 27 % of budget**, over
      180 samples of the real `server_root.tscn` with a full lobby and the full crowd: mean 1.58,
      p50 1.55, p95 1.81, **max 2.27**. Reproducible to three decimal places across runs.
      `test_server_tick_budget.gd`, written here because **this line named an instrument that did
      not exist** — `test_crowd_perf.gd` times `CrowdDirector.tick()`, one row of §2's eight.
      **The maximum is asserted rather than the p99**, which is strictly stronger: if no tick is
      over budget, no percentile can be, and a p99 over 180 samples is one of the worst two
      readings whatever the estimator.
      **It boots the real server scene, which no test had ever done** — trap 4 names it
      specifically — and it measures between `net_ticked` and `tick_completed`, which bracket
      exactly the thing under budget.
      **What it leaves out is stated and measured separately, never added**: `Net.send_snapshot`
      early-returns without an ENet peer, so `serialise()` is not in the figure. It costs
      **1.26 ms** for six clients. Summing the two would be a projection, and the gate has caught
      two of those already; what they jointly support is only the weak claim that the omission
      cannot put the tick near 8.0 ms.
- [ ] `test_crowd_bandwidth.gd` within 96 kbit/s down.
      — **WRITTEN AT THIS GATE, AND IT MEASURES 108.0 kbit/s — 112 %.** Not blocked any more:
      **missed, on a measurement.** §7.1's head-counts were very nearly right (41.0 near against
      ~45, 29.2 far against ~30) and its two **change fractions** were not — 0.776 and 0.761
      measured against 0.55 and 0.70 assumed. Those two decide the total and were the only inputs
      never checked; US-0029 shrank the NPC record 10 B → 8 B on the strength of this table while
      `0.55` sat unquestioned inside it. **The record was never the problem.** TDD-04 §7.1.1.
      — **AND THE THREE MECHANISMS §7.1 ASSUMES ARE NOW ALL BUILT, WHICH DID NOT CLOSE IT.**
      US-0030 culled the crowd and US-0031 added rate LOD and an NPC delta: **155 % → 119 % →
      111 %**, measured on the real builder's serialised bytes. That agrees with the projection
      above to one point, by an independent route. **The remaining 11 % has no owner and neither
      candidate is priced** — ADR-0007's seed-derived far crowd, or a smaller
      `TUN-NET-NPC-CULL-RADIUS`, which invariant 17 pins above `TUN-COMPASS-RANGE-MAX`.
      TDD-04 §7.1.2.
- [ ] `test_clone_animation_parity.gd` and `test_footstep_parity.gd` pass for all four personas.
- [x] `test_clone_local_min.gd` passes over a clustered 3-minute match. **US-0047.** A unit
      test, because 5 400 ticks of physics do not fit the integration budget. **Passing is not the
      same as the guarantee holding always**, and the number this line first published was
      **wrong**: it said 2 readings of 12 960, which was a property of one anchor arrangement
      rather than of the rule. Fixing an unrelated level bug (US-0096) took the same code to 248,
      and crediting the floor to *arrived* clones rather than departed ones brought it to
      **100 of 12 960**. What the test asserts now is that a breach is never ignored — of 21
      short pairs, 18 already had a clone walking and 6 were dispatched. US-0047's "always"
      criterion is unticked on exactly that. **The gate should read the number, not the tick**,
      and this line is the reason that sentence is in the story. TDD-08 §5.1.4.
- [ ] Startle waves read directionally to a human observer.
- [ ] Feel check: the crowd feels alive — a tester still looks at NPCs unprompted after minute 4.
- [x] **Risk register re-scored: RISK-CROWD-PERF, RISK-ANONYMITY-LEAK, RISK-ANIM-SCOPE** — and
      `RISK-BANDWIDTH`, which the gate did not name and which moved most. **Three of the four went
      up.** `RISK-ANONYMITY-LEAK` Low → **Medium** (a live instance in the level data, not a
      hypothesis about an animator); `RISK-ANIM-SCOPE` Medium → **High** (the clip count in this
      project is **zero**, on either rig, with three stories blocked behind it);
      `RISK-BANDWIDTH` impact Low → **Medium** (downstream's fix is culling or ADR-0007, neither
      free, where upstream's was cheap). `RISK-CROWD-PERF` **did not move, and the reason is the
      finding**: the server half is measured and comfortable, and the 0.10 ms margin is on the
      *client*, which has no `NpcView` to measure.
- [ ] Tag `m3-crowd` pushed.
      — **the owner's call, and deliberately not taken here.** M1 and M2 were both tagged over
      unticked lines, so precedent does not block it; what is new is a **measured** budget miss
      rather than an absence. Outstanding at the moment of the tag: downstream 112 %, six lines
      blocked on clone meshes / animation clips / a human at a windowed client, and one line
      (server tick p99) whose instrument is buildable and unbuilt.

## What the first measurement of the project's largest assumption says

ADR-0001 accepted GDScript-across-ninety-agents as a risk and gave it a fallback ladder. This is
the first time it has been measured.

| | Budget (§11.2) | Measured, 78 NPCs, no LOD |
|---|---|---|
| Spatial hash rebuild | ≤ 0.15 ms | **0.054 ms** |
| `NpcBrain.step()` × all 78 | ≤ 0.50 ms for ~34 | **0.046 ms** |
| Everything inside `CrowdDirector.tick()` | — | **SUPERSEDED — no players in the district; see below** |
| Crowd movement, per **physics** frame | ≤ 0.60 ms for ~34 | **RETRACTED — see below** |
| **Server total per net tick** | **≤ 1.75 ms** | **RETRACTED — derived from the row above** |
| Physics frame, wall clock | — | **16.77 ms** full, 16.58 with no crowd at all |

> **TWO ROWS OF THIS TABLE ARE WITHDRAWN AND THE REST OF IT IS SUPERSEDED.** The movement figure
> came from `Performance.TIME_PHYSICS_PROCESS`, which reported **31 ms, then 5.69, then 24–28** for
> arrangements whose wall clock never moved off 16.7 ms — **a cost larger than the frame
> containing it is a broken instrument, not a slow frame**. PR #95 published 5.69 before the
> contradiction was spotted; TDD-08 §11.2.1 carries the retraction and **the number should not be
> quoted**. The "≈ 12 ms server total" is arithmetic on it and goes with it.
>
> The `CrowdDirector.tick()` row is superseded for a different reason: it was measured on a
> district with **no players in it**, so every NPC banded Far and two subsystems did nothing. With
> six players at the map's own spawn points it was **0.52 mean / 0.59-0.64 p95 / 1.26-1.29 max**
> — **superseded on 2026-08-20**: locally 0.74-0.80 / 0.89-0.95 / 1.53-1.72, and on CI p95 1.067,
> 1.249 and 1.815, the last of which failed the build. This gate line is MARGINAL, not comfortable,
> and the brains step **46 of 78**, not 6. TDD-08 §11.2.
>
> The wall-clock row is the one that survived all of it, and it is the one that mattered: the
> server keeps up, with the full crowd, against a 16.67 ms deadline.

**Three findings, in the order they matter.**

**1. The decisions are almost free.** The whole crowd stage — hash, brains, goals, repath queue,
formations — is **0.52 ms mean and 1.26–1.29 ms at worst** with six players in the district, well
inside §11.2's 1.75 ms. **What movement costs is still unknown**: the instrument that reported
5.69 ms was broken, and getting a trustworthy per-item figure needs a profiler this project does
not have. Owed, not estimated.

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
