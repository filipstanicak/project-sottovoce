---
id: US-0063
title: M4 gate — the loop resolves
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [BACKLOG-ROADMAP, BIBLE-TEST-PLAN, ADR-0016]
---

# US-0063 — M4 gate: the loop resolves

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-COMBAT` |
| **Systems** | all M4 systems |
| **Estimate** | M |
| **Depends on** | US-0062 |

## Description

**The technical exit for M4: the fifteen systems are built, registered in the shipped server,
inside budget, and the loop resolves end to end.**

> **THIS STORY WAS THE PLAYTEST GATE UNTIL 2026-08-27 AND WAS SPLIT BY
> [`ADR-0016`](../../00_meta/adr/ADR-0016-split-the-m4-gate.md).** It was run as written, one of
> ten criteria was met, and **six of the other nine could not be run at M4 by construction** — a
> playtest needs a match (`SYS-MATCH`, US-0079, **M6**), a lobby (US-0078, M6), a HUD
> (US-0072/0073, M5) and a score (US-0064/0074, M5), and M4's story list contains none of them.
> The gate did not fail; it was unrunnable when it was written, and nobody had checked, because a
> gate is the one story only read at the end.
>
> **The human half is [`US-0098`](US-0098-first-human-playtest.md), at M6.** The original ten
> criteria and the reasoning behind the split are in the ADR; this story now carries what M4 can
> actually be held to.

## Acceptance criteria

- [x] All fifteen M4 stories are built, and every M4 system is registered in `server_root.tscn`
      rather than only in a test fixture.
      **US-0049–0062.** `SYS-CONTRACT`, `SYS-SUSPICION`, `SYS-BLEND` (all four kinds),
      `SYS-DETECTION`, `SYS-COMPASS`'s server half, the prey warning, `SYS-KILL`, `SYS-STUN`,
      `SYS-SPAWN`. Three of them are not `GameSystem`s and the reason is TDD-01 §4's diagram in
      each case, recorded per story.
- [x] **The loop resolves end to end through the shipped server**, from a press to a respawn,
      asserted by an integration test that calls no system directly.
      **`test_the_m4_loop_resolves.gd`, and it did not exist.** Every M4 system was tested against
      its own fixture and `test_the_loop_closes.gd` is M2's — it proves the *transport*. This one
      boots `server_root.tscn` with the crowd live and drives press → validate → commit → contact
      frame → death → cycle repair → reassign breath → announcement → respawn timer → constrained
      placement → reinsertion. **13.1 s, 3 tests, 20 assertions.**
- [x] The server tick is inside `TUN-PERF-SERVER-TICK-BUDGET` with every M4 system live.
      **2.16 ms mean, 2.27 p95, 2.6–2.9 p99, against a budget of 8.0** — 27 %. Reproducible over
      three consecutive runs (2.151 / 2.171 / 2.175). One run reported a **6.000 ms max** against
      3.056 and 2.722 after it; recorded as an outlier rather than explained, because this corpus
      has withdrawn transient machine-state readings before.
- [x] The telemetry the downstream playtest depends on is **counted**, and the gap reported.
      **28 of 29 documented events have no emitter.** GDD-07 §8 is a 29-event catalogue and
      exactly one call reaches `TelemetrySink.append` — `TEL-DEGENERATE-CYCLE`.
      `test_telemetry_catalogue.gd` is that count and it did not exist. **This is the M4 gate's
      `test_crowd_bandwidth.gd`**: an instrument the gate depended on that nobody had checked was
      there. `TelemetrySink`'s own docstring warned in M0 — *"a sink that appears late is a sink
      whose call sites were never written."*
- [x] Risk register re-scored; `RISK-NOT-FUN-SOLO` updated.
      **`RISK-NOT-FUN-SOLO`'s first-measurable moves M4 → M6.** Probability and impact unchanged —
      there is no new evidence about fun either way — and **a risk discovered two milestones later
      than planned is a worse risk at the same score.** `RISK-AGENT-DRIFT` confirmed with four
      live instances found in one afternoon; `RISK-CROWD-PERF` re-measured; `RISK-BANDWIDTH`
      updated to the 105 % downstream figure.
- [x] The three suites pass from a clean checkout, and the script counts in `CLAUDE.md` match.
      arch **47 / 186 / 837**, unit **148 / 1241 / 27 045** (8 pending by design), integration
      **33 / 242 / 671** at **183.5 s**. `test_claude_md_counts_are_current.gd` guards the script counts.
- [ ] Tag `m4-the-loop` pushed.
      **The owner's call**, and it should follow ADR-0016 rather than precede it.

## What this gate found, beyond its own criteria

**`PawnStateId.DEAD` IS NEVER OBSERVABLE FROM OUTSIDE A TICK.** GDD-02 §3.1 gives `Respawning`
the entry *"death resolved"* and the exit *"`TUN-RESPAWN-DELAY` 5.0 s"*, and §3's diagram draws
`Dead --> Respawning: corpse spawned` — the corpse spawns **at** the contact frame, so both edges
are taken in the same tick: `SYS-KILL` sets `Dead` at the `combat` stage and `SYS-SPAWN` moves it
on at `contract`, one stage later. **The code is correct and the first version of the loop test
was wrong**, reading `Respawning` where it expected `Dead` and looking exactly like a rule that
does not work. It asks `CombatTargets.is_dead` now. **Anything client-side that keys a death
screen on `Dead` will never fire** — worth knowing before US-0073.

**`--record` IS PARSED INTO `LaunchConfig.record_path` AND READ BY NOTHING**, while
`playtests/README.md` instructs a facilitator to *"attach the telemetry export (`--record`)"*. A
runbook documenting a flag that does nothing, and it would have been discovered with six people in
the room. Trap 14 outside a test table.

**`US-0084` WAS CITED AS "THE HUD" IN TWELVE PLACES ACROSS THREE DOCUMENTS.** It is *Accessibility
— input and motion*, **M6**. The HUD is US-0072 (Compass widget), US-0073 (tier, portrait,
crosshair) and US-0074 (score feed), all **M5**. Every blocked client-side criterion in this corpus
— US-0054's, US-0057's, US-0059's — pointed at the wrong story in the wrong milestone. Corrected;
the two surviving references are genuinely about motion reduction and are right.

**THE INTEGRATION SUITE IS NOW AT 183.5 s AGAINST A DOCUMENTED 180 s, AND THAT BUDGET IS
ENFORCED NOWHERE.** It appears in TEST_PLAN §3, TEST_PLAN §10 and TDD-12 §17, and no job checks
it. Either enforce it or raise it; a number three documents assert and nothing measures is the
same shape as every other finding on this list.

**THE FEEL-REGRESSION CHECKLIST IS 11 OF 14 BLOCKED**, and not one of them on M4 work. Runnable
today: the crowd feels alive; slowing down is instant; traversal is forgiving — and the last two
were judged at M1. Row 1 is THE TURN, which the old criterion 3 also asked, so the turn was asked
twice by this gate and had no instrument either time. The full run is US-0098's.

## Test notes

`test_the_m4_loop_resolves.gd` asserts the ordering the director imposes, never a system's return
value — the consequences that leave `SYS-KILL` through `server_root` (cycle repair, corpse,
startle, witnesses) are the ones most likely to look wired and not be, which is what US-0060's
four entry points were.

`test_telemetry_catalogue.gd` reports rather than fails, the choice `test_snapshot_size.gd` made,
and **turns green by itself the day US-0080 wires a sink** — the `pending`-that-names-its-own-
blocker pattern.

## Notes

The old description's claim — *"the loop must be interesting with NO abilities, NO scoring, NO HUD
beyond a debug overlay and NO audio"* — is preserved in US-0098 and is what that story tests. It
was never a licence to run the questions against **no player-facing channel at all**, which is
what M4 actually has.
