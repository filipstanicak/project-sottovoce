---
id: ADR-0024
title: The HUD shows what the reference shows
version: 1.0.0
status: accepted
owner: Lead Game Designer
last_updated: 2026-09-25
depends_on: [ADR-0013, GDD-06-UI-AUDIO, US-0073]
---

# ADR-0024 — The HUD shows what the reference shows

- **Status:** accepted. **The corpus is swept here; the build is US-0105.** Nothing in this ADR
  is drawn yet.
- **Date:** 2026-09-25
- **Deciders:** owner. Asked whether the global kill feed, the contract's player name and rank,
  and a permanent own rank should stay banned, the owner answered *"Bleiben dem Original so
  treu wie möglich."*
- **Amends:** never-do #12 (CLAUDE.md and its seed); GDD-06 §2.2 A, B and D, §2.3 and §8;
  NETWORK_PROTOCOL §7; TDD-04's withholding table; DEFINITION_OF_DONE; COVERAGE_MATRIX;
  SIGNAL_AND_EVENT_BUS; GDD-08's rejected-features table
- **Related:** ADR-0013 (the reference wins, and the first narrowing of #12), ADR-0021 (the
  face from assignment), ADR-0022 (the arc at the portrait and the pursuer marker), owner
  decisions 14 and 15

## Context

**Never-do #12 banned four things as converting an earned inference into a given fact.** The
reference has two of them and not the other two. A recorded match (chat log of 2026-09-25,
never here: never-do #5) shows:

- **a global kill feed**: *"A killed B"* lines at the left for every kill in the district, and
  the same place announces a player joining;
- **the contract's player name and current placement** beside the portrait, and an assignment
  card that shows both before play resumes;
- **your own placement**, permanently, with one icon per pursuer beneath it;
- **a compass that says up or down**, and that glows when the contract is in sight;
- **one-line notices**: a new pursuer on you, your contract poisoned, you taking the lead, your
  pursuer killing a civilian;
- **a death card**: the killer's player name, the points your death paid them, the bonuses they
  earned, and one line explaining how you were caught.

It has **no minimap and no names over heads.**

**The argument for the ban was that the contract cycle's opacity is load-bearing.** The
reference plays well with the cycle's changes announced to everyone. What stays hidden there is
the part that matters: *which figure* is the player. A name in the feed tells you somebody died,
not where they stand, and it never marks a body. The owner chose the reference.

## Decision

**Lifted from never-do #12:** the global kill feed, player names in the HUD (the feed, the
portrait, the death card, the scoreboard), and the permanent own placement.

**Still banned:** the minimap, and **names or any marker over a body that is not your own
contract or your own revealed pursuer**. ADR-0013's relationship-marker rule stands.

**The kill-cam is undecided rather than lifted.** The reference's death camera frames the
killer during the live kill animation. That is not a replay, but it does show the body that
killed you. Recorded as open question A.

**What US-0105 builds, in order of dependency:**

| Element | Depends on |
|---|---|
| Up/down on the Compass, and the glow while the contract is in sight | nothing: buildable now |
| One-line notices (new pursuer, contract poisoned, you take the lead) | nothing for the first and third; poison is dormant |
| *"Your pursuer killed a civilian"* | owner decision 14 (a kill on a chosen figure) |
| Kill feed, contract name and rank, death card, results names | **player names**, which do not exist anywhere yet (US-0078's lobby) |
| Own placement, contract placement | every player's score on the wire, a new message |
| One icon per pursuer | owner decision 15; until then it is always one |
| The death card's bonus lines | the score feed reaching the victim for that one kill: `test_no_global_score_feed.gd`'s rule narrows, it does not go |

## Open questions

- **A. The death camera.** Take the reference's (the live kill, framed on the killer) or keep
  the current one?
- **B. The death card's hint line.** The reference picks one line explaining how you were
  caught (flanked, followed by lock, betrayed by an ability). Ours would need a small
  catalogue in the string table and a server-side reason. Worth it?

## What this costs, said plainly

The cycle becomes legible to everyone: after a kill in the feed, every player knows two
contracts changed. The reference accepted that, and it is the decision. The two arch guards
that enforce the old rule, `test_no_global_score_feed.gd` and `test_warning_names_nobody.gd`,
**are not weakened by this ADR**. What they guard is still true today, and US-0105 amends each
in the same commit as the behaviour, citing this ADR as their header requires.

## Consequences

Never-do #12 is amended in CLAUDE.md and the seed in this commit, and every normative statement
of the old ban is struck with its reason rather than deleted. Code comments that describe
today's behaviour (`event_wire.gd`, `match_announcer.gd`) stay true until US-0105 changes that
behaviour, and change with it.
