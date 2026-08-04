---
id: US-0085
title: Onboarding minimum — speed coach and death card
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-08-FUTURE, GDD-06-UI-AUDIO]
---

# US-0085 — Onboarding minimum: speed coach and death card

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-ACCESS` |
| **Systems** | `SYS-HUD` |
| **Estimate** | S |
| **Depends on** | US-0084 |

## Description

The two cheapest onboarding interventions: a first-match speed coach and a minimal death card.

A new player's instincts are precisely inverted — sprinting is what other games taught them, and
here it reaches Noticed in 1.2 s.

## Acceptance criteria

- [ ] The first THREE times a new player crosses into Noticed by sprinting, one non-modal line appears.
- [ ] The coach disables permanently after three firings or one match. It is NOT a tutorial.
- [ ] On death, a card shows three facts: your tier at death, your killer's name, and whether they were ANONYMOUS when they initiated.
- [ ] The death card shows NO position, NO replay, NO camera.
- [ ] Results screen shows time spent Anonymous per player, winner highlighted.

## Test notes

Measured against the onboarding target: a new player's THIRD match should contain at least one
kill scoring 350 or more.

## Notes

The third fact on the death card is the lesson: "they were Anonymous — you could not have seen
them, and that is what you should learn to do."

The death card is deliberately the minimum information that makes death legible without becoming
a kill-cam. Position and replay are the bright line; crossing it requires an ADR.

No progression, deliberately. The session's reward is getting better.
