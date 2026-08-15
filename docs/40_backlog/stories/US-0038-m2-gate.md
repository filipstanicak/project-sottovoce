---
id: US-0038
title: M2 gate — netcode verification
version: 1.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-15
depends_on: [BACKLOG-ROADMAP, BIBLE-TEST-PLAN]
---

# US-0038 — M2 gate: netcode verification

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | `SYS-NET-PREDICTION`, `SYS-NET-REPLICATION` |
| **Estimate** | S |
| **Depends on** | US-0037 |

## Description

Run and log the full M2 exit verification. This story exists so the gate is somebody's explicit
deliverable rather than an assumption.

## What a gate is for, and what this one found

Running the suite was the cheap half. The gate's actual value was **checking that the things it
names exist and measure what they claim to**, and two of them did not:

- **`test_upstream_bandwidth.gd` did not exist.** §4.1 called it "expected to FAIL", which reads
  like a test that runs and goes red. Nothing ran. The upstream miss was a projection from
  TDD-04 §7.3 that nobody had checked against the implementation.
- **Written, it found the miss is four times worse than documented and the planned fix does not
  work.** See below.

Everything the gate names is now verified to be a file that something runs — trap 14, third
application.

## Acceptance criteria

- [x] **Three clients plus a headless server, replicated movement, verified by hand.** Done
      2026-08-15, four real processes. Each client was welcomed into a distinct wire slot (1, 2,
      3) and **each saw the other two appear**:

      ```
      [net] Net: peer 974602089 welcomed — 1 player(s)
      [pawn] pawn spawned for peer 974602089 at (12.000000, 0.000000, 36.000000)
      [net] Net: peer 1771168444 welcomed — 2 player(s)
      [pawn] pawn spawned for peer 1771168444 at (20.000000, 0.000000, 70.000000)
      [net] Net: peer 843868542 welcomed — 3 player(s)
      [pawn] pawn spawned for peer 843868542 at (6.000000, 0.000000, 97.500000)
      ```
      ```
      [net] Net: welcomed as peer 1, map 0, phase 2, tuning 1057634729
      [net] client is slot 1
      [net] remote pawn appeared in slot 2
      [net] remote pawn appeared in slot 3
      ```

      **This is the first multi-process run with delta encoding live**, and the first proof that
      `SlotTable` maps 32-bit peer ids onto bytes over a real wire rather than only in a test.
      `phase 2` is ACTIVE, so US-0030's welcome-phase defect stays fixed.

      **The clients are headless and therefore motionless** — trap 13: there is no windowing layer
      to read an input device. What this run proves is the *transport* carrying three real peers.
      Replicated **movement** is proven by `test_the_loop_closes.gd` and the integration harness,
      not here, and saying otherwise would be the kind of rounding-up this gate exists to refuse.
- [x] **`test_prediction_reconciliation.gd` passes at all four latency profiles.** Verified by
      reading the file, not by trusting §4.1: four separate tests at 1, 3, 6 and 11 frames —
      LAN, GOOD, TYPICAL, POOR. Nine assertions, all green.

      **Its latency is downstream-only, and that is worth stating.** `_mirror()` applies each
      command to the server in the same frame it is sampled and holds only the *snapshot*. So the
      file proves reconciliation converges when **corrections** arrive late; it does not exercise
      the server genuinely lagging because **commands** arrive late. `IntegrationHarness` delays
      both, and measured zero replays at every profile. Between them the case is covered; neither
      covers it alone.
- [ ] **`test_frame_rate_independence.gd` passes at 30, 60 and 144 fps.** **THE SUBSTITUTE IS
      ACCEPTED EXPLICITLY; THE LINE IS NOT TICKED.** A headless process has no display rate to
      vary, so the test as specified cannot exist in this pipeline.

      The property it was to prove — that gameplay does not ride the render clock — is guarded by
      `test_no_gameplay_in_process.gd`, which forbids `_process` anywhere server-side outright.
      That is **stronger in one direction**: gameplay cannot be off the render clock *by accident*
      today, whereas a three-rate comparison only shows it was not, on the day it ran. It is
      **weaker in another**: a client-side visual reading gameplay state per rendered frame would
      still slip past, and only a real display could catch that.

      The gate accepts the structural guard as sufficient **for M2**, whose exit criterion is
      transport correctness. It is left unticked because the substitute is not the criterion, and
      a ticked line here would tell M6 the frame-rate case was closed when it was not.
- [x] **`test_join_leave_stable.gd` passes over five minutes of churn.** **Met as 120 join /
      leave cycles rather than five minutes of wall clock**, and the gate accepts the substitution
      explicitly. 18 000 physics frames would outlast the 180 s the whole integration suite is
      allowed. What five minutes buys is *repetition*, which is what the cycles deliver; what it
      does not buy is any state that appears only after four minutes, and nothing in the
      lifecycle path accumulates with time rather than with cycles.

      Ticked rather than left open because the **intent** is met in full and the deviation is
      recorded in three places. This is the one line where the gate judges a substitution
      sufficient; the frame-rate line above is the one where it does not, and the difference is
      that this one loses nothing.
- [ ] **Downstream bandwidth within budget, measured.** `test_snapshot_size.gd` recomputes §7.1's
      table from the real record sizes on every run and projects **93.5 kbit/s, 97 % of budget**.

      **It is a projection, not a measurement.** The NPC counts in it are §7.1's assumptions —
      there is no crowd until M3, so nothing has ever measured 90 replicated NPCs. Every *record
      size* in the projection is measured; the *entity counts* are not. Left unticked, and
      US-0031's matching criterion stays unticked for the same reason.
