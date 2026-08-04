---
id: US-0047
title: Clone local-minimum rebalancing
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-08-CROWD, GDD-03-SOCIAL-STEALTH]
---

# US-0047 — Clone local-minimum rebalancing

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-ANONYMITY` |
| **Systems** | `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0046 |

## Description

The director maintains at least two clones of each in-use persona within 25 m of every player,
by re-routing existing clones.

## Acceptance criteria

- [ ] Runs on the 2 s director timer, never per tick.
- [ ] Re-ROUTES existing clones; never respawns or re-personas them.
- [ ] Retargets the nearest idle clone toward an under-served region.
- [ ] Over a 3-minute clustered match, every player always had at least 2 same-persona clones within 25 m.
- [ ] Re-routing does not read as clones following players.

## Test notes

`test_clone_local_min.gd` runs a 3-minute headless match with players deliberately clustered in
one zone.

## Notes

This is the layer that actually matters. Layers 1 to 3 catch authoring mistakes, which are
visible in review. This catches the invisible failure: all twelve Lucerna clones drift to the
north plaza, the Lucerna player in the south market is now unique, every rule still works, the
crowd count is still 78, nothing is broken — and they are simply, silently, findable.

Deliberately slow, because visible re-routing is itself an information leak: a stream of Lucerna
suddenly walking toward a market says a Lucerna player is there.
