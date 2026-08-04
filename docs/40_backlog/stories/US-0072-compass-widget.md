---
id: US-0072
title: HUD — Compass widget
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [BIBLE-UI-UX, TDD-11-UI, ADR-0006]
---

# US-0072 — HUD: Compass widget

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-HUD` |
| **Systems** | `SYS-HUD`, `SYS-COMPASS` |
| **Estimate** | M |
| **Depends on** | US-0065 |

## Description

The game's central instrument: CompassVM plus CompassWidget.

## Acceptance criteria

- [ ] Renders a CONE with soft gradient edges — never a hard-edged needle.
- [ ] 220 px, centre-bottom, 64 px from the edge.
- [ ] Pulse phase advances at DISPLAY rate; period comes from the 30 Hz authoritative distance.
- [ ] Ring scale eases OUT; ring alpha eases IN — the onset is the sharp event.
- [ ] Lock arc fills clockwise.
- [ ] Emits EVT-COMPASS-PULSED for audio to subscribe to.
- [ ] NEVER shows a numeric distance.
- [ ] CompassVM holds NO world position, applies NO wobble, performs NO extrapolation.
- [ ] Encodes nothing in hue: distance is cadence, direction is position, lock is arc fill.

## Test notes

`test_compass_vm.gd` asserts the period against the sampled table at every listed distance.
`test_compass_no_wobble_clientside.gd`, `test_compass_no_position.gd`.

## Notes

Ease-out on scale with ease-in on alpha means the ring expands fast and fades slow, so ONSET is
the sharp event. Onset is what peripheral vision detects; a symmetrical pulse reads as a throb
and cadence becomes much harder to judge.

The protocol prevents leaks; these widget prohibitions prevent INVENTION.
