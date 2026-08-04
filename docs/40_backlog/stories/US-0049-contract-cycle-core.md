---
id: US-0049
title: ContractCycle core algorithm
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
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

- [ ] Pure Core — no Node, no engine, unit-testable with no scene.
- [ ] `contract_of` and `pursuer_of` are cyclic successor and predecessor.
- [ ] Removal yields a cycle of length n-1 with no reassignment pass — THE REPAIR IS THE REMOVAL.
- [ ] Insertion is constrained: never self, avoid the recent contract, avoid killer-adjacency.
- [ ] Self-assignment is the ONLY hard constraint; others relax in a fixed documented order.
- [ ] `assert_valid()` checks distinct ids, no fixed point at n at least 2, exactly one cycle.
- [ ] n equals 2 raises TEL-DEGENERATE-CYCLE; n equals 1 issues no contract without erroring.

## Test notes

`test_contract_cycle_fuzz.gd` runs 10 000 randomised event sequences — kills, respawns, joins,
disconnects, batched — asserting the invariant throughout.
`test_contract_never_self.gd` asserts no relaxation path ever drops the self filter.

## Notes

Removing a node from a cycle yields a cycle. The victim's pursuer automatically inherits the
victim's contract, so no player is contractless at any instant. That property is why a cycle was
chosen over a random matching.

A constraint system that can FAIL is a crash waiting for a playtest.
