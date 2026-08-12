---
id: US-0092
title: The pawn is centred — the shoulder offset is deprecated
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-12
depends_on: [GDD-02-PLAYER, BIBLE-NAMING]
---

# US-0092 — The centred camera

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-CAMERA` |
| **Systems** | `SYS-CAMERA`, `SYS-INPUT` |
| **Estimate** | S |
| **Depends on** | US-0021, US-0091 |

## Description

**Decided by the owner.** The pawn stands on the centre line of the shot. `TUN-CAM-SHOULDER-OFFSET`
and `TUN-CAM-SHOULDER-SWAP-TIME` are deprecated, and `INPUT-SHOULDER` with them.

## Acceptance criteria

- [x] `CameraArm` has no lateral term. The arm is behind the pawn and on its axis at every yaw
      and pitch.
- [x] `TUN-CAM-SHOULDER-OFFSET`, `TUN-CAM-SHOULDER-SWAP-TIME` retired into TUNABLES §19.
- [x] `INPUT-SHOULDER` is declared nowhere and bound to nothing, while remaining an ID in the
      corpus.
- [x] GDD-02 §4.1 records that centred framing is a decision, not an absence.

## Two reasons, and the second is the one that matters

1. **The offset never did anything.** `CameraRig` slid the camera 0.45 m sideways and then called
   `look_at(pivot)` — and the pivot is the pawn's own axis, so the pawn projected to the exact
   centre of the screen however far the camera moved. The offset changed the viewing *angle* and
   never the composition. It had been that way since US-0021 and **nobody could see it, because
   the pawn was invisible until US-0091.** The first screenshot of a rendered body made it
   obvious in one glance.
2. **A centred model is the right shot for this game.** It is the established framing for
   third-person social stealth, and it is what this design needs: the pawn's silhouette is the
   thing the player is *reading* — how do I look right now, am I moving like the crowd — and a
   silhouette pushed into the corner of the screen is one you stop checking. An over-the-shoulder
   offset exists to clear a firing line. This game has no firing line.

The cost is accepted and recorded in §4.1: your own body occupies the middle of the screen and
hides what is directly ahead at close range.

## What a retired input costs, which turned out to be a mechanism

`Ids` is **harvested from the documents**, and NAMING_AND_IDS §2.3 keeps a retired ID documented
forever. So an input action cannot be made to disappear by deleting its table row — the harvester
finds it again, `Ids` declares it, and the guard that every documented action has a row fails.

`InputActions.DEPRECATED` is the declaration that closes that loop: the ID stays in the corpus
and in `Ids`, and is excused from having a row, a binding, or any way for a player to press it.
Two new guards keep both halves honest — a retired action is declared nowhere, *and* it is still
remembered by the corpus. The second matters more: an ID that vanished could be reintroduced
later with a second meaning, which is the one thing immutability exists to prevent.

## The runner earned its keep again

Removing `CameraArm.Shoulder` broke three test scripts, which then **failed to parse and were
silently skipped**. Both suites reported green — 368 unit and 92 integration passing, nothing
failing — while running two and one fewer scripts than exist on disk. `.ci/run_gut.sh` refused
them on the count. That is trap 10, and it is the third time the count has caught what the pass
did not.

## Recorded without a citation

The owner's reasoning cited a specific commercial title as precedent. **That reference cannot
appear in this repository**: `.ci/banned_terms.txt` lists it, the `ip-guard` job scans every
tracked file, and IP_GUARDRAILS §2 forbids franchise terminology in code, comments, commits,
branch names, filenames and docs alike. The *decision* is recorded above on its own merits, which
is what the design record needs anyway — a reason that stands without an appeal to another game.
