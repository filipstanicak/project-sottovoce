---
id: US-0074
title: HUD — score feed
version: 0.2.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-28
depends_on: [GDD-06-UI-AUDIO, TDD-11-UI]
---

# US-0074 — HUD: score feed

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-HUD` |
| **Systems** | `SYS-SCOREFEED` |
| **Estimate** | S |
| **Depends on** | US-0073 |

## Description

The game's teacher: named bonuses arriving as a readable sequence at the instant they are earned.

## Acceptance criteria

- [x] Shows bonus NAMES, not just values.
- [x] Bonuses from one kill stagger by 0.12 s.
- [x] At most four simultaneous lines; each persists 4.0 s, raisable to 8 s.
- [x] Penalties use a visually DISTINCT treatment.
- [x] Tabular numerals so values do not reflow as digits change.
- [x] Right side above centre — readable WITHOUT being looked at.
- [x] Subscribes to EVT-SCORE-EVENT-APPENDED; never polls a total.
- [x] Shows only the local player's events. NO global kill feed.

## Test notes

`test_scorefeed_stagger.gd`, `test_scorefeed_cap.gd`, `test_score_wire.gd`,
`test_score_courier.gd`, `test_bonus_names_exist.gd`, `test_no_global_score_feed.gd`.

## What was built, and what it cost

**`NET-S2C-SCORE-EVENT` DID NOT EXIST AND THIS STORY IS INERT WITHOUT IT.** The bus signal
`EVT-SCORE-EVENT-APPENDED` was declared at M0 with no emitter, and no story claimed the wire
message. It is built here: `ScoreWire` owns the catalogue's sixteen-byte row, `MatchAnnouncer`
addresses it, `HudBridge` forwards it, and `ScoreFeedVm` queues it.

**THE COURIER IS A CURSOR OVER THE LOG RATHER THAN A HOOK ON EACH APPEND.** Two systems append
today — the kill and the stun — and ADR-0014's escape will be a third. A courier wired to each
call site is a list that goes stale in silence, and the symptom is one bonus that stopped
reaching the feed. `ScoreLog.tail(index)` is the seam.

**AND THE RECIPIENT IS A FIELD OF THE EVENT, WHICH IS WHAT MAKES NEVER-DO #12 STRUCTURAL.**
Every other S2C message takes a recipient list its caller assembled; this one takes
`ScoreEvent.actor_id`, so there is no list to widen by accident.

**`SCORE-DEATH` IS THE ONE KIND WITHHELD, FOR TWO REASONS THAT AGREE.** It pays nothing, so a
feed whose question is *"what did I just get paid for?"* has nothing to draw — and it is the
**only** score event whose `subject` names somebody the recipient has not earned:
`ScoreLog.mark_death` records the victim as actor and the *killer* as subject.
`NET-S2C-KILL-RESULT` is the message designed to tell a victim who killed them; a second channel
for the same fact is one nobody would think to audit.

**THE ROW IS HAND-PACKED, AND `gdlint` IS WHAT DECIDED THAT.** Eight loose RPC arguments exceeded
`.gdlintrc`'s six-argument cap, which the file itself calls *"a design signal, not a style
preference"*. It was right twice over: Godot Variant-encodes loose arguments (US-0095 measured
`NET-C2S-INPUT` at **56 bytes against a budgeted 9** that way), and eight positional integers in
which transposing `actor` and `subject` is invisible is exactly the shape `ScoreAward` was
extracted to avoid in US-0064.

**THREE BONUSES HAD NO NAME AND NOTHING CHECKED.** `SCORE-HALFSEEN` (2026-08-27, the fidelity
re-audit) and `SCORE-ESCAPE`/`SCORE-CLOSECALL` (2026-08-26, ADR-0014) had no row in
`data/strings/en.csv` — fourteen of seventeen, which is exactly the shape of a table that looks
complete. `test_bonus_names_exist.gd` harvests the ids from `Ids` and refuses a kind with no
name; the display key is **derived** (`SCORE-FROMABOVE` → `bonus.fromabove`) rather than
tabulated, so a second seventeen-row list cannot drift from the first.

**AND THE PENALTY TREATMENT HAS NO PRODUCER.** ADR-0013 took `TUN-SCORE-RECKLESS` to **zero**,
so no shipped bonus pays below zero and §5.2's penalty treatment is built and dormant. It is
reachable only through `tools/hud_probe.tscn`'s frame 14, which says so.

## What looking at it changed

Run windowed after any change here:

```
godot --path . res://tools/hud_probe.tscn
```

Three defects no test in this repo could have found:

- **The blocks touched.** A block was exactly as tall as its own two rows, so four bonuses read
  as one eight-row ladder rather than as four things — and the penalty plate, which is padded,
  drew straight over the line above it.
- **The name was drawn dim and the value bright**, which is the wrong way round for an element
  whose stated purpose is that *the name is the lesson*. The value keeps its dominance by
  **size**, which is a channel a colourblind palette cannot undo.
- **Only the penalty had a plate.** §5.2 prices a penalty as *"different plate, different
  weight"* — which says every line has one. White text over the district's pale sky is at the
  edge of legible at the fovea and gone in the periphery, and this element must be read without
  being looked at.

## Open

Nothing. Two things this story deliberately did not do:

- **The ascending sting** (`SFX-SCORE-BONUS-LARGE` pitching up per position in the stack) needs
  `Audio.play()`, which is a stub until US-0075. The stagger it rides is built and tested.
- **`TUN-UI-SCOREFEED-DURATION` raisable to 8 s** is read from the tuning every time a line is
  queued, so the accessibility option is a `.tres` value away. The options screen is US-0083's.
