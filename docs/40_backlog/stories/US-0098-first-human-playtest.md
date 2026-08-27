---
id: US-0098
title: The first human playtest — six players, three matches, twelve questions
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [ADR-0016, BIBLE-TEST-PLAN, BACKLOG-ROADMAP]
---

# US-0098 — The first human playtest

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-PLAYTEST` |
| **Systems** | all |
| **Estimate** | M |
| **Depends on** | US-0079 (a match), US-0078 (a lobby), US-0074 (the score feed), US-0080 (telemetry) |

## Description

**Six humans, three consecutive matches, the twelve questions.** This is the half of the old
M4 gate that needs people, split out by [`ADR-0016`](../../00_meta/adr/ADR-0016-split-the-m4-gate.md)
because it could not run at M4 and running it anyway would have measured the wrong thing.

**This is still the hinge of the project.** Splitting it changed *when* it happens, not how much
rests on it — and the ADR records the cost plainly: THE TURN, and with it `RISK-NOT-FUN-SOLO`,
is now first measurable two milestones later than planned.

## Why this exists as a separate story

The old US-0063 scored a playtest against a build with no match, no lobby, no HUD, no score and no
telemetry. Four of its questions are unanswerable without a score feed, two of its criteria read
telemetry with no emitter, and **Q7 — *"did you understand why you died"*, the single most
important question in TEST_PLAN §6.2 — would have scored near zero against a build that does not
tell a player they died.** A number that low, once recorded, gets quoted; and it would have been a
measurement of M5's absence rather than of the design.

**It runs before US-0088, not as part of it.** The M6 gate judges the MVP; this is evidence the M6
gate reads. If it is folded into US-0088 the first human contact with the game happens at the same
moment as the decision it should inform.

## Acceptance criteria

- [ ] Six humans play three consecutive matches, in one session, with a named facilitator.
- [ ] All twelve questions from TEST_PLAN §6.2 asked **individually and in writing** — never
      aloud in the group, because the first answer spoken shapes every answer after it — and
      logged to `docs/40_backlog/playtests/YYYY-MM-DD.md` using that directory's template.
- [ ] The telemetry export is attached and carries the tuning profile hash, so the session stays
      interpretable after values change. **`--record` must have a reader by then** — it is parsed
      into `LaunchConfig.record_path` and read by nothing today (US-0080).
- [ ] **THE TURN**: mean speed drops measurably between minute 1 and minute 4, read from
      `TEL-MEAN-SPEED` by match minute and confirmed by watching.
- [ ] Q7 *"did you understand why you died"* scores at least 4 of 5.
- [ ] Q12 *"would you play again tonight"* at least 70 percent yes.
- [ ] Q5 (best kill) rates **below** Q4 (realising you were followed).
- [ ] `TEL-FIRST-CONTACT-OUTCOME` below 40 percent correct identification.
- [ ] The full feel-regression checklist — all fourteen rows of TEST_PLAN §7.2 — run and logged
      by one named person. **Eleven of the fourteen were blocked at M4**; this is the first run
      where every row can be judged.
- [ ] `RISK-NOT-FUN-SOLO` re-scored against a real Q12, at four players and at six.

## Test notes

**If the turn does not happen, that is the most serious possible finding and no downstream work
should start until it is diagnosed.** That sentence is carried over from US-0063 unchanged and is
the reason this story exists rather than being folded into the M6 gate.

**A null result and an unmeasured result are different things.** At M4 the turn was *unmeasured* —
`TEL-MEAN-SPEED` had no emitter — and the M4 gate is evidence for neither outcome. Do not read it
as a partial result for this story.

**Q5 vs Q4 is an ordering, not two absolute values.** TEST_PLAN §11 open question 3 records why:
self-reported intensity is unreliable in magnitude and much more robust in rank.

## Notes

If Q5 exceeds Q4, hunting is beating being hunted and the emotional asymmetry the whole design is
tuned around has inverted. That is a design problem, not a tuning one.

**If `SYS-MATCH` (US-0079) moves to M5, this story should move with it.** A match is its only hard
blocker that M5 does not otherwise clear — ADR-0016's open question prices that move and leaves it
to the owner.
