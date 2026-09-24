---
id: US-0100
title: The persona is dealt at the countdown
version: 0.1.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-09-24
depends_on: [GDD-03-SOCIAL-STEALTH, BIBLE-NET-PROTOCOL]
---

# US-0100 — The persona is dealt at the countdown

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-MATCHFLOW` |
| **Systems** | `SYS-MATCH`, `SYS-CONTRACT`, `SYS-CROWD` |
| **Estimate** | M |
| **Depends on** | US-0079 |

## Description

**Owner decision 13, taken 2026-09-24.** A player has no persona server-side at all:
`PawnContext.persona` is declared under *Identity*, two lines below `peer_id`, and has never
had a writer under `scripts/`. Four things wait on that — ADR-0021's contract portrait,
US-0077's results slot labels, `CloneBalance` being told all four personas are in use, and
US-0073's portrait criterion — and **none of them wants a lobby**. They want a player to
*have* a persona.

The persona is dealt server-side at the countdown, from `MatchContext.rng`, in the same breath
as the contract cycle. **Duplicates are permitted**, which US-0078 already calls *good: they
add a candidate to each other's crowd*. US-0078's `NET-C2S-LOADOUT` later **replaces** the
deal rather than enabling it — decision 1's argument about the countdown trigger, applied a
second time. This story moves no criterion out of US-0078.

## Acceptance criteria

- [x] Every player holds a persona from the countdown, dealt from the seeded `MatchContext.rng`
      and never from `randf`/`randi` (never-do #8). Duplicates are permitted. **The deal runs
      before `ContractSystem.open`**, because that call announces synchronously and a hunter
      told the persona from the *previous* deal is a client and a district disagreeing about a
      face — found in review, asserted at the seam now.
- [x] A player who joins *after* the countdown is dealt one too, or they are the only figure in
      the district with no clones — GDD-03 §6.3 rule 5's marked man. **And a join *before* the
      countdown is not**, because US-0100's own rule is that nobody holds a persona until the
      deal. **Ticked only after the review found two defects in the untested version**: it
      dealt in `LOBBY`, and every lobby join spent the match generator, so the recorded seed
      stopped reproducing the district. `MatchPhase.is_simulating` is the gate and
      `test_the_persona_deal_ordering.gd` asserts both halves.
- [x] The deal survives death: `reset_for_spawn` must not clear it, because a persona is
      identity and a respawn is not a new player.
- [x] `CloneBalance` fetches clones for the personas **actually in play** rather than all four.
      The boot roster is unchanged; only the 2 s rebalance pass narrows. **Ticked only after
      the review found the missing half**: the list was refreshed after a *deal* and never
      after a *departure*, so the last wearer of a persona leaving left the pass fetching
      clones nobody wore for the rest of the match. `MatchConsequences.peer_left` closes it and
      three tests hold it — the drop, the persona somebody else still wears, and the empty
      district that must fall back to all four rather than look like `test_crowd_perf.gd`'s
      deliberate layer-4-off measurement.
      **What is still owed is the census, not the rule**: US-0047's clone-floor measurement run
      on a dealt district belongs with the human playtest.
- [x] The hunter is told their contract's persona (ADR-0021), on
      `NET-S2C-CONTRACT-ASSIGNED`, with `PROTOCOL_VERSION` raised and the handshake refusing
      the old width.
- [x] `CrowdRoster.PLAYABLE`'s order is asserted to be append-only, because it is now a wire
      encoding as well as a derivation input.
- [x] A persona the client cannot resolve is drawn as unknown rather than guessed.

## Test notes

Falsify: a deal that uses `randi`, a `reset_for_spawn` that clears the persona, an inserted
`PLAYABLE` member, the wire index read one off — and the three the review found: the deal after
`contracts.open`, the join gate removed, and `peer_left` not refreshing the list. All six red by
name.

## Notes

**Deliberately NOT in this story: the results table's personas.** `MatchEndReport` carries
`anonymous_ticks`, `kits` and `events` and no persona, so `ResultsRoot` builds a slot label,
abilities and Anonymous time and could not draw a persona if it wanted to. That needs its own
transport — a persona per result row, or the stable roster that also answers US-0078's
criterion 4 (*persona selections are VISIBLE to all players*). **It costs a second
`PROTOCOL_VERSION` bump**, and that is the cheaper mistake: shipping the field here with no
reader is the *field nobody reads and nobody writes* shape this corpus has paid for eight
times, most recently in the very field this story gives a writer.

**The crowd roster is derived at boot and the deal happens at the countdown**, which is an
ordering problem this story does not solve by re-deriving. `CrowdRoster.derive` decides the
initial mix before any player has a persona; re-rolling it at the countdown would churn the
whole district in front of the lobby. Only `CrowdDirector.personas_in_use` — read by the 2 s
rebalance pass and nothing else — narrows to the dealt set. The initial mix stays all four,
which `crowd_roster.gd` already argues is the safe direction.
