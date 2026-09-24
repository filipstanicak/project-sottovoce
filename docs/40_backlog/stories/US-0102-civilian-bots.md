---
id: US-0102
title: The test bots walk the crowd's walk
version: 0.1.0
status: done
owner: Lead Game Designer
last_updated: 2026-09-24
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-08-CROWD]
---

# US-0102 — The test bots walk the crowd's walk

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-MATCHFLOW` |
| **Systems** | tooling only — `tools/bot_client.gd` |
| **Estimate** | M |
| **Depends on** | US-0101 |

## Description

**Asked from the controls on 2026-09-24:** *"Ihr Laufen ist momentan sehr linear und
einheitlich. Wird das für die Zukunft noch angepasst?"* Once the district was dressed
(US-0101) the portrait named a colour, and the bot was the one figure of it nobody had to look
at twice. **Identification cannot be tested alone against a target that identifies itself.**

This is a debug tool, not an opponent: SCOPE_FENCE OUT #14 keeps bots that play out of the MVP,
and nothing here plans, hunts or is exported. What it changes is how a *test target* walks —
by **behavioural parity**, the clone rule applied to movement: the bot makes the choices an NPC
makes, from the same sources, rather than trying to be clever.

## Acceptance criteria

- [x] A walking bot strolls to an idle anchor chosen uniformly over `MapData.idle_anchors`
      (`CrowdIntent._an_anchor`'s rule) along a path on the district's own committed navmesh,
      at blend-walk (`TUN-CROWD-NPC-SPEED-STROLL` by invariant 1), and stands on arrival for a
      duration drawn from `TUN-CROWD-IDLE-DURATION-MIN`..`-MAX` as `NpcBrain._enter` draws it.
      `test_bot_civilian.gd`.
- [x] A bot that cannot move while walking gives up on its anchor, and a bot turning in place
      is not counted as stuck.
- [x] `--census <seconds>` prints the crowd, the other players and the bot itself side by side
      on four numbers a watcher reads a walk by — speed while moving, share of time standing,
      stop length, turn rate — from drawn positions, so both groups pass through the same
      interpolation a hunter watches — the bot's own body included. `test_bot_census.gd` holds
      each number to a synthetic track whose answer is known, including a figure that left the
      view and came back, moving or standing.
- [x] `play.bat` and `sandbox.bat` bots walk this way by default; `--hunt` is unchanged.

## Test notes

**Measured on a live server, seed 42, three bots and a census bot, 120 s each** — remeasured
after review of #236 corrected the instrument (below):

| | moving | standing | stop | turning (median) |
|---|---|---|---|---|
| the crowd | 1.40 m/s | 33–35 % | 9.7–10.3 s | 0.06–0.07 rad/s |
| the old bots (`main`) | 1.39 m/s | 22 % | **1.1 s** | 0.05 rad/s |
| the civilian bots | 1.39 m/s | 28 % | **7.7 s** | **0.11 rad/s** |

**The speed was never the tell** — the old bot already held `input_slow`, and the first write-up
of this story said otherwise before it was measured. **The stops were**: the old bot only ever
paused to turn, where the crowd stands 8–25 s at a time. **And the civilian bot now turns more
than the crowd** — 0.11 against 0.07 rad/s — which the first census could not show: the look keys
sweep, so its corners are squarer than an agent's. It is the next thing to close, and it is said
here rather than tuned away.

**The review of #236 corrected the instrument twice, and both are why the table changed.** The
bot's own track was read from `PawnContext.position`, the unsmoothed simulation, while the other
two groups came off drawn nodes; `BotCensus.sample` now reads every group through `drawn()` and
takes the local body as a node, so the old read cannot be written. And a view gap did not end a
stop, so a figure standing on both sides of it was one long stop — planted, it reads **6.0 s**
for two stops of 3. Both have tests; both plants are red by name.

What the numbers cannot answer is the owner's eye at a windowed client — the Turing-test half of
this story, which stays with the next playtest.

## Notes

**Not copied, deliberately:** processions (`WALKING_GROUP`), startles and gawking are the
director's decisions about groups of NPCs, not a walk a lone figure makes. And a bot turns with
the pad's look keys rather than a mouse, so its corners are a little squarer than an agent's.
