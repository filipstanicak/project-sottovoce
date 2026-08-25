---
id: US-0049
title: ContractCycle core algorithm
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-21
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-10-SCORING]
---

# US-0049 — ContractCycle core algorithm

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-CONTRACT` |
| **Systems** | `SYS-CONTRACT` |
| **Estimate** | M |
| **Depends on** | US-0048 |

## Description

The Hamiltonian cycle over living players, as a pure Core type: an ordered list where each
player's contract is their cyclic successor.

## Acceptance criteria

- [x] Pure Core — no Node, no engine, unit-testable with no scene.
- [x] `contract_of` and `pursuer_of` are cyclic successor and predecessor.
- [x] Removal yields a cycle of length n-1 with no reassignment pass — THE REPAIR IS THE REMOVAL.
- [x] Insertion is constrained: never self, avoid the recent contract, avoid killer-adjacency.
- [x] Self-assignment is the ONLY hard constraint; others relax in a fixed documented order.
- [x] `assert_valid()` checks distinct ids, no fixed point at n at least 2, exactly one cycle.
- [x] n equals 2 raises TEL-DEGENERATE-CYCLE; n equals 1 issues no contract without erroring.

## Test notes

`test_contract_cycle_fuzz.gd` runs 10 000 randomised event sequences — kills, respawns, joins,
disconnects, batched — asserting the invariant throughout.
`test_contract_never_self.gd` asserts no relaxation path ever drops the self filter.

## Notes

Removing a node from a cycle yields a cycle. The victim's pursuer automatically inherits the
victim's contract, so no player is contractless at any instant. That property is why a cycle was
chosen over a random matching.

A constraint system that can FAIL is a crash waiting for a playtest.

## What it cost, 2026-08-21

**BUILT AND DONE, SEVEN OF SEVEN.** `scripts/core/contract/contract_cycle.gd`, 270 lines, pure
but for `Tuning`. The fuzz applies **10 000 events over 200 sequences** — 5 334 removals, 4 491
insertions, 1 222 batches — and checks `assert_valid()` between every pair, visiting cycle sizes
0 through 9 including the degenerate 2 and the lone survivor.

**THE ANTI-REPEAT RULE WAS INERT, TWICE, AND ONLY THE RESPAWN TEST COULD SEE IT.**

1. `remove()` cleared the departing peer's contract history — and the **only reader of that
   history is the insertion that happens when they come back**. Every assertion about a live
   cycle passed.
2. `open()` did not record the deal it had just made, so at the first respawn of a match the
   history was empty. Measured: **26 of 40 seeds avoided the repeat, against 40 of 40 after.**

Both are the same shape: a rule that is present and never reached. Neither errored, and the
fuzz could not find them — a cycle with no history is a perfectly valid cycle.

**`assert_valid()` RETURNS A STRING.** GDScript strips `assert()` from release builds, so a
validity check written as an assertion does not exist in the shipped game. Empty means sound.

**A JOIN IS THE SAME CALL AS A RESPAWN** with the constraints vacuous, rather than GDD-03 §7.2's
separate random insertion — so the two cannot drift. And `apply()` performs every removal before
any insertion, which is what stops a respawn landing beside somebody leaving in the same batch.

**THE SELF FILTER IS GUARDED TWICE**: an exhaustive sweep of every cycle size 0–6 against every
killer choice and six seeds, and a source scan refusing a `_candidates` whose self filter sits
*below* the first relaxation branch — the shape that would let a future fourth stage drop it.

`SYS-CONTRACT`, the delays and the debounce clock are US-0050's; this story is the algorithm.
