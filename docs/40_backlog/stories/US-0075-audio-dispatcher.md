---
id: US-0075
title: Audio dispatcher, buses and event map
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [BIBLE-AUDIO, GDD-06-UI-AUDIO]
---

# US-0075 — Audio dispatcher, buses and event map

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-AUDIO` |
| **Systems** | `SYS-AUDIO` |
| **Estimate** | M |
| **Depends on** | US-0074 |

## Description

The SFX-ID-to-bus mapping, ducking priority, occlusion, and captions.

## Acceptance criteria

- [ ] Four buses: INFO, AMBIENCE, MUSIC, UI.
- [ ] BUS-INFO CANNOT be muted; its slider floors at -12 dB.
- [ ] Ducking follows the documented priority; the prey sting is the only sound ducking other information.
- [ ] Every event flagged captioned emits EVT-CAPTION on the SAME FRAME.
- [ ] No captioned event is routed to an atmosphere bus.
- [ ] The prey sting is mono and centred, with NO 3D emitter.
- [ ] Player and NPC footsteps use identical clips and radii per speed.
- [ ] Occlusion low-passes at 900 Hz with -6 dB; NPCs never occlude audio.
- [ ] With ambience and music muted, NO gameplay information is lost.

## Test notes

`test_prey_sting_nonpositional.gd`, `test_footstep_parity.gd`,
`test_no_captioned_events_on_atmosphere_buses.gd`, `test_captions_for_flagged_events.gd`.

## Notes

Attaching an AudioStreamPlayer3D instead of an AudioStreamPlayer is a one-word mistake that
silently deletes a core design property. Hence the dedicated test.

Footstep parity is an anonymity leak exactly equivalent to the animation one, and just as
invisible to review.
