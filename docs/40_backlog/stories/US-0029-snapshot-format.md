---
id: US-0029
title: Snapshot format and serialisation
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-04-NET, BIBLE-NET-PROTOCOL]
---

# US-0029 — Snapshot format and serialisation

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-SNAPSHOT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0028 |

## Description

The binary snapshot layout and its serialise/deserialise pair, plus quantisation helpers.

## Acceptance criteria

- [ ] Layout matches NETWORK_PROTOCOL.md section 4 exactly.
- [ ] Position quantised to 1 cm as 3x i16 map-local; yaw to 1 degree as u8.
- [ ] Remote pawn record is 14 bytes; NPC record is 7 bytes including index.
- [ ] Round-trip serialise then deserialise is lossless within quantisation.
- [ ] The snapshot contains NO persona, exact position, elevation or tier for the contract.
- [ ] render_state is a 2-bit per-observer field.

## Test notes

`test_payload_omissions.gd` asserts the absent fields are genuinely absent.
`test_snapshot_size.gd` measures the worst case against the downstream budget.

## Notes

The information rules are enforced in the wire format, not the UI. A rule that lives in a widget
can be broken by a different widget; a rule that lives in the protocol cannot be broken at all.
