---
id: US-0050
title: ContractSystem and repair events
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-10-SCORING]
---

# US-0050 — ContractSystem and repair events

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-CONTRACT` |
| **Systems** | `SYS-CONTRACT` |
| **Estimate** | S |
| **Depends on** | US-0049 |

## Description

The server system wrapping ContractCycle: repair on kill, death, disconnect and join, with
debouncing and replication.

## Acceptance criteria

- [ ] Cycle built at countdown as a uniformly random permutation.
- [ ] Repair happens in the SAME TICK the death resolves.
- [ ] Multiple events within 0.25 s are batched into one repair pass.
- [ ] New contract issued after the 3 s reassignment delay.
- [ ] NET-S2C-CONTRACT-ASSIGNED carries peer id and reason ONLY — no persona, no position.
- [ ] Reassignment is announced audibly and visibly, not merely applied.

## Test notes

`test_contract_repair_same_tick.gd` asserts no player is contractless at a tick boundary.
`test_contract_degenerate.gd` for n equals 2 and n equals 1.

## Notes

Kill and stun are ordered before contract repair in the tick sequence precisely so the invariant
never lapses at a boundary.

Players not noticing reassignment is a named failure mode — the announcement is required, not
polish.
