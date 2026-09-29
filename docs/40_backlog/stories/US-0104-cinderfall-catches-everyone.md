---
id: US-0104
title: Cinderfall catches everyone in it, and the caster may kill there
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-09-25
depends_on: [ADR-0023, GDD-04-ABILITIES, US-0067]
---

# US-0104 — Cinderfall catches everyone in it, and the caster may kill there

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-ABILITIES` |
| **Systems** | `SYS-ABILITY`, `SYS-KILL`, `SYS-STUN`, `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | ADR-0023 (accepted), US-0067 (the cloud exists) |

## Description

**Owner decision, 2026-09-25: *"Bitte wie es im Original ist umändern."*** A recorded reference
match shows the ability used three times as an ambush: burst, then a kill inside the cloud. One
of those kills paid the top stealth rung. Our cloud forbids exactly that. ADR-0023 records the
rule. This story builds it and rewrites GDD-04 §3.1 in the same commit.

## Acceptance criteria

- [ ] **The cloud catches everyone in `TUN-CINDERFALL-RADIUS` except the caster, for as long
      as it stands**: anyone there at the burst and anyone who walks in afterwards. A caught
      figure coughs until the cloud ends, with no movement, kill, stun or cast, and can be
      killed.
- [ ] **NPCs in the radius are caught too**, with the same visible reaction, so the cloud does
      not name the players inside it (clone parity, GDD-03 §6.5).
- [ ] **A caught pursuer of the caster counts as stunned by the caster.** `SCORE-STUN`, the
      contract loss (ADR-0019), and every consequence a pressed stun has.
- [ ] `TUN-CINDERFALL-BLOCKS-KILL` → false and `TUN-CINDERFALL-BLOCKS-LOS` → false, neutralised
      rather than removed. **A kill initiated by the caster inside their own cloud lands**, as a
      test at the system's seam.
- [ ] `TUN-CINDERFALL-SUSPICION` → 0.
- [ ] Invariant 12 keeps its inequality with its new reason (catch somebody standing at kill
      range).
- [ ] GDD-04 §3.1, §3.5 and the §7 pair audit are rewritten. TUNABLES rows, TDD-09 and the
      CLAUDE.md state row say the new rule.

## Test notes

Falsify each rule by planting its opposite, one at a time, against the suite that owns it: the
flag back to true, the caster caught by their own burst, an NPC left out, a caught pursuer not
paid.

## Open (ADR-0023 C, the owner's)

`TUN-CINDERFALL-DURATION` 6.0 s is now how long a caught figure is held, longer than a pressed
stun (4 s). The reference's cloud lasts about 4 s. Left at 6.0 until the owner decides.
