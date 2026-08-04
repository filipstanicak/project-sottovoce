---
id: US-0083
title: Accessibility — palettes and captions
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [BIBLE-UI-UX, GDD-02-PLAYER]
---

# US-0083 — Accessibility: palettes and captions

| | |
|---|---|
| **Milestone** | M6 |
| **Epic** | `EPIC-ACCESS` |
| **Systems** | `SYS-HUD`, `SYS-AUDIO` |
| **Estimate** | M |
| **Depends on** | US-0082 |

## Description

Four colour palettes and a full caption track.

## Acceptance criteria

- [ ] Four palettes: default, deuteranopia, protanopia, monochrome.
- [ ] NO widget names a colour literal; all come from the Palette resource.
- [ ] The four persona identity hues differ in VALUE as well as hue, spanning 30 to 78 percent.
- [ ] All three tiers are distinguishable in the monochrome palette.
- [ ] The Compass encodes NOTHING in hue.
- [ ] Every audio event flagged captioned has a caption string.
- [ ] Captions render positionally where the sound is positional, and CENTRED for the prey warning.
- [ ] A deaf player loses no Compass information — the visual pulse is the primary channel.

## Test notes

`test_no_colour_literals.gd`, `test_tier_monochrome.gd`, `test_captions_for_flagged_events.gd`.

## Notes

The monochrome column is the real test. Four hues spanning 30 to 78 percent value are
distinguishable by brightness alone, which means the identity channel never depends on hue
discrimination.

Silhouette identification at 40 m was a design requirement before it was an accessibility one,
and it happens to solve both.
