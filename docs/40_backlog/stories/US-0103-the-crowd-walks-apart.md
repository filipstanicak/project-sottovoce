---
id: US-0103
title: The crowd walks apart, gathers and sits
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-09-25
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-08-CROWD]
---

# US-0103 — The crowd walks apart, gathers and sits

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-MATCHFLOW` |
| **Systems** | `SYS-CROWD`, `SYS-BLEND` |
| **Estimate** | L — planned as two PRs |
| **Depends on** | US-0102 |

## Description

**Reported from the controls on 2026-09-25 with a screenshot:** figures of the crowd walking in
rows along one route. The owner wants *a few groups, and everybody else walking on their own* —
and pointed out that in the reference title NPCs **sit on benches and stand in circles**, and a
player does the same to blend. Sources for that are in the chat log of 2026-09-25, never here
(never-do #5).

**MEASURED BEFORE ANYTHING WAS CHANGED** — `tools/crowd_spread_census.tscn`, the district, one
synthetic player, 120 s, two runs:

| state | share of the crowd | walking with company, **same state** | with anyone |
|---|---|---|---|
| `IDLE` | 19 % | 0 % | 0 % |
| `STROLL` | 63–64 % | **39 %** (both runs) | 40 % |
| `WALKING_GROUP` | 17–18 % | 93–94 % (by design) | 93–95 % |

and **58–64 % of stroller walking lies on shared lanes** (one-metre cells five or more strollers
crossed). The rows are the *strollers*: each picks its own anchor and takes the **shortest**
navmesh path, so they share corners and street centres — lane formation as an artefact of
pathing. The four processions (GDD-03 §5.2) are the "few groups" and stay.

**AND THE CHECK FOUND A RELEASE BLOCKER NOBODY HAD TRACKED.** GDD-03 §6.3 rule 7 — *clones must
be able to occupy every blend action a player can*; *"a player sitting on a bench that no NPC ever
sits on is a player sitting alone on a bench"* — has **no implementation**: nothing under
`scripts/systems/crowd/` uses a blend prop, a lean spot or a hiding spot, and
`TUN-CROWD-IDLE-GROUP-SIZE-MIN`/`-MAX` (conversation clusters of 2–4) are declared and **read by
nothing**. A player who blends on a bench today is the only figure ever seen on one.

**GOAP was evaluated and not chosen** (chat, 2026-09-25): it plans *what* an agent does, not
*how* it walks, so it cannot remove a lane; and any NPC activity a player cannot also perform
becomes a tell. Benches and circles are smart objects both can use — the reference's own answer.

## Acceptance criteria

- [ ] **Walk apart.** Strollers take a seeded per-NPC lateral offset and scatter their path
      corners inside the walkable corridor (new tunables, none changed). Measured with
      `crowd_spread_census`: strollers' same-state company falls well below 39 %, and
      shared-lane walking well below 58–64 %. The civilian test bots (US-0102) follow the
      same rule, or they become the one figure on the centre line.
- [ ] **Gather.** Some idle NPCs form conversation circles of `TUN-CROWD-IDLE-GROUP-SIZE-MIN`..
      `-MAX` at anchors, and a player can stand into one and blend there (the crowd-pocket blend;
      check `TUN-BLEND-POCKET-MIN-NPC` against a circle of that size).
- [ ] **Sit and lean.** NPCs occupy benches and lean spots through the same occupancy the
      player's prop blend uses (GDD-03 §6.3 rule 7), with a rule for a seat an NPC holds when a
      player wants it. Seated reads as standing at the seat until clips exist — on both sides.
- [ ] Processions stay at `TUN-CROWD-GROUP-COUNT` 4 × `TUN-CROWD-GROUP-SIZE` 4.

## Test notes

`tools/crowd_spread_census.tscn` is the instrument and landed with this story's checkpoint,
before any fix, so the "before" is on record. Its arithmetic is `tools/crowd_spread.gd`, tested
in `test/unit/tools/test_crowd_spread.gd`.

**THE FIRST FIGURES WERE WRONG IN TWO WAYS, AND THE REVIEW OF #237 FOUND BOTH.** A walk whose
two samples straddled a state change was booked to the new state, which is why `IDLE` read 15 %
company for figures that do not walk. And a stroller beside a procession counted as company, so
the stroller figure measured rows *or* processions. Both are fixed, each with a synthetic test
that reddens without its half. **Remeasured: 39 % same-state company in both runs** (the old
figure was 33–40 %), with anyone 40 %, so the processions add one point and the rows are the
strollers' own. Shared lanes read 58 % and 64 %. The server's timing is not seeded, so compare
the fix against a range of runs, not one.

## Notes

Planned as two PRs: walk apart + gather first (the measured cause, no animation needed), then
sit and lean (the release blocker, which needs the seat-contention rule decided).
