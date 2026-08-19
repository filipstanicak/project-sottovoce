---
id: US-0045
title: Crowd LOD — update rate and animation
version: 0.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-19
depends_on: [ADR-0003, TDD-08-CROWD, BIBLE-PERF-BUDGET]
---

# US-0045 — Crowd LOD: update rate and animation

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-BEHAVIOUR` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0044 |

## Description

Distance-banded update-rate LOD on the server and animation LOD on the client.

## Acceptance criteria

> **Three of six. The three that are open are the CLIENT half**, and **`NpcView` now exists** — a
> client draws 66–72 NPCs across ~108 m of district, and **watching it for eight seconds found
> three defects no test in this repository could reach**. See "What watching it found" below.
> A client draws the crowd across 108.7 m of district. What is still missing is what LOD would *band*:
> there is **no mesh and no `AnimationTree`**, and every NPC wears the same greybox body, so
> animation LOD has nothing to reduce and mesh LOD has nothing to swap. US-0046's, and it needs
> animation clips, of which this project has **none on either rig**.

- [x] **Bands at 20 m near, 45 m mid, 70 m far**, from `TUN-PERF-CROWD-LOD-*`, evaluated per tick
      as squared-distance compares against the nearest player. **No players means Far**, because
      an empty server has nobody to be fooled by a slow crowd and the other way round would make
      the emptiest server the most expensive one.
- [x] **Brain rate: every tick near, every third mid, every fifteenth far.** Measured at **46 of
      78 effective** with six players at the spawn points — see below; this story published
      6 of 78, which was an empty district. Staggered by NPC index, or a third of the crowd would
      think on the same tick and the *spike* would be worse than the flat cost it replaced.
- [x] **LOD changes RATE only. No distance check appears inside `NpcBrain.step()`.**
      `test_lod_changes_rate_not_logic.gd` scans for `CrowdLod`, `Band`, `distance`, `players`,
      `pawns` and `global_position`, and is falsified against a planted violation. It also asserts
      the **`stride`** reaches the brain, which a distance scan cannot see.
- [ ] **Client animation LOD: full tree near, reduced mid, single clip far.** `NpcView` exists as
      of this update; what is still missing is the **mesh and the `AnimationTree`** — there is
      nothing to band. **US-0046**, and there are no animation clips on either rig.
- [ ] **Animation LOD NEVER changes silhouette or gait inside the 60 m compass range.** Same
      blocker, and it needs rendered frames to compare.
- [ ] **Mesh LOD at 100, 50 and 20 percent triangle counts.** Same blocker; there are no meshes.

## §4.1's saving is real, smaller than this story first claimed, and worth less than either

`test_crowd_perf.gd` was built **before** this story, deliberately, so LOD had a number to move.

**THIS STORY'S FIRST FIGURE WAS MEASURED ON A DISTRICT WITH NOBODY IN IT.** It reported 6 of 78
effective brain steps and explained it as six players spreading thinly over 120 × 120 m. There
were no players: `test_crowd_perf.gd` ran with `MatchContext.pawns` empty, so `CrowdLod.band_of`
answered Far for everything and 6 is 78 divided by the Far stride of 15. Found in US-0047, fixed
in US-0041's last line, and corrected here rather than quietly left.

| | §4.1 | First published | **Measured, six players at the spawn points** |
|---|---|---|---|
| Effective brain steps | ~34 of 90 | 6 of 78 | **46 of 78** |
| Near / Mid / Far | ~20 / ~35 / ~35 | 0 / 0 / 78 | **30 / 48 / 0** |
| `CrowdDirector.tick()` | — | 0.54 → 0.44 ms | **0.54–0.57 ms** |

**THERE IS NO FAR BAND AT MATCH START.** Six spawn points on this map leave nothing beyond
`TUN-PERF-CROWD-LOD-MID` 45 m of somebody, so the reduction is 78 → 46 — **1.7×, against §4.1's
2.6× and against the 13× the empty run implied** — and the fifteen-tick stride only applies once
players cluster and leave part of the district unwatched. The *saving* remains a fifth of a
millisecond either way, because US-0048 measured the brains at **0.046 ms of the crowd's cost**
before this was built.

§4.1 calls the reduction "the difference between fitting the budget and not". It is not. It is
built because ADR-0003 requires it, because it **unblocks US-0041's far-band path validity**, and
because other systems will want a band number — and the story says so instead of claiming a
performance win it does not deliver.

## Two things LOD nearly changed that are not rates

**A banded brain's timers.** Stepped every fifteenth tick and decremented by one,
`TUN-CROWD-IDLE-DURATION-MIN` 8 s becomes 120 s. `NpcBrain.step()` takes a `stride` for exactly
this. The only symptom would have been a distant crowd standing unusually still, which reads as
atmosphere.

**Events raised on a tick the brain did not think.** Clearing `CrowdContext` every tick regardless
— which is what the first version did — wipes a `startle_flag` before anybody reads it, so **LOD
would have silently dropped startles and gawk tokens for two thirds of the crowd**, worse the
further away you are. Startle is the one interrupt the design requires to be *reliable*, because
players read it as information.

Both are behaviour changes wearing a rate change's name, which is exactly what ADR-0003 forbids.
Neither would have produced an error, a log line or a failing test before US-0045's own suite.

## Test notes

| Test | Asserts |
|---|---|
| `test_crowd_lod.gd` | The bands are the documented radii; the **nearest** player decides; an unwatched crowd is Far; the strides are 1/3/15; a band is spread across its own period **and** nobody starves; **a Far brain keeps the documented idle duration**; LOD actually reduces how many brains think; an NPC beside a player is Near; **a startle is not dropped by a band** |
| `test_lod_changes_rate_not_logic.gd` | `NpcBrain` cannot see distance, bands, players or positions — falsified against a planted `if ctx.position.distance_to(player) > 45.0`. And the `stride` reaches it |
| `test_crowd_perf.gd` | Reports the effective brain count each run, so §4.1's claim stays measured rather than asserted |

`test_anim_lod_silhouette.gd` is still unwritten and needs rendered frames — US-0046.

## Notes

`CrowdIntent` was split out of `CrowdDirector` in this story: adding the bands pushed the file
past 400 lines (never-do #6). The responsibility did not move, only its address, and
`test_steering_knows_no_states.gd` follows it.

## Notes

A crowd whose behaviour changed with observer distance would be a crowd that lies, and the crowd
is an information channel.

Mid band sits at 45 m rather than a cheaper 25 m specifically so it still produces a correct
silhouette and walk cycle at the distance players are trying to distinguish clones from humans.

## What watching it found

`tools/crowd_probe.tscn` drives a real client against a real server and samples every **drawn**
NPC for eight seconds. A still frame cannot tell a walking crowd from a frozen one, so it reports
the numbers instead of only the picture.

**THE ONE NUMBER THIS SYSTEM IS BUILT AROUND, CHECKED ON THE WIRE FOR THE FIRST TIME.** Invariant 1
forces `TUN-CROWD-NPC-SPEED-STROLL` to equal `TUN-SPEED-BLENDWALK` so a blend-walking player is
indistinguishable from the crowd **by gait**. `test_crowd_moves.gd` asserts it on the server;
interpolation sits between that and what a player sees. Measured **1.400 m/s drawn against a
documented 1.400** — 100.0 %, across 56 to 61 movers, over several runs.

Everything else it found was a defect, and all three are server-side:

1. **The NPC delta never converged, and was inert in every real game.** An ack lags by at least a
   tick, so a record is re-sent while its first copy is in flight — and refreshing the stamp on
   each re-send means the entry always leads the ack and is never promoted. A motionless NPC at a
   constant **7.6122 m was sent on twelve consecutive ticks**. Every unit test acknowledged
   synchronously, which is the one timing that hides it.
2. **A departing NPC became a statue.** Absence cannot say "gone", and the last position a client
   is told is inside the radius by definition, so its own distance check can never fire. Eight
   seconds with a stationary player produced **zero drops**. The server sends one final
   out-of-range record now.
3. **The cull boundary chattered.** A single threshold is not stable against a crowd: RVO shoves a
   standing body at up to 0.1 m/s. Leaving is decided at the radius, re-admission one margin
   inside it.

4. **The client replayed every goodbye forever, and this one was reported open first.** Four to six
   NPCs per spawn point were created and freed roughly **once per snapshot**, each last seen at
   **70.01–70.05 m** against a 70.00 m radius. The two cases that reproduce deterministically — an
   NPC parked on the line, one walking straight out through it — are quiet in
   `test_cull_jitter.gd`, and both are **server-side**. It was not the server.
   `SnapshotAssembler` carries the crowd forward, correctly, because absence means "no update" —
   and the farewell is the one record for which that is false. It cached the goodbye and
   re-presented it in every later snapshot; `NpcView` read each replay as a fresh departure, spawned
   a body for an index it no longer held, and freed it again. **Neither class was wrong about its
   own job**, which is why every test of either passed. The rule is `CrowdWire.is_farewell()` now,
   one class both of them call.

**THE CONSTANT DISTANCE WAS THE TELL AND IT WAS MISREAD AS A TIGHT BAND.** 70.01–70.05 m is not a
population of NPCs hovering near the line: it is a handful of records, each frozen at the single
value the server sent once. On the instrument that finally showed it, one NPC was re-presented at a
constant **70.0231 m on 199 consecutive ticks**.

**`tools/cull_trace.tscn` IS THAT INSTRUMENT, AND ITS FIRST VERSION REPORTED A CLEAN BOUNDARY OVER
THE DEFECT.** It boots the real `server_root.tscn` and prints the **server's** own decision about
every NPC around each drop, which is the half `crowd_probe.tscn` cannot see. It fed the views raw
wire snapshots to begin with — a path no client uses, because `Net` assembles before it emits
`snapshot_received` — and measured two drops in 240 ticks, both correct. Through the assembler:
**485 drops for 5 real departures**, and **7 for 7** after the fix.

**ONE CASE IS LEFT UNCOVERED AND IS BOUNDED RATHER THAN FIXED.** The farewell is a single record on
an unreliable channel and the server drops its baseline as it sends it, so a lost farewell is never
retried. It is not permanent — rule 2 frees anything whose last-known position passes the radius
plus `NpcView.drop_margin()`, so the observer moving about 0.6 m clears it — and it can only happen
to an NPC at 70 m, outside every gameplay radius. TDD-04 §7.1.3.

**THE PROBE ITSELF WAS WRONG TWICE, BOTH TIMES REPORTING A CONSTANT.** It first read the *drawn*
transform of dropped NPCs and reported 72.8 m for every one — exactly the distance from the
observer to the world origin, because a body that appears and drops between two samples is never
drawn anywhere. It then read the received position *after* the view had erased it, and reported
-1.0 for every one. **A diagnostic that reports the same number for everything is reporting its own
default**, which is trap 13's family and cost two runs each time.
