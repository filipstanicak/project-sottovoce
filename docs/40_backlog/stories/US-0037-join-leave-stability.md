---
id: US-0037
title: Join and leave stability
version: 1.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-15
depends_on: [TDD-04-NET]
---

# US-0037 — Join and leave stability

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0036 |

## Description

Mid-match join and leave without orphaned entities, stale bookkeeping or desync.

## Cleanup is the code most likely to look correct and never have executed

Every owner of per-peer state has some — `SlotTable`, `PeerRegistry`, `PawnHost`, `RpcRouter`,
`SnapshotBuilder`, `RemotePawns`. It is written once, beside the thing it cleans up, and **the
happy path never reaches it.** Until this story none of it had run under churn.

**The failure it looks for is inheritance, not leakage.** ENet reuses peer ids, so anything left
behind is not wasted memory — it is handed to the next joiner, who is then named as somebody else
in every message that names anybody.

## Acceptance criteria

- [x] A joining peer receives a pawn, a wire slot and a snapshot. **Tuning sync and match start
      are not asserted here**: the sync is `Net`'s and needs two processes, and
      `NET-S2C-MATCH-START` belongs to `SYS-MATCH` in M4.
- [x] A leaving peer's pawn is freed and its per-peer bookkeeping released — asserted as a
      **baseline comparison** across five counters, not as five separate absences, so a new owner
      of per-peer state has to be added to the baseline to be ignored.
- [x] **A timeout is handled identically to a clean disconnect.** **Proven across real processes
      on 2026-08-15, in US-0038's gate run.** A client was killed hard — no disconnect packet, the
      peer simply stops answering, which is the timeout path — and about ten seconds later
      (`TUN-NET-TIMEOUT` is 10 s) the server logged `Net: peer 843868542 left` followed by
      `pawn freed for peer 843868542`: the same `Net.peer_left` → `_on_peer_left` sequence a clean
      disconnect takes.

      "Identically" is structural — there is **one signal and one handler** — and what was missing
      was evidence that a timeout reaches it at all. A *graceful* quit could not be exercised in
      the same run, because a headless process has no window to receive a close request.
- [x] Repeated join and leave churn leaves no orphaned entities. **40 cycles of three peers —
      120 joins and 120 departures** — with everything back to baseline afterwards.
- [x] Remaining clients see no stutter when a peer joins: the incumbents still agree with the
      server within `TUN-NET-RECONCILE-THRESHOLD` across a join, and a survivor still agrees
      after twenty cycles of somebody else's churn.
- [ ] **Below the minimum player count the match ends gracefully with results shown.** `SYS-MATCH`
      owns match end and it is M4's; there is no results screen to show. Left unticked.

## Five minutes is repetition, and repetition is what is counted

US-0037 asks for five minutes of churn. **18 000 physics frames would take longer than the 180 s
the whole integration suite is allowed**, so the test counts cycles instead: 40 × 3 peers = 120
joins and 120 departures, each with its own snapshot stream. What five minutes buys is
repetition; what it does not buy is any state that only appears after four minutes, and nothing
here accumulates with time rather than with cycles. Recorded rather than rounded up.

## What the churn found

**A departed client sent one more command.** `queue_free()` frees at the end of the frame, so a
removed client's driver sampled once more and enqueued a packet nobody could deliver — and the
snapshot answering it arrived for a client that no longer existed, indexing a dictionary that had
none. Found by the in-flight count failing to return to zero, which is exactly why the baseline
comparison counts the wire as well as the entities.

The harness guards it at the source now, which is also what really happens: **a closed socket
does not send.**

**And one of this file's own tests was true of the wrong thing.** It let a pawn stand still for
30 frames, removed it, rejoined, and asserted the new pawn had not resumed from where the old one
stopped — which it trivially had not, because it had never gone anywhere. Trap 4, inside a test
about cleanup. It drives the pawn now.

## Test notes

| Test | Asserts |
|---|---|
| `test_join_leave_stable.gd` | A joiner gets a pawn, a slot and a snapshot; a leaver takes everything with it; **a freed slot is reused rather than burned**; a rejoining peer does not inherit its own past; incumbents are undisturbed by a join; **40 cycles return every counter to baseline**; 120 joins never exhaust the slot table; a survivor still agrees after twenty cycles of churn |

The baseline is five counters — server pawns, `MatchContext.pawns`, wire slots, clients and
**packets still on the wire** — compared before and after. Counting the wire is what caught the
one real defect.

## Notes

Contract cycle repair on disconnect arrives at M4. At M2 there is no cycle to repair — this story
covers transport-level lifecycle only.
