---
id: US-0070
title: Ability — Lunge
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-04-ABILITIES, TDD-09-ABILITY]
---

# US-0070 — Ability: Lunge

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY` |
| **Estimate** | M |
| **Depends on** | US-0069 |

## Description

A six-metre committed dash that auto-initiates a kill on arrival.

The "I have been made, commit now" button.

## Acceptance criteria

- [ ] 30 s cooldown, 0.25 s wind-up, 6 m at 9 m/s, +40 suspicion applied at wind-up.
- [ ] Direction LOCKS at wind-up — no steering mid-dash.
- [ ] Auto-initiates the kill only against the caster's own contract.
- [ ] STUNNABLE for the entire wind-up and dash.
- [ ] A whiff costs a 1.2 s stagger in the open.
- [ ] Startles NPCs within 7 m along the dash path.

## Test notes

`test_lunge_stunnable.gd`, `test_lunge_unsteerable.gd`, `test_lunge_contract_only.gd`.

## Notes

A prepared defender ALWAYS beats a Lunge: 0.92 s of telegraphed, unsteerable approach against a
0.7 s stun with a 120 degree cone, and the +40 at wind-up guarantees the lunger is at least
Noticed, which satisfies the stun tier gate.

Sprint is deliberately awkward to enter because it is for PLANNED speed. Lunge is the answer to
UNPLANNED speed — one press, no timing, when your target has turned and you have one second to
decide whether to abandon the hunt or spend everything on it.

Watch TEL-KILLS-BY-METHOD. Above ~15 percent of kills means the approach phase is being
short-circuited.
