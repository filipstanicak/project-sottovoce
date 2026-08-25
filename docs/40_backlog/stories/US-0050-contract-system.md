---
id: US-0050
title: ContractSystem and repair events
version: 0.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-21
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

- [ ] Cycle built at countdown as a uniformly random permutation. **`open()` exists, is Fisher–Yates against the seeded generator and is tested — and nothing calls it, because there is no COUNTDOWN phase until `SYS-MATCH`.** The live path is `report_join`, which builds the cycle as peers arrive.
- [x] Repair happens in the SAME TICK the death resolves.
- [x] Multiple events within 0.25 s are batched into one repair pass.
- [x] New contract issued after the 3 s reassignment delay.
- [x] NET-S2C-CONTRACT-ASSIGNED carries peer id and reason ONLY — no persona, no position. **A wire slot, not a peer id**: peer ids never travel (US-0029), and the mapping happens at the one call site in `server_root`.
- [ ] Reassignment is announced audibly and visibly, not merely applied. **The wire carries it and nothing renders it**: `Audio.play()` is a stub until US-0075 and `CompassVM` is US-0057. Named as a failure mode by the story, so it is not rounded up.

## Test notes

`test_contract_repair_same_tick.gd` asserts no player is contractless at a tick boundary.
`test_contract_degenerate.gd` for n equals 2 and n equals 1.

## Notes

Kill and stun are ordered before contract repair in the tick sequence precisely so the invariant
never lapses at a boundary.

Players not noticing reassignment is a named failure mode — the announcement is required, not
polish.

## What it cost, 2026-08-21

**FOUR OF SIX, AND THE TWO OPEN ONES ARE BLOCKED ON THINGS THAT DO NOT EXIST.**

**THE TWO RULES LOOKED CONTRADICTORY AND ARE NOT.** "Repair in the same tick" and "batch events
inside 0.25 s" coexist because **a removal is not a rebuild**: deleting a node from a cycle
leaves a cycle, so removals apply at once and cannot conflict. The debounce governs the
announcement and the insertions — the operations that choose something.

**AND THE BREATH POINTED THE KILLER AT A CORPSE.** `TUN-CONTRACT-REASSIGN-DELAY` was built as
*hold the new contract*, which left the old one standing for three seconds — a Compass aimed at
the player they had just killed. A kill announces **twice** now: the clear lands at once, the
name after the breath. Found by the one assertion that swept **every tick** rather than the
settled state, and every other test in the file passed over it.

**`net.gd` WAS 392 OF ITS 400 LINES WITH SEVEN MORE M4 EVENT MESSAGES TO COME**, so the split its
own comment predicted — *"the C2S doorway below could move the same way if this file grows
again"* — happened at the **first** of them rather than the fifth. `EventWire` is a child of the
`Net` autoload, which is at the same path on every peer.
