---
id: US-0077
title: Results screen and bonus breakdown
version: 0.1.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-09-09
depends_on: [GDD-06-UI-AUDIO, ADR-0004]
---

# US-0077 — Results screen and bonus breakdown

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-RESULTS` |
| **Systems** | `SYS-RESULTS` |
| **Estimate** | S |
| **Depends on** | US-0076 |

## Description

The teaching moment. Placement is the frame; the per-bonus breakdown is the purpose.

## Acceptance criteria

- [ ] Final placement and totals for all players.
- [x] Per-player bonus breakdown: each type, count earned, points contributed.
- [x] The breakdown is derived from the SAME fold as the totals, so they cannot disagree.
- [ ] Each player's persona, loadout and passive shown — retrospective kit-reading.
- [ ] Your killers by name and count. NO position, NO replay.
- [x] Highest single kill of the match with its bonus stack, attributed.
- [ ] Time spent Anonymous per player, with the winner's highlighted.
- [ ] 25 s duration; skippable only by UNANIMOUS input.
- [x] NO per-player timeline, path or heatmap — that is a kill-cam by another name.

## Test notes

`test_results_matches_scoreboard.gd` folds 100 random logs and asserts breakdown totals equal
scoreboard totals.

## Notes

The time-Anonymous line is the cheapest onboarding fix available: it makes the invisible skill
visible in the one place players are already comparing themselves.

Unanimous skip means one impatient player cannot deny another the teaching moment.


## Implementation status, 2026-09-09

**NET-S2C-MATCH-END is built**, merged as `35be35b` in PR #218 and already
included in this branch. MatchEndWire carries the payload sent on the transition
into RESULTS; Net.events.match_ended receives it as MatchEndReport. It contains
anonymous_ticks and kits keyed by wire slot, events as reconstructed ScoreEvents
including SCORE-DEATH, and anonymous_seconds(slot, rules).

**The ScoreLog remains server-owned.** Presentation receives a separate copy of
reconstructed events, not the server log. It folds that copy with the same
ScoreFold for totals and bonus points, so criterion 3 is structural rather than
a promise. test_score_no_direct_mutation.gd remains unchanged and enforces the
ownership boundary. Three pure ScoreFold queries supply occurrence counts, the
local player's killers and the highest contract-kill group.

ResultsRoot visibility still follows HudBridge's existing snapshot-derived phase
event. The working result payload and the missing phase snapshot described below
are separate paths: receipt of the former does not establish receipt of the latter.

The owner assigned transport, metadata and unanimous skip to Claude; Codex owns
the presentation and the approved pure queries. The story remains in-progress:

- **Live opening is blocked in the server phase delivery.** The three-client probe
  reaches RESULTS server-side but no client opens the screen. MatchDirector's
  non-simulating branch returns before tick_completed; that signal is the sole
  SnapshotBuilder.send_all trigger. Thus the snapshot-derived phase never reaches
  RESULTS (nor the subsequent LOBBY). Claude must preserve snapshot phase delivery
  outside simulation; the presentation does not add a second phase channel.

- Placement is not delivered. **Owner decision, 2026-09-09: leave it unknown until
  Claude supplies it**, rather than invent a tie-breaking or shared-place rule.
  Every delivered player's total is shown, with an em dash for the absent place.
- Criterion 4 stays open: no player persona or passive is assigned server-side;
  the placeholder loadout does arrive and is shown.
- Criterion 5 stays open: player names do not exist in the project; the delivered
  death counts are shown against localized `Player <slot>` labels.
  Both findings are measured in [TDD-10 §7.1](../../20_tdd/10_scoring_and_match_state.md#71-what-us-0077s-server-half-built-and-the-two-things-it-cannot-deliver).
- Anonymous time is shown per delivered participant. Winner emphasis is implemented
  and tested with supplied placement, but cannot identify the winner in live data yet.
- The existing server owns the results duration. NET-C2S-SKIP-RESULTS is still
  unbuilt: it needs a C2S doorway on EVENT, and net.gd remains at 398 of 400 lines
  (NETWORK_PROTOCOL §2). Skip, its tally and results time delivery remain Claude's
  work; the shipping button stays disabled.
- The current transport enumerates connected slots and does not preserve departed
  participants' identity. Complete departed-player results require server work.

## Presentation handoff to the delivery owner

ClientRoot owns a ResultsRoot child named `Results`. Its `_match_ended` adapter
currently consumes MatchEndReport.events, slots(), kits and anonymous_seconds().
GameState.local_peer_id is historically named but contains the same wire slot.
Do not reconstruct results from live ScoreReports: they intentionally withhold
other players' awards and death records.

`present(events, roster, local_actor)` also accepts completed metadata with these
keys, for the future delivery extension and the reproducible visual probe:

| Roster key | Meaning |
|---|---|
| id | Event actor/subject wire slot |
| name | Authoritative display name |
| placement | Server placement; absent/zero displays unknown |
| persona | PERSONA- ID |
| abilities | ABIL- IDs in kit order |
| passive | PASV- ID |
| anonymous_seconds | Authoritative duration; absent/negative displays unavailable |

Connect ResultsRoot.skip_requested to the server skip request, then call
apply_skip_state(votes, voters, voted, seconds_left) with server facts.
seconds_left is optional and defaults to unknown: it is RESULTS time, never
Snapshot.ticks_remaining. A connected sender is required to enable the button.
One request is emitted per result; neither full tally nor zero time dismisses it.
Only the existing phase event closes the screen and clears the previous results.
The input sampler releases the cursor and sends neutral gameplay input while open.

## Verification surfaces

- `test_results_matches_scoreboard.gd`: 100 seeded logs compare totals and displayed
  contributions, including final-phase multipliers, zero awards and empty logs.
- `test_results_screen.gd`: actual packet decoder to screen, snapshot phase to
  HUD/input handoff, absent metadata, one-shot voting and safe-area layout.
- `tools/results_probe.tscn`: waiting, local, winner and long-name/empty captures
  with explicit fixture metadata; these do not claim live metadata exists.
- `tools/results_network_probe.tscn`: one server and three real client scenes,
  real handshake/courier/decoder/snapshot bridge. Fixture awards and accelerated
  ACTIVE/FINAL clocks exercise delivery without changing tuning. Start a server
  with `--server --port 27177 --min-players 3 --map sandbox --crowd 0`, then three
  clients with `--connect 127.0.0.1:27177 --map sandbox`. Each process must report
  `RESULTS PROBE` success; this is not a completed eight-minute playtest.
