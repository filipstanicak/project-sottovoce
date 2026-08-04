---
id: US-0048
title: M3 gate — crowd performance and anonymity
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [BACKLOG-ROADMAP, BIBLE-PERF-BUDGET, BIBLE-RISK-REGISTER]
---

# US-0048 — M3 gate: crowd performance and anonymity

| | |
|---|---|
| **Milestone** | M3 |
| **Epic** | `EPIC-ANONYMITY` |
| **Systems** | `SYS-CROWD`, `SYS-NPC-AI` |
| **Estimate** | S |
| **Depends on** | US-0047 |

## Description

Run and log the M3 exit verification. The hardest gate in the project.

## Acceptance criteria

- [ ] `test_crowd_perf.gd` passes with 90 NPCs on the reference machine, in the standard scenario.
- [ ] p99 client frame time at or under 16.6 ms with peak crowd density.
- [ ] Server tick p99 at or under 8.0 ms.
- [ ] `test_crowd_bandwidth.gd` within 96 kbit/s down.
- [ ] `test_clone_animation_parity.gd` and `test_footstep_parity.gd` pass for all four personas.
- [ ] `test_clone_local_min.gd` passes over a clustered 3-minute match.
- [ ] Startle waves read directionally to a human observer.
- [ ] Feel check: the crowd feels alive — a tester still looks at NPCs unprompted after minute 4.
- [ ] Risk register re-scored: RISK-CROWD-PERF, RISK-ANONYMITY-LEAK, RISK-ANIM-SCOPE.
- [ ] Tag `m3-crowd` pushed.

## Test notes

If the crowd budget is missed, work the fallback ladder in PERFORMANCE_BUDGET section 6 IN ORDER.
Reducing crowd count is last, and never below 60.

## Notes

The 0.10 ms crowd margin is the tightest in the corpus. This gate is where the project's largest
unvalidated assumption — GDScript performance across 90 agents — is first measured.
