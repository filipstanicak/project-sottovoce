---
id: US-0036
title: Headless 3-client integration harness
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [BIBLE-TEST-PLAN, TDD-12-BUILD]
---

# US-0036 — Headless 3-client integration harness

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | — |
| **Estimate** | M |
| **Depends on** | US-0035 |

## Description

Spawn a real server and three real clients in-process and drive them with scripted input,
exercising the actual netcode rather than a mock.

## Acceptance criteria

- [ ] `IntegrationHarness` provides start, drive, advance_ticks, simulate_latency, assert_all_peers_agree.
- [ ] Four latency profiles: LAN, Good, Typical, Poor.
- [ ] Every netcode test runs at all four.
- [ ] Suite completes in at most 180 s.
- [ ] Runs headless in CI on pull requests.

## Test notes

`test_frame_rate_independence.gd` runs a match at 30, 60 and 144 fps client display rates and
asserts identical gameplay state. It is the direct proof that putting all gameplay on the net
tick actually holds.

## Notes

A mock cannot surface prediction bugs, because the bug IS the difference between two real
implementations of the same step function.
