---
id: US-0060
title: KillSystem with contest and lag compensation
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-10-SCORING, ADR-0010]
---

# US-0060 — KillSystem with contest and lag compensation

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-COMBAT` |
| **Systems** | `SYS-KILL` |
| **Estimate** | **L** |
| **Depends on** | US-0059 |

## Description

Kill validation against the lag-compensated world, the contest window, and the committed
animation.

## Acceptance criteria

- [ ] Valid only against the killer's own contract; any other target is rejected.
- [ ] A rejected kill applies +30 suspicion and plays a WHIFF — never silence.
- [ ] Range 2.5 m plus 0.35 m grace, evaluated after rewind.
- [ ] Facing cone 60 degrees for the killer; the VICTIM's facing is irrelevant.
- [ ] Rewind clamped to 100 to 200 ms; NPCs and Cinderfall volumes rewound too.
- [ ] Tier, contract and cooldowns are NOT rewound — always current.
- [ ] Contests inside 0.4 s resolve by SERVER RECEIVE TICK, never client time.
- [ ] The loser staggers 1.5 s with no points and no lockout.
- [ ] 1.4 s animation; victim dies at the 0.9 s contact frame.
- [ ] Kill initiation is blocked inside any Cinderfall volume, including the caster's own.

## Test notes

`test_kill_contract_only.gd`, `test_kill_facing_cone.gd`, `test_kill_contest.gd`,
`test_lagcomp_rewind.gd`, `test_lagcomp_no_exploit.gd`, `test_no_client_time_in_kill.gd`.

## Notes

Killing a target facing away from you is the intended patient play, not an exploit.

Server receive order for contests advantages low ping. Accepted: client timestamps are trivially
forgeable, and server receive order is the only ordering the server can trust. TEL-CONTEST-RESOLVED
logs both RTTs so the skew is measurable rather than assumed.
