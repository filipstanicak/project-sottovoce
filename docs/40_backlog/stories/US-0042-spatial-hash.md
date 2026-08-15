---
id: US-0042
title: Shared spatial hash
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-16
depends_on: [TDD-08-CROWD, TDD-07-SUSPICION]
---

# US-0042 — Shared spatial hash

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-CROWD-CORE` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | S |
| **Depends on** | US-0041 |

## Description

A uniform grid rebuilt once per tick, shared by four consumers: nearest-NPC queries, blend
validation, startle propagation and gawk token issuance.

The naive alternative is O(pawns x NPCs) in three separate places — 540 distance checks per tick
for suspicion alone.

## Acceptance criteria

- [x] **Cell size 6.0 m, equal to the open-ground radius**, so the hottest query touches at most
      4 cells. **Read from `TUN-SUSPICION-OPEN-RADIUS` rather than declared as 6.0** — the
      criterion is that the two are the *same number*, and a literal would stop being true the
      first time the radius is retuned. Asserted against the tunable, not against 6.
- [x] **Rebuilt each tick from 90 NPCs with no allocation after warm-up.** A counting sort over
      buffers sized once in `setup()`. `test_spatial_hash_no_alloc.gd` scans `rebuild()` and the
      three counting queries for `[]`, `{}`, `.new(`, `Array(`, `Dictionary(` **and `.resize(`**,
      which is an allocation written in a syntax that does not look like one.
- [x] **Provides `query`, `count_within`, `count_persona` and `nearest_distance`.**
      `nearest_distance` takes a bound — see below.
- [x] **Query results match brute force for 1000 random queries.** And for 300 each of
      `count_within`, `count_persona` and `nearest_distance`. Every one of those comparisons also
      counts how often it found *anybody* and fails if that number is low, because two empty
      answers agree.
- [x] **Rebuild costs at most 0.15 ms.** Measured over a thousand rebuilds of 90 NPCs:
      **0.0561 ms**, 37 % of the budget.

## `nearest_distance` is bounded, which TDD-08 §6's signature is not

`nearest_distance(centre, within)` returns `INF` when nobody is inside `within`, rather than
widening its search until it finds somebody.

An unbounded nearest has to keep expanding, and in the one case that matters — a player genuinely
alone — that expansion is a full scan of the crowd, per pawn, per tick. That is exactly the
O(pawns × NPCs) cost this file exists to remove, arriving precisely when the district is
emptiest and the answer matters most.

No consumer needs more. `TUN-SUSPICION-GAIN-OPEN` asks whether anybody is within
`TUN-SUSPICION-OPEN-RADIUS`, and "further than that" is the whole answer.

## Two decisions that are not obvious from the structure

**Distance is horizontal, always.** A player 3.5 m up on the Loggia balcony is not in a blend
pocket with the crowd below — but they are equally not *alone* for `TUN-SUSPICION-GAIN-OPEN`, and
the rule that charges them for being up there is `TUN-SUSPICION-GAIN-ROOF`. A 3D radius would
charge it twice, quietly, in a system that never mentions elevation.

**An entity outside the map is clamped into a border cell, not refused.** The grid is a broad
phase and every query ends in an exact distance test, so a clamped entity is still correctly
excluded by distance — whereas refusing it would make an NPC invisible to a query standing right
beside it. A silent hole at the map edge, which is where the canal is.

**The hash is rebuilt before the brains, not after.** TDD-08 §1's diagram feeds it into them:
startle propagation asks who is nearby (US-0044). Rebuilt afterwards, every brain would see the
previous tick's crowd while every system downstream saw this tick's — one of the two would be
wrong and neither would say so.

## Test notes

| Test | Asserts |
|---|---|
| `test_spatial_hash.gd` | The cell size **is** `TUN-SUSPICION-OPEN-RADIUS`; brute-force equivalence for `query` ×1000, `count_within` ×300, `count_persona` ×200 and `nearest_distance` ×300, each refusing to pass if too few queries found anybody; `count_persona` provably differs from `count_within`; height does not empty a radius; an out-of-map entity is still found beside it; a rebuild replaces rather than accumulates; a shorter count hides the inactive tail; an empty hash answers rather than crashes; **a rebuild costs 0.0561 ms** |
| `test_spatial_hash_no_alloc.gd` | `rebuild()` and the three counting queries construct nothing and resize nothing; falsified against a planted `{}` |
| `test_crowd_moves.gd` | After thirty ticks of walking, **every NPC is findable at its own feet** — the only assertion that separates a live hash from one built once at setup |
| `test_crowd_is_wired_into_the_server.gd` | Exactly one place rebuilds it, and `MatchContext` owns it |

The timing assertion is deliberately an order of magnitude looser than the measured figure, with
the real number printed beside it. A timing test pinned at its budget on shared CI hardware is a
flaky test, and a flaky test gets a wider threshold until it means nothing — which is how a real
regression ships. The log line is the evidence; the assertion is a tripwire.

## Notes

Not double-buffered. Suspicion must see THIS tick's crowd, not last tick's — a player accruing
alone-suspicion inside a pocket that has already re-formed is the silent failure this ordering
exists to prevent. Rebuild is cheap enough that correctness wins.
