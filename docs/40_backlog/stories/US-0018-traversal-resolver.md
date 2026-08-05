---
id: US-0018
title: Traversal resolver and forgiveness
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-05
depends_on: [TDD-06-PAWN, GDD-02-PLAYER]
---

# US-0018 — Traversal resolver and forgiveness

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-TRAVERSAL` |
| **Systems** | `SYS-TRAVERSAL` |
| **Estimate** | M |
| **Depends on** | US-0017 |

## Description

The seven-case first-match-wins resolver plus the magnetism windows.

Combined forgiveness is ~0.45 s — enormous by action-game standards, and correct: a missed ledge
must be a decision error, never a timing error, because the player's attention belongs on the
crowd rather than their own footwork.

## Acceptance criteria

- [x] Resolution follows TDD-06 section 4.2 order exactly: ledge grab, gap jump, drop, vault, mantle, climb, nothing.
- [x] Ledge grab is FIRST — forgiveness goes before everything.
- [x] Vault is checked before mantle, so a low wall you can go over does not become one you climb onto.
- [x] Climb is LAST — the most expensive option is never selected when a cheaper one applies.
- [x] Case 7 consumes the input and plays nothing. Silence, not a flail.
- [x] Magnetism: 0.25 s late window, 0.6 m lateral radius.
- [x] Gap-jump auto-align within 20 degrees.

## Test notes

`test_traversal_resolution.gd` covers all seven cases in order, including case 7's silence.
`test_traversal_forgiveness.gd` asserts 0.20 s early and 0.25 s late both resolve.

## Notes

A failed traverse must never look like a bug.

---

## Seven cases, four states

Gap jump and drop both enter `Drop`; vault and mantle both enter `Vault`. TDD-06 §4.2's
pseudocode says so explicitly — each state branches internally on the numbers the probes left.

That makes the ordering **untestable from the return value alone**: a test that could only see
the state name could not tell case 2 from case 3 at all, and the first acceptance criterion is
precisely that the order is followed. So `classify()` returns the case and `resolve()` maps it to
a state. The design specifies an ordering; the code exposes one.

`classify()` is also side-effect free, so a tell or an animation anticipation can ask what a
traverse *would* do without stealing the player's press. Only `resolve()` consumes.

## What this story found

### 1. The auto-align fan silently never fired

`_cast_gap_fan` guarded on `probe.at_edge()` — and `at_edge()` requires `ProbeResult.valid`,
which `refresh()` sets **after every cast has run**, including that one. The fan asked the
finished-reading question from inside the reading, got `false` every time, and did nothing.

No error, no failing test. The symptom would have been auto-align appearing not to exist, which
reads as "the controls ignore you" and gets blamed on latency.

The `valid` flag was added in US-0017 to stop *readers* mistaking "nothing known" for "nothing
there". It turns out the prober cannot use its own guard, which is a distinction worth having
learned once.

### 2. The ledge top-cast measured the floor in front of the wall

It was placed a fixed `TUN-TRAVERSE-GAP-PROBE-STEP` ahead of the pawn instead of past the face
the ledge ray actually hit. A wall 0.5 m away and one 0.9 m away have their tops in different
places; the cast landed in front of the near one every time and returned the ground height, which
`ledge_is_reachable` then rejected.

`_cast_obstacle_top` had already solved this in US-0017, by casting from the measured hit
distance. The ledge cast did not, because it was written from the same shape without the same
reason attached to it.

### 3. A bare `ProbeResult` reads as "standing at an edge"

Not a bug this time — a hazard, and I walked into it writing the test fixtures. `foot_clear`
defaults to `true` and `ground_ahead` to `false`, so any hand-filled result that does not state
otherwise satisfies the edge test, and every case resolved as a drop.

Real probes always set `ground_ahead`. Test doubles have to as well, and the fixture now says so
where someone writing the next one will read it.

## One tunable promoted

`TUN-TRAVERSE-GAP-ALIGN-ARC` 20°. GDD-02 §7.3's forgiveness table listed four windows and gave
IDs to three; the auto-align arc was a bare "±20°" in the value column with a dash where its ID
should have been.

## What this story does not do

- **Nothing calls `resolve()` yet.** `Vault`, `Climb` and `Drop` are declared in the graph with
  legal edges, and unimplemented until US-0019 and US-0020. Wiring the resolver into the
  locomotion states now would push the pawn into an unregistered state on the first press — the
  exact failure US-0016 hit with `Respawning`, and the reason `spawn_into()` exists.
- **No drop-swing.** §7.2 case 3 mentions it for a lower ledge within 2 m; that is US-0020's
  state, and the probes do not look for one.
- **`aligned_yaw()` is computed but never applied.** The gap jump that would apply it is
  US-0020's `Drop`.
