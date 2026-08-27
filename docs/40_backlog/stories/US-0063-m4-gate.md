---
id: US-0063
title: M4 gate — the loop is playable
version: 0.2.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [BACKLOG-ROADMAP, BIBLE-TEST-PLAN]
---

# US-0063 — M4 gate: the loop is playable

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-COMBAT` |
| **Systems** | all M4 systems |
| **Estimate** | M |
| **Depends on** | US-0062 |

## Description

The first real playtest. **This is the hinge of the entire project.**

The loop must be interesting with NO abilities, NO scoring, NO HUD beyond a debug overlay and NO
audio. If it needs those to be fun, they are carrying a design that does not work — and finding
that out here costs one milestone rather than three.

---

## The gate was run on 2026-08-27, and its finding is about itself

**ONE OF TEN CRITERIA IS MET. SIX CANNOT BE RUN AT M4 BY CONSTRUCTION, AND THAT IS THE FINDING.**

This gate's criteria are scored against a *playtest*, and a playtest needs three things M4 does
not contain and was never scheduled to contain:

| Needed by this gate | Story | Milestone |
|---|---|---|
| A match — countdown, 8:00 clock, Final Contract, end, winner | `SYS-MATCH`, US-0079 | **M6** |
| A lobby — direct-IP join, ready-up, persona and loadout | US-0078 | **M6** |
| A HUD — Compass, tier, portrait, crosshair | US-0072, US-0073 | M5 |
| A score, so *"did you understand why you died"* has an answer | US-0064, US-0074 | M5 |
| `TEL-MEAN-SPEED`, `TEL-FIRST-CONTACT-OUTCOME` | US-0080 | **M6** |

**ROADMAP §1's M4 row reads *"the game is playable end-to-end"*, and M4's own story list
(US-0049–0063) contains no match, no lobby, no HUD and no score.** That is not a slipped story;
it is the milestone's exit criterion describing work filed under two later milestones. **The gate
did not fail — it was unrunnable when it was written**, and nobody had checked, because a gate is
the one story that is only read at the end.

**THE RECOMMENDATION IS TO SPLIT IT RATHER THAN MOVE IT.** Moving the whole gate to M6 loses the
thing it is for — *finding out early* — and M6 already has US-0088. See *What to do about it*.

### The scorecard

| # | Criterion | Result |
|---|---|---|
| 1 | Six humans play three consecutive matches | ❌ **there is no match.** `SYS-MATCH` is US-0079, M6 |
| 2 | Twelve questions asked individually and in writing, logged | ❌ blocked on 1. The instrument exists: TEST_PLAN §6.2 and `playtests/README.md`'s template |
| 3 | **THE TURN**: mean speed drops between minute 1 and minute 4 | ❌ **no instrument.** `TEL-MEAN-SPEED` has no emitter |
| 4 | Q7 "did you understand why you died" ≥ 4/5 | ❌ blocked on 1 — and see the note below |
| 5 | Q12 "would you play again tonight" ≥ 70 % | ❌ blocked on 1 |
| 6 | Q5 (best kill) rates below Q4 (realising you were followed) | ❌ blocked on 1 |
| 7 | `TEL-FIRST-CONTACT-OUTCOME` below 40 % correct identification | ❌ **no instrument** |
| 8 | Feel-regression checklist run and logged | ❌ **11 of its 14 rows are blocked**; the 3 runnable were judged at M1 |
| 9 | Risk register re-scored; `RISK-NOT-FUN-SOLO` updated | ✅ **done, 2026-08-27** |
| 10 | Tag `m4-the-loop` pushed | ⏸ the owner's call |

**Q7 deserves its own sentence.** *"Did you understand why you died"* is TEST_PLAN §6.2's **single
most important question**, and today the honest expected answer is *no* — a kill is a state change
and a log line, with no animation, no marker, no feed and no score. Running it now would measure
M5's absence and record it as a legibility failure. **That is the strongest argument for splitting
the gate rather than forcing it.**

### What the gate measured instead

**THE SERVER TICK, WITH ALL FIFTEEN M4 SYSTEMS LIVE: 2.16 ms MEAN, 2.27 p95, 2.6–2.9 p99, AGAINST
A BUDGET OF 8.0.** `test_server_tick_budget.gd` boots the real `server_root.tscn` with a full
lobby and the full crowd. Reproducible over three consecutive runs (mean 2.151 / 2.171 / 2.175).
**27 % of budget**, with contract, spawn, suspicion, blend, detection, compass, the prey warning,
kill and stun all registered.

> One run reported a **6.000 ms max** against 3.056 and 2.722 on the two after it. Recorded as a
> single outlier rather than explained; the p99 moved by 0.23 ms across the same three runs. This
> corpus has withdrawn transient machine-state readings before.

**AND 28 OF 29 DOCUMENTED TELEMETRY EVENTS HAVE NO EMITTER.** GDD-07 §8 is a 29-event catalogue;
exactly one call reaches `TelemetrySink.append`, and it is `TEL-DEGENERATE-CYCLE`.
`test_telemetry_catalogue.gd` is the count, and it did not exist — **the M4 gate's equivalent of
`test_crowd_bandwidth.gd` at M3**, an instrument the gate depends on that nobody had checked was
there. `TelemetrySink`'s own docstring has warned since M0: *"a sink that appears late is a sink
whose call sites were never written."*

**AND `--record` IS PARSED INTO `LaunchConfig.record_path` AND READ BY NOTHING.**
`playtests/README.md` instructs a facilitator to *"attach the telemetry export (`--record`)"*, so
the playtest procedure documents a flag that does nothing. Trap 14 in a runbook rather than in a
test table, and it would have been discovered with six people in the room.

**AND `US-0084` WAS CITED AS "THE HUD" IN TWELVE PLACES.** It is *Accessibility — input and
motion*, **M6**. The HUD is US-0072 (Compass widget), US-0073 (tier, portrait, crosshair) and
US-0074 (score feed), all **M5**. Every blocked client-side criterion in this corpus — US-0054's,
US-0057's, US-0059's — pointed at the wrong story, in the wrong milestone. Corrected across
`CLAUDE.md`, `ROADMAP.md` and `SIGNAL_AND_EVENT_BUS.md`; the two remaining references, which are
genuinely about motion reduction, are left.

### The feel-regression checklist, scored by what is runnable

TEST_PLAN §7.2 has fourteen rows. **Three can be run today and all three were judged at M1.**

| Runnable now | Blocked, and by what |
|---|---|
| 9 — the crowd feels alive | 1 the turn, 13 score feed, 14 results (M5 scoring) |
| 11 — slowing down is instant *(judged M1)* | 4 Compass legible, 5 pulse inflection, 6 prey warning (M5 HUD/audio) |
| 12 — traversal is forgiving, 10/10 *(judged M1)* | 8 the kill commits, 10 startle direction (no animation clips, either rig) |
| | 2 blend-walk safe, 3 sprint expensive, 7 stun decisive (need a second human **and** feedback) |

**Eleven of fourteen are blocked, and not one of them on M4 work.** Row 1 is THE TURN, which is
also criterion 3 above — it is asked twice and has no instrument either time.

## What to do about it — the recommendation

**Split this gate; do not move it.** Its value is finding out early, and its criteria are two
different tests wearing one story number:

1. **A technical M4 exit that can run today** — server tick, telemetry coverage, the systems
   integration, and a two-client hand session confirming the loop resolves. Most of it is
   measured above.
2. **The human playtest**, which needs a match, a HUD and a score, and therefore belongs beside
   US-0088 at M6 — where it can be run *with* the score feed the questions assume.

Splitting is an ADR because it changes a milestone exit criterion, and the ROADMAP's M4 row needs
amending in the same breath: **"the game is playable end-to-end" was never true of M4's story
list.**

**Nothing downstream is blocked by this.** M5 is the work that unblocks the playtest, so the
ordering does not change — only the honesty of the exit criterion does.

---

## Acceptance criteria

- [ ] Six humans play three consecutive matches.
      **Blocked: there is no match.** `SYS-MATCH` is US-0079, M6; the lobby is US-0078, M6.
- [ ] All twelve playtest questions asked individually and in writing, logged to `docs/40_backlog/playtests/`.
      Blocked on the line above. The template and the questions both exist.
- [ ] THE TURN: mean speed drops measurably between minute 1 and minute 4.
      **Blocked twice: no match, and `TEL-MEAN-SPEED` has no emitter** (US-0080).
- [ ] Q7 "did you understand why you died" scores at least 4 of 5.
      Blocked. **And it would fail today for M5's reasons** — no animation, no marker, no feed.
- [ ] Q12 "would you play again tonight" at least 70 percent yes.
      Blocked on the playtest.
- [ ] Q5 (best kill) rates BELOW Q4 (realising you were followed).
      Blocked on the playtest.
- [ ] TEL-FIRST-CONTACT-OUTCOME below 40 percent correct identification.
      **Blocked: no emitter** (US-0080).
- [ ] Feel-regression checklist run and logged.
      **11 of 14 rows blocked**; the 3 runnable were judged at M1 and are unchanged.
- [x] Risk register re-scored; RISK-NOT-FUN-SOLO updated.
      **Done 2026-08-27.** `RISK-NOT-FUN-SOLO`'s first-measurable moves **M4 → M6** — the risk is
      unchanged and the date we find out is two milestones later. `RISK-AGENT-DRIFT` confirmed
      with four live instances found in one afternoon; `RISK-CROWD-PERF` re-measured;
      `RISK-BANDWIDTH` updated to the 105 % downstream figure.
- [ ] Tag `m4-the-loop` pushed.
      **The owner's call**, and it should follow the split above rather than precede it.

## Test notes

If the turn does not happen, that is the most serious possible finding and no downstream work
should start until it is diagnosed.

> **AND IT CANNOT HAPPEN OR NOT-HAPPEN YET, WHICH IS A DIFFERENT THING FROM A NULL RESULT.**
> `TEL-MEAN-SPEED` has no emitter, so the turn is unmeasured rather than absent. **Do not read
> this gate as evidence either way**; the note above stands unchanged for whenever the gate is
> actually run.

`test_telemetry_catalogue.gd` reports the coverage gap on every run and turns green by itself the
day US-0080 wires a sink — the `pending`-that-names-its-own-blocker pattern.

## Notes

If Q5 exceeds Q4, hunting is beating being hunted and the emotional asymmetry the whole design is
tuned around has inverted. That is a design problem, not a tuning one.
