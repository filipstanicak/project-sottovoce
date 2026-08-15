---
id: US-0040
title: NpcBrain five-state HFSM
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-16
depends_on: [ADR-0003, TDD-08-CROWD, GDD-03-SOCIAL-STEALTH]
---

# US-0040 — NpcBrain five-state HFSM

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-CORE` |
| **Systems** | `SYS-NPC-AI` |
| **Estimate** | M |
| **Depends on** | US-0039 |

## Description

Stroll, Idle, WalkingGroup, Startle and Gawk as a flat hierarchical state machine, with Startle
as a global interrupt.

A behaviour tree was rejected: per-tick tree traversal across 90 agents in GDScript is thousands
of virtual calls for five behaviours.

## Acceptance criteria

- [x] **Exactly five states; a sixth requires an ADR.** `test_npc_brain.gd` asserts the enum's
      size, so growing it is a deliberate act rather than an accident. ADR-0003 chose a flat
      machine over a behaviour tree *on the strength of there being few behaviours* — that
      argument stops holding somewhere, and this is where somebody is made to notice.
- [x] **Startle is enterable from all four other states and always wins.** Asserted from every
      state in the enum, and separately on the hot path: the interrupt is checked **before** the
      timer, so a startle in the tick an idle pause ends still startles.
- [x] **Per-agent per-tick cost is one integer compare, one timer decrement and one small call.**
      `step()` is those three operations and nothing else. The transition table is consulted on
      *events*, which are rare.
- [x] **`step()` allocates NOTHING after warm-up.** `test_npc_brain_no_alloc.gd`, an architecture
      guard, and it is **scanned rather than measured** — see below.
- [x] **Every state-event pair is either handled or explicitly listed as ignored.** All 35 pairs
      are present in `TRANSITIONS`; the deliberate no-ops say `IGNORED` rather than being absent.
      An unknown pair logs an error instead of shrugging.
- [x] **NPC stroll speed equals player blend-walk speed exactly, asserted as an invariant.**
      Invariant 1 already existed — and would have passed identically if it had never been
      written, so it is now **falsified** against a deliberately broken profile.

## The silent no-op is the whole reason the table is exhaustive

An absent state-event pair looks exactly like a handled one. An NPC simply never leaves Idle,
nothing errors, and the crowd reads as slightly dead in a way nobody can point at. US-0040's own
notes name the completeness test as the standard defence, so the table lists all 35 pairs and the
deliberate nothings say `IGNORED` out loud.

`handle()` treats a *missing* pair as a loud failure rather than a shrug, which is the same
distinction one level down.

## Why the no-alloc guard scans instead of measuring

A runtime memory probe is the obvious approach and the wrong one. GDScript's static memory moves
for reasons unrelated to this file, so the test would be flaky — **and a flaky test gets a wider
threshold until it means nothing.** The construction syntax is what the rule is actually about,
and it is exactly what a scan can see.

It covers `step()` and everything `step()` calls, because an allocation one frame deeper is still
`step()`'s cost. Falsified against a planted `var scratch := []`.

Ninety agents at 30 Hz is **2 700 calls a second** against `TUN-PERF-CROWD-BUDGET`'s 2.0 ms for
the entire crowd — AI, navigation and animation LOD together.

## Two tunables were missing and are now in TUNABLES

GDD-03 §6.1's diagram says an idle NPC strolls on when its **"idle timer expired (8–25 s)"**, and
no tunable carried that. The machine cannot leave Idle without it, and never-do #1 forbids
hardcoding a gameplay number.

`TUN-CROWD-IDLE-DURATION-MIN` (8 s) and `-MAX` (25 s) now exist, with **the GDD's own range**
rather than an invented one, plus invariant 27 asserting min < max. Inverted, `randf_range`
returns values outside the band and every NPC's pause becomes wrong in the same direction — a
crowd that all moves off together, which reads as a mechanism rather than a city.

The pause is **drawn, not fixed**, for that reason. Measured across 40 brains: more than five
distinct durations.

## Timers are in net ticks, and that is trap 9

A brain is ticked by a system at 30 Hz, so `Tuning.ticks()` is the converter and
`Tuning.step_ticks()` — the 60 Hz input-rate one — would halve every duration **silently**,
because both produce plausible integers. Four merged call sites had this wrong before US-0016,
including the stun freeze. The test asserts the right one *and* that the two differ, so it cannot
pass by them happening to agree.

## Test notes

| Test | Asserts |
|---|---|
| `test_npc_brain.gd` | Exactly five states; **all 35 state-event pairs present**; startle enterable from every state and winning on the hot path; a gawker abandons a corpse; **fleeing beats gawking**; a second startle restarts the flee; every documented edge; an idle pause is drawn and stays in range; **timers are net ticks, not step ticks**; a clockless state never times out; `reset()` clears the propagation flag; stroll speed equals blend-walk, and invariant 1 is **falsified** |
| `test_npc_brain_no_alloc.gd` | Nothing on the hot path constructs an Array or Dictionary; the table is a `const`; the scan is falsified against a planted allocation |

The four names in the original notes — `test_npc_no_alloc.gd`, `test_npc_transition_table.gd`,
`test_startle_global_interrupt.gd`, `test_npc_speed_matches_blendwalk.gd` — are **not used**. Every
property they name is asserted, in the two files above. Recorded rather than left looking missing.

## Notes

Startle being uninterruptible means a gawking NPC abandons a corpse when startled, destroying a
standing information object. Accepted: it reads correctly, and the corpse itself persists
regardless.

The silent no-op transition is the classic FSM bug; the completeness test is the standard defence.

**Nothing ticks these brains yet.** `NpcBrain` is a machine with no driver: `SYS-CROWD` gets its
system class when there is something to steer, which needs the navmesh and agents (US-0041). The
crowd is allocated and identified and the machine is proven; what does not exist is anything that
calls `step()` in a running server. Said plainly here because US-0039's first criterion was ticked
on exactly that confusion.

**Startle propagation is US-0044's, not this story's.** `has_propagated` exists and is reset,
because it belongs to the brain's state and a recycled NPC carrying a stale flag would refuse to
pass on a startle for the rest of the match. What is absent is the propagation *itself*, which
needs the spatial hash (US-0042).
