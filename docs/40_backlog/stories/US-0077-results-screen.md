---
id: US-0077
title: Results screen and bonus breakdown
version: 0.1.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-09-08
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
- [ ] Per-player bonus breakdown: each type, count earned, points contributed.
- [ ] The breakdown is derived from the SAME fold as the totals, so they cannot disagree.
- [ ] Each player's persona, loadout and passive shown — retrospective kit-reading.
- [ ] Your killers by name and count. NO position, NO replay.
- [ ] Highest single kill of the match with its bonus stack, attributed.
- [ ] Time spent Anonymous per player, with the winner's highlighted.
- [ ] 25 s duration; skippable only by UNANIMOUS input.
- [ ] NO per-player timeline, path or heatmap — that is a kill-cam by another name.

## Test notes

`test_results_matches_scoreboard.gd` folds 100 random logs and asserts breakdown totals equal
scoreboard totals.

## Notes

The time-Anonymous line is the cheapest onboarding fix available: it makes the invisible skill
visible in the one place players are already comparing themselves.

Unanimous skip means one impatient player cannot deny another the teaching moment.


## Implementation status, 2026-09-08

Presentation work is in progress. Phase changes use the existing HudBridge /
EventBus signal. Match `ticks_remaining` must not drive a results countdown.
The view model will use ScoreFold for both totals and breakdowns.

The delivery seam is not implemented yet: NET-S2C-MATCH-END and
NET-C2S-SKIP-RESULTS exist in the protocol catalogue but have no handlers.
The live score feed sends only the recipient's awards and omits SCORE-DEATH;
it cannot supply all-player results. Names, complete kits and authoritative
Anonymous durations also need an end-of-match payload. The server-owned log
must not be held by presentation (test_score_no_direct_mutation.gd).
The owner assigned transport, metadata and unanimous skip to Claude; Codex owns
the presentation. End-to-end acceptance stays open until that delivery is wired.


## Presentation handoff to the delivery owner

The shipping `ClientRoot` now owns a `ResultsRoot` child named `Results`.
The adapter calls `present(events: Array[ScoreEvent], roster: Array[Dictionary],
local_actor: int)` after validating the complete end-of-match payload. Do not use
live `ScoreReport`s: they intentionally lack identity and death records.
Preserve the events' frozen base points and multiplier; the UI never reconstructs
an event against a current tuning profile. IDs in the roster and local_actor must
be the same identity domain as ScoreEvent.actor_id/subject_id, including departed
participants. This is a presentation adapter contract, not a new wire format.

| Roster key | Meaning |
|---|---|
| id | Stable event actor/subject ID |
| name | Authoritative display name |
| placement | Final server placement; absent/zero displays unknown, no client tie-break |
| persona | PERSONA- ID |
| abilities | Array of the two ABIL- IDs |
| passive | PASV- ID |
| anonymous_seconds | Authoritative duration; absent/negative displays unavailable |

Connect `ResultsRoot.skip_requested` to the existing planned skip request, then
call `apply_skip_state(votes, voters, voted, seconds_left)` with server facts.
`seconds_left` is optional and defaults to unknown; it is RESULTS time, never
Snapshot.ticks_remaining. Without a connected sender, the button stays disabled.
A vote is emitted at most once per displayed result. A full tally or zero time
never dismisses the screen: only the existing match_phase_changed event does.

The payload may precede or follow RESULTS. A late payload replaces a waiting
surface; leaving RESULTS clears it. The existing input sampler releases the
cursor and sends neutral gameplay input while the results surface is active.
`tools/results_probe.tscn` reproduces waiting, local, winner and long-name/empty
screens using fixtures; it is not the delivery path and the shipping client
never manufactures these records.
