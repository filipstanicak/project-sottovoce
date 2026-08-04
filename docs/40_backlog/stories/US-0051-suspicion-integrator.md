---
id: US-0051
title: Suspicion integrator
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-07-SUSPICION, TUN-INDEX]
---

# US-0051 — Suspicion integrator

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-SUSPICION` |
| **Systems** | `SYS-SUSPICION` |
| **Estimate** | M |
| **Depends on** | US-0050 |

## Description

`SuspicionMath.integrate` — the pure per-tick function, plus tier evaluation with hysteresis.

The highest-value unit-test target in the project after the contract cycle.

## Acceptance criteria

- [ ] Pure Core function of state, tuning and dt.
- [ ] Gain and decay are MUTUALLY EXCLUSIVE — no concurrent decay above stroll speed.
- [ ] Continuous sources sum additively: jog, run, sprint, climb, roof, open-ground.
- [ ] Decay applies only at or below stroll speed AND after the 0.6 s post-gain delay.
- [ ] Stillness passive multiplies decay while stationary.
- [ ] Blending overrides both with a linear crush toward zero.
- [ ] Clamped to 0 to 100.
- [ ] Tier entered at threshold, exited 5 points below.

## Test notes

`test_suspicion_math.gd` reproduces the GDD-03 section 3.5 worked 45-second timeline to within
0.1 points at every listed timestamp.
`test_suspicion_tapsprint.gd` asserts 4 Hz sprint-stroll alternation yields HIGHER suspicion per
metre than continuous running.
`test_suspicion_hysteresis.gd` asserts no tier oscillates faster than 1 Hz.

## Notes

Mutual exclusion is not a micro-optimisation: with concurrent decay, jog at +4/s against -8/s
would be net NEGATIVE and the entire speed ladder would invert.

Without the decay delay, tap-sprinting at 4 Hz nets +8.5/s while averaging 4.2 m/s — better than
running. The delay makes stop-start strictly worse than committing.
