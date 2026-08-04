---
id: US-0076
title: Reactive music stems
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [BIBLE-AUDIO, GDD-06-UI-AUDIO]
---

# US-0076 — Reactive music stems

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-AUDIO` |
| **Systems** | `SYS-MUSIC` |
| **Estimate** | S |
| **Depends on** | US-0075 |

## Description

Four always-playing stems cross-faded by state. A stem system rather than a cue system, because
the driving state can change several times in ten seconds.

## Acceptance criteria

- [ ] Four stems: base, noticed, exposed, final phase.
- [ ] Cross-fade 0.8 s in, 1.6 s out — fast to arrive, slow to leave.
- [ ] Constant tempo and key; 32-bar sample-aligned loops.
- [ ] Keyed ONLY to own suspicion tier and match phase.
- [ ] NOT keyed to compass proximity, other players, kills elsewhere, or being hunted.
- [ ] Fully mutable.
- [ ] The exposed motif appears in exactly three places across the whole game.

## Test notes

A source scan of the music controller must find no reference to another player's state.

## Notes

Keying music to being hunted was tempting and rejected: it would be a permanent, free,
directionless proximity sensor, gutting the 15 m prey warning.

Music reacts to your own tier and the match phase. Both are things you already know.

Build base, exposed and final phase first. The noticed stem is deliberately barely audible and
may not be worth building at all.
