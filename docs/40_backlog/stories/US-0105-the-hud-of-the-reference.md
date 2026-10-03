---
id: US-0105
title: The HUD shows what the reference shows
version: 0.1.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-09-29
depends_on: [ADR-0024, GDD-06-UI-AUDIO, US-0073]
---

# US-0105 — The HUD shows what the reference shows

| | |
|---|---|
| **Milestone** | M5 (the parts that need player names: M6) |
| **Epic** | `EPIC-HUD` |
| **Systems** | `SYS-COMPASS`, `SYS-SCORE`, `SYS-NET-*` |
| **Estimate** | L — several PRs, in the dependency order below |
| **Depends on** | ADR-0024 (accepted); US-0078 for names; US-0106 (owner decision 14, settled by ADR-0025) and owner decision 15 for two lines |

## Description

**Owner decision, 2026-09-25: *"Bleiben dem Original so treu wie möglich."*** ADR-0024 lifts the
global kill feed, player names in the HUD and a permanent own placement from never-do #12, and
lists what the reference's HUD shows that ours does not. This story builds it.

## Acceptance criteria

- [x] **The Compass lies at the character's feet** (owner, 2026-09-25), **as the reference means it**:
      a flat ring at a fixed spot round the legs, centred at 80 % of the frame's height, with the
      chase ring on the same ground. The reference's ring circles the legs at knee-to-thigh height
      (about 40 % of the figure above the feet; ours about 30 %), and the owner kept that spot on
      2026-09-29 when the review of #243 found the words said *feet*. **The camera framing was checked first**, as ADR-0024 asked, and moved:
      `TUN-CAM-REST-PITCH` −13° (owner, 2026-09-29), so the feet are in frame to sit on.
- [x] **The Compass says up or down** when the contract is above or below the hunter, and
      **glows while the contract is in sight**. PR 2, `PROTOCOL_VERSION` 6.
- [x] **One-line notices**: a new pursuer on you, and you take the lead. Strings in the table.
      PR 3, `NET-S2C-NOTICE`, `PROTOCOL_VERSION` 7.
- [ ] **Your own placement** is always on screen, with **one icon per pursuer** beneath it
      (always one until owner decision 15).
- [ ] **The contract's placement** beside the portrait. Needs every player's score on the wire,
      as a new message with a `PROTOCOL_VERSION` bump.
- [ ] **A global kill feed**, *"A killed B"* and *"A joined"*, for every player. Blocked on
      player names (US-0078).
- [ ] **The contract's player name** beside the portrait and on the assignment card. Blocked on
      names.
- [ ] **A death card**: the killer's name, the points your death paid them, and the bonuses they
      earned for it. `test_no_global_score_feed.gd` is amended for that one kill, citing ADR-0024.
- [ ] *"Your pursuer killed a civilian"*, once owner decision 14 makes a wrong kill possible.
      *Decision 14 settled 2026-10-02 (ADR-0025): the line is built by US-0106.*

## As built

- **PR 1 (2026-09-29): the framing and the ring.** Measured from the client, not reasoned: a level
  view put the head at 42 % and the feet below the frame; at −13° they sit at about 97 % and the
  horizon at about 33 %, against the reference's ~95 % and ~30 %. The figure is still somewhat
  larger than the reference's (≈ 55 % of the height against ≈ 45 %); the arm length was left alone
  by the owner's choice. `CompassWidget.place` and `ground_scale` are the one source of the ring's
  spot and shape. `tools/hud_probe.gd`'s two direction diagnostics had drawn a whole ring since
  2026-08-27 (10 m, inside the full-ring radius) and use 55 m now.
- **PR 2 (2026-09-29): up, down and in sight.** Three bits in the byte `portrait_revealed` had to
  itself, so the snapshot is no bigger and every frozen fixture still reads the same; the meaning
  changed, so `PROTOCOL_VERSION` 6. *Up* is `TUN-COMPASS-VERTICAL-THRESHOLD` 2.0 m — above a stall
  (0.9 m), below the balcony (3.5 m); **ours, not sourced**. *In sight* is the chase's own sight
  (`PursuitTracker.geometry` and the clear line already cast), so it costs no raycast and cannot
  disagree with the chase bar. The widget draws a chevron and fills the disc, and the word is
  `CompassWordWidget`'s — `test_compass_invents_nothing.gd` keeps `CompassWidget` free of text, and
  the word widget can only draw one of two string-table words; `tools/compass_probe.tscn` captures all four states, and the Compass's direction frames
  moved there from `hud_probe`, which had reached the length limit.
- **PR 3 (2026-09-30): the one-line notices.** `NET-S2C-NOTICE` carries a `NoticeWire.Kind` and nothing
  else, to the one player it is about. *A new pursuer* rides `MatchAnnouncer.contract_issued` — the prey of
  every newly announced contract, **except the countdown's first deal**, where everybody gets one at once.
  *You have taken the lead* rides the score flush: `ScoreLead` announces the new **sole** top scorer above
  zero among the players still here, only when points were paid — so a leader who leaves hands nobody the
  lead. *Points, not rows*: the review of #245 found a zero-point event (the death marker) passing the
  first gate, and that sequence is a test now. `NoticeVm` shows one at a time for `TUN-UI-NOTICE-DURATION` 3.0 s (**ours**; the reference gives no
  figure) and queues a second rather than replacing it. Drawn where the reference draws it, measured: y 475
  of 720 in both.

## Open (ADR-0024)

The death camera (framed on the killer, as the reference's is?) and the death card's
one-line hint, *how you were caught*.
