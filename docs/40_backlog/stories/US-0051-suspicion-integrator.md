---
id: US-0051
title: Suspicion integrator
version: 0.1.0
status: done
owner: Technical Director
last_updated: 2026-08-21
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

- [x] Pure Core function of state, tuning and dt.
- [x] Gain and decay are MUTUALLY EXCLUSIVE — no concurrent decay above stroll speed.
- [x] Continuous sources sum additively: run, sprint, climb, roof, open-ground.
- [x] Decay applies only at or below stroll speed AND after the 0.6 s post-gain delay.
- [x] Stillness passive multiplies decay while stationary.
- [x] Blending overrides both with a linear crush toward zero.
- [x] Clamped to 0 to 100.
- [x] Tier entered at threshold, exited 5 points below.

## Test notes

`test_suspicion_math.gd` reproduces the GDD-03 section 3.5 worked 45-second timeline to within
0.1 points at every listed timestamp.
`test_suspicion_tapsprint.gd` asserts 4 Hz sprint-stroll alternation yields HIGHER suspicion per
metre than continuous running.
`test_suspicion_hysteresis.gd` asserts no tier oscillates faster than 1 Hz.

## Notes

Mutual exclusion is not a micro-optimisation: with concurrent decay, a cheap gain against -8/s
would be net NEGATIVE and the entire speed ladder would invert.

Without the decay delay, tap-sprinting at 4 Hz nets +8.5/s while averaging 4.2 m/s — better than
running. The delay makes stop-start strictly worse than committing.

## What it cost, 2026-08-21

**EIGHT OF EIGHT, AND TWO FINDINGS AGAINST THE DESIGN DOCUMENTS.**

**THE TAP-SPRINT EXPLOIT IS NOT CLOSED, AND THE NUMBER IS 4.3 %.** Measured in suspicion **per
metre**, which is what a player actually spends to cross the district: 2.024 without the delay,
**2.976 with it, against a run's 3.111**. The delay adds 47 % and leaves stop-start **cheaper
than committing**. Closing the rest needs `TUN-SUSPICION-GAIN-SPRINT` at 26.1 rather than 25.0 —
inside its own 20–32 band, and a `TUN-` change is the owner's — **or** the speed ladder already
closes it, because a real pawn cannot alternate at 4 Hz through `TUN-SPEED-RUN-RESOLVE` and the
sprint double-tap. That second half is **unverified**: this test drives `speed_state` directly.
Reported as `pending`, like `test_spawn_points.gd`'s seat census.

**AND THE COUNTERFACTUAL CAUGHT THE PRIMARY TEST MEASURING THE WRONG THING.** The first version
ran for twelve seconds; both patterns saturate at `TUN-SUSPICION-MAX` in that time, so
`value / metres` collapses to `100 / metres` — a comparison of **distances**, which tap-sprinting
"wins" purely by being slower. It passed. The counterfactual — defeat the delay and the exploit
must reappear — is what failed, because the saturated measurement could not see the exploit
either way. Two seconds, and an assertion that neither pattern reaches 90 % of the ceiling.

**GDD-03 §3.5's WORKED TIMELINE CANNOT BE REPRODUCED AND IS NOT.** The test note asks for it to
0.1 points; it is driven by a **jog at +4/s** and `TUN-SUSPICION-GAIN-JOG` is deprecated with no
successor, along with the rung. On the current ladder the same actions reach **Exposed at 7.9 s**
rather than brushing Noticed, which inverts what the example teaches. Re-authoring it is design
prose and is the owner's. The integrator is tested against §3.3 instead.

**AND `evaluate_tier` AMENDS TDD-07 §2.3's SKETCH**: a rise may skip a rung, a fall may not.
A stunned player is forced to 100 outright, and a rule that forces a tier is not kept if it lands
a tick late. Nothing forces a tier downward, so the descent still passes through.
