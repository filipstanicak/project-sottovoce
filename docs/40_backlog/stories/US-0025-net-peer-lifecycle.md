---
id: US-0025
title: Net autoload and peer lifecycle
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0002, TDD-04-NET, BIBLE-NET-PROTOCOL]
---

# US-0025 — Net autoload and peer lifecycle

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-TRANSPORT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0024 |

## Description

ENetMultiplayerPeer setup, the three channels, peer join and leave, RTT measurement, and the
handshake.

## Acceptance criteria

- [ ] Server creates on port 27015 by default, max 6 peers.
- [ ] Three channels: STATE unreliable, EVENT reliable ordered, SESSION reliable ordered.
- [ ] NET-C2S-HELLO validates protocol version and build hash; mismatch rejects with a reason.
- [ ] NET-S2C-WELCOME returns peer id, tuning hash, map id and phase.
- [ ] Tuning hash mismatch triggers NET-S2C-TUNING-SYNC; the client is CORRECTED, never kicked.
- [ ] Peer timeout at 10 s is treated as a disconnect.
- [ ] Ping and pong maintain per-peer RTT.

## Test notes

`test_channel_separation.gd` asserts a reliable flood does not delay snapshot delivery.

## Notes

The channel split matters most under packet loss. Without it a retransmitted score event would
delay every subsequent snapshot, and the symptom would be remote players stuttering whenever
anyone scored — a networking bug that looks like a gameplay bug.
