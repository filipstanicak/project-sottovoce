---
id: US-0019
title: Vault and mantle states
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-06-PAWN, BIBLE-ANIMATION-SPEC]
---

# US-0019 — Vault and mantle states

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-TRAVERSAL` |
| **Systems** | `SYS-TRAVERSAL` |
| **Estimate** | S |
| **Depends on** | US-0018 |

## Description

StateVault, branching internally on height between vault and mantle. Root motion is used here,
which is one of only two places it is permitted.

## Acceptance criteria

- [ ] Vault: 0.55 s, obstacles up to 1.1 m, zero suspicion cost.
- [ ] Mantle: 0.95 s, obstacles 1.1 to 2.3 m, climb-rate suspicion for its duration.
- [ ] Both use root motion for exact hand and foot placement.
- [ ] Both are interruptible by COMBAT-priority transitions.
- [ ] Durations match their tunables exactly.

## Test notes

`test_anim_durations_match_tunables.gd` covers the durations.
`test_root_motion_policy.gd` asserts root motion appears only on traversal clips.

## Notes

Vault costing zero suspicion is deliberate — it is the only free athletic move and the backbone
of ground-level route-finding. Chained vaults are geometry-limited; watch telemetry in case
vault-chaining becomes a dominant travel mode.
