---
id: US-0026
title: RpcRouter and authority checks
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0002, TDD-04-NET, BIBLE-NET-PROTOCOL]
---

# US-0026 — RpcRouter and authority checks

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-TRANSPORT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0025 |

## Description

The single validation chokepoint for every inbound client message. No client message reaches a
system without passing through it.

## Acceptance criteria

- [ ] Every C2S handler calls `_authorise` FIRST, with no path around it.
- [ ] Every C2S message in NETWORK_PROTOCOL.md section 2 has a non-empty authority check.
- [ ] Input applies to the SENDER's pawn, looked up from the peer id — never from the payload.
- [ ] Stale or replayed sequence numbers are dropped.
- [ ] Lobby-only messages are rejected outside the LOBBY phase.
- [ ] Rejections log with peer id and reason.

## Test notes

`test_no_client_authority.gd` is a source scan: no @rpc handler writes system state without
passing _authorise. `test_client_cannot_assert_outcome.gd` parses the message catalogue for
outcome fields.

## Notes

There is no NET-C2S-KILL and no NET-C2S-STUN. Kill and stun are BUTTONS in the input bitfield.
A client cannot express "I killed someone" in this protocol — that is what lets the scope fence
defer all anti-cheat beyond server authority.