- [x] **Upstream miss recorded with its failing test and the coalescing decision logged.**
      `test_upstream_bandwidth.gd` is written and reports the number. See the section below — the
      miss is **253 %, not the 112 % §7.3 predicted**, and the coalescing decision is logged as
      *insufficient on its own*.
- [ ] **Feel check: the local pawn still feels local at 180 ms RTT.** **The owner's, and not
      taken.** The objective half is measured and reported in US-0024: response is **two ticks,
      33.3 ms, at LAN, GOOD, TYPICAL and POOR alike** — identical to the local-only reading,
      because prediction means the network decides when the client is *corrected*, never when it
      *responds*.

      That is not the same statement as "feels local", which no test may make. It needs a
      windowed client, a human, and an artificial delay — and the three-process run above was
      headless, so it could not be taken there either. Left unticked.
- [x] **Risk register re-scored; `RISK-NETCODE` and `RISK-BANDWIDTH` updated.** Both moved, in
      opposite directions, and both for measured reasons. See §4 and §11 of the register.
- [x] **Tag `m2-net` pushed.**

## The upstream finding: 253 %, and coalescing does not fix it

**`NET-C2S-INPUT` is not hand-serialised.** `Snapshot` packs its own bytes, which is why §7.1's
downstream figures can be measured at all. Input goes out as **RPC arguments**, and Godot encodes
those as Variants.

Measured with `var_to_bytes`, the same variant encoder Godot's high-level multiplayer uses:

| | Payload | Total upstream | Against a 16 kbit/s budget |
|---|---|---|---|
| §7.3's assumption | 9 B | 18.0 kbit/s | 112 % |
| **Measured at the gate** | **56 B** | **40.5 kbit/s** | **253 %** |
| With coalescing only | 56 B | 33.8 kbit/s | 211 % |
| ~~Hand-packed, no coalescing~~ | ~~10 B~~ | ~~18.4 kbit/s~~ | ~~115 %~~ |
| ~~Hand-packed **and** coalesced~~ | ~~10 B~~ | ~~11.7 kbit/s~~ | ~~73 %~~ |

> **THE LAST TWO ROWS WERE WRONG, AND US-0095 CORRECTED THEM.** They counted the packed payload as
> reaching the wire raw. A `PackedByteArray` RPC argument costs **8 bytes of Variant wrapper plus
> the payload rounded up to four**, so a 12-byte command costs 20. Hand-packed is **145 %**, not
> 115 %; hand-packed and coalesced is **91 %**, not 73 %.
>
> **A projection is not a measurement.** This table was a projection made one layer *above* the
> thing it described — which is exactly the mistake §7.3 made one layer below, in the same story
> that found it. Hand-serialisation still made the largest single difference available (253 % →
> 145 %), so the decision the gate reached was right; only its arithmetic was not.

**The decision, logged:** coalescing is **not** the fix and must not be built first. §7.3 proposed
it when the payload was believed to be 9 bytes and the 28-byte packet overhead dominated — at
which point halving the packet rate was the whole game. Against a 56-byte payload the overhead is
the *smaller* half, and coalescing leaves the miss at 211 % while costing up to 16 ms of input
latency against an 80 ms feel budget. **Paying latency for 42 kbit/s would be the worst trade in
the project.**

**Hand-serialising `InputCommand` the way `Snapshot` is serialised is the fix**, and it alone
brings upstream to **145 %** (corrected — see above). **Built in US-0095.** Both together reach
91 %, and coalescing became the right second step only once the payload was fixed: packet overhead
alone is 84 % of the budget. That ordering is now recorded in §7.3 and in
`RISK-BANDWIDTH`, and neither is M2's — M2's exit criterion is that the transport is honest about
what it costs, which is now true.

**This is US-0029's defect in the other direction.** There, §7.1's per-record sizes were
unreachable from §4's own field list, and the total was re-derived. Here §7.3's arithmetic is
*correct for the format it assumes* — the implementation simply never used that format, and
nobody had measured which one was on the wire. **A budget is a claim about an implementation, and
an unmeasured one describes the document rather than the program.**

## What the hand run retired

**US-0037's timeout criterion.** It was left unticked as needing two processes: *"a timeout is
handled identically to a clean disconnect."* A client was killed hard — no disconnect packet, the
peer simply stops answering, which is exactly the timeout path — and roughly ten seconds later
(`TUN-NET-TIMEOUT` is 10 s) the server logged:

```
[net] Net: peer 843868542 left
[pawn] pawn freed for peer 843868542
```

the same `Net.peer_left` → `_on_peer_left` → `pawns.despawn` sequence a clean disconnect takes.
There is **one signal and one handler**, so "identically" is structural; what was missing was
evidence that a timeout reaches it at all, and that is now on record.

A *graceful* client quit could not be exercised: a headless process has no window to receive a
close request, so the only departure this run could produce was the timeout. That is enough for
the criterion as written, and the limit is stated rather than glossed.

## Test notes

The feel check is manual and cannot be automated. A pawn can pass every latency test and still
feel wrong.

`test_upstream_bandwidth.gd` reports its miss as **`pending()` rather than a red failure**, which
is the same choice `test_snapshot_size.gd` made and for the same reason: it is a design finding,
not a defect in any file a red suite would point at, and **a permanently red test is one somebody
eventually deletes**. §4.1's "expected to FAIL" is honoured as a recorded, visible pending with
the number in the message. Recorded here rather than reinterpreted quietly.

## Notes

The upstream budget miss is expected here, not a surprise. Decide on coalescing with the latency
measurement in hand rather than deferring it silently. — **Decided: not coalescing first. The
payload, not the packet rate, is the problem.**
