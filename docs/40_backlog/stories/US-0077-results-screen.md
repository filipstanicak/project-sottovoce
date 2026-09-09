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

- [x] Final placement and totals for all players.
- [x] Per-player bonus breakdown: each type, count earned, points contributed.
- [x] The breakdown is derived from the SAME fold as the totals, so they cannot disagree.
- [ ] Each player's persona, loadout and passive shown — retrospective kit-reading.
- [ ] Your killers by name and count. NO position, NO replay.
- [x] Highest single kill of the match with its bonus stack, attributed.
- [x] Time spent Anonymous per player, with the winner's highlighted.
- [x] 25 s duration; skippable only by UNANIMOUS input.
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

ScorePlacement.standings supplies order, points and place from the same report
slots and events; no presentation tie-break exists. is_shared_win chooses explicit
joint-winner wording, including a match where all players scored zero. This
supersedes the temporary unknown-placement decision: main 22c80e7 supplied the rule.

ClientRoot connects ResultsRoot.skip_requested to Net.requests.send_skip_results.
The press sends once and never hides the screen itself. HudBridge, still the only
snapshot reader in presentation, forwards RESULTS ticks_remaining through a local
results_time_changed signal. At zero, ResultsRoot hides the surface but keeps HUD
and gameplay input suppressed until an actual phase change; RESULTS does not imply
a new lobby. No local timer counts down. PR #220 (1c7fb0a) restores RESULTS
snapshots; report delivery and snapshot-derived phase remain separate paths.

The owner assigned transport, metadata and unanimous skip to Claude; Codex owns
the presentation and the approved pure queries. The story remains in-progress:

- **Live opening and expiry are verified after PR #220.** One server and three
  real clients each received three players and the 300-point fixture kill. In the
  skip run, clients voted at staggered times; the screen stayed open before the
  last vote and all three closed on authoritative zero. In the separate no-vote
  run, all three closed at the server's normal RESULTS expiry. HUD and gameplay
  stay suppressed because the server remains in RESULTS. No second phase channel
  was added.

- Criterion 4 stays open: no player persona or passive is assigned server-side;
  the placeholder loadout does arrive and is shown.
- Criterion 5 stays open: player names do not exist in the project; the delivered
  death counts are shown against localized `Player <slot>` labels.
  Both findings are measured in [TDD-10 §7.1](../../20_tdd/10_scoring_and_match_state.md#71-what-us-0077s-server-half-built-and-the-two-things-it-cannot-deliver).
- NET-C2S-SKIP-RESULTS is built in RequestWire and the shipping button is connected.
  Criterion 8 is verified through the real request and snapshot paths, including
  the normal 25-second clock without accelerated RESULTS time.
- MatchSystem.skips() and its player count are server state, not replicated vote
  totals. No tally is fabricated. The optional tally adapter remains available
  for a future delivery; the actual button reports only that this client sent a vote.
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
| placement | Ignored on input; ScorePlacement derives the authoritative rule from the report |
| persona | PERSONA- ID |
| abilities | ABIL- IDs in kit order |
| passive | PASV- ID |
| anonymous_seconds | Authoritative duration; absent/negative displays unavailable |

ClientRoot already connects ResultsRoot.skip_requested to Net.requests.send_skip_results.
A received report enables voting only with a live connection and a bound sender.
No vote tally is available over the wire; apply_skip_state is only an optional
adapter for future authoritative tally data and the fixture probe.

RESULTS snapshots carry results time as ticks_remaining (ACTIVE/FINAL carry match
time instead). HudBridge publishes the phase first, then forwards RESULTS time
locally through ClientRoot to ResultsRoot. Other phases' zeroes cannot close it.
Authoritative RESULTS zero hides the surface; full vote tallies and the local press
cannot. Leaving RESULTS clears the previous report and restores gameplay controls.
No client phase is invented at expiry: the server currently remains in RESULTS.

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
  `RESULTS PROBE PASS` and `RESULTS PROBE EXPIRY PASS`. The default client mode
  presses skip at staggered times; repeat with `--natural-expiry` on all three
  clients to leave RESULTS running for its normal duration. The server keeps the
  connections alive for 30 seconds of RESULTS. This is not a completed
  eight-minute playtest.
