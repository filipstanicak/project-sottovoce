---
id: US-0023
title: Crowd-scan input
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-02-PLAYER]
---

# US-0023 — Crowd-scan input

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-CAMERA` |
| **Systems** | `SYS-CAMERA` |
| **Estimate** | S |
| **Depends on** | US-0022 |

## Description

The held crowd-scan input: slower look sensitivity, narrower FOV, capped movement.

Reading the crowd is the game's central act, so it gets its own button rather than being an
emergent consequence of standing still.

## Acceptance criteria

- [ ] Look sensitivity multiplied by 0.45 while held.
- [ ] FOV narrows to 48 degrees — narrower than any speed state.
- [ ] Movement capped at blend-walk speed.
- [ ] Ambience ducked slightly; footstep sources sharpened.
- [ ] Grants NO mechanical advantage: no reveal, no highlight, no tag.
- [ ] Available as hold or toggle.

## Test notes

Verify no gameplay state changes while scanning.

## Notes

Crowd-scan is the game's aim-down-sights and deliberately grants nothing mechanical. It grants
slower, closer, quieter looking — the advantage is entirely in the player's own perception. This
is the clearest single statement of what kind of game this is.
