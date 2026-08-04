---
id: US-0084
title: Accessibility — input and motion
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-02-PLAYER, BIBLE-UI-UX]
---

# US-0084 — Accessibility: input and motion

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-ACCESS` |
| **Systems** | `SYS-INPUT`, `SYS-CAMERA` |
| **Estimate** | S |
| **Depends on** | US-0083 |

## Description

Hold-versus-toggle for every hold input, full rebinding, adjustable buffers, and motion-reduction
mode.

## Acceptance criteria

- [ ] Every hold input has an individually configurable toggle mode.
- [ ] Every action rebindable except the menu key.
- [ ] A single-input alternative exists for the two-input gamepad sprint.
- [ ] Input buffers may be RAISED to 0.4 s, never lowered.
- [ ] Motion reduction locks FOV, reduces bob, removes speed lines, damps the Compass ring scale while PRESERVING cadence.
- [ ] Motion reduction ADDS a persistent speed-state indicator to compensate for the lost FOV channel.
- [ ] The trade-off is stated to the player in the options screen.
- [ ] Camera shake fully disableable; no gameplay information is ever carried by shake.
- [ ] Reduced crowd density is NOT offered.

## Test notes

Manual verification. Confirm a motion-reduction player can still judge their own speed state.

## Notes

Raising input buffers is a pure accessibility gain with no competitive advantage, because they
only affect whether YOUR OWN input registers.

Reduced crowd density is the one accessibility request refused: density is gameplay, and reducing
it would grant a competitive advantage by making players easier to pick out. Performance-driven
reduction is handled by fidelity LOD instead, never by count.
