---
id: US-0036
title: Headless 3-client integration harness
version: 1.1.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-15
depends_on: [BIBLE-TEST-PLAN, TDD-12-BUILD]
---

# US-0036 — Headless 3-client integration harness

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | — |
| **Estimate** | M |
| **Depends on** | US-0035 |

## Description

Spawn a real server and three real clients in-process and drive them with scripted input,
exercising the actual netcode rather than a mock.

## Everything is the shipping object except the wire

`client_root.tscn` with its real `LocalPawnDriver` and `Reconciler`, a real `PawnHost` driving
`pawn_server.tscn`, a real `SnapshotBuilder`, and **real `Snapshot` bytes** between them — the
format is where the information rules live, so a harness that passed objects would prove nothing
about what actually travels.

**Only the wire is synthetic**, and only because it has to be: `Net` is an autoload, so one
process holds exactly one of it, and an RPC resolves by node path. The harness carries commands
and snapshots itself, holding each for a chosen number of frames — which is also what makes
latency a dial rather than a network condition nobody can reproduce.

## This is what retires "verified by hand"

US-0025, US-0028 and US-0030 were each proven by launching processes and reading their logs.
That was real evidence and it is written down in each story. What a log cannot do is **fail a
pull request**.

## Acceptance criteria

- [x] `IntegrationHarness` provides `start`, `drive`, `advance`, latency selection and
      per-peer agreement. **The harness measures; the test asserts** — an `assert_all_peers_agree`
      inside the helper would produce a failure message naming the helper rather than the peer,
      so it returns `disagreement(peer)` and `worst_disagreement()` instead.
- [x] Four latency profiles: LAN, GOOD, TYPICAL, POOR — 1, 3, 6 and 11 frames of one-way delay
      at the 60 Hz physics rate. **Test parameters, not tunables**: nothing a player experiences
      reads them.
- [ ] **Every netcode test runs at all four.** Only the harness's own three-client agreement test
      does. The reconciliation suite runs its own four profiles separately, and the rest of the
      netcode tests are pure and have no wire to give a latency to. Left unticked rather than
      reworded.
- [x] Suite completes in at most 180 s — **87.7 s** for the whole integration suite, 104 s for
      all three suites together.
- [x] Runs headless in CI on pull requests.

## The harness's server clock never ticked

**Found in US-0031, 2026-08-15.** `IntegrationHarness` never advanced `ctx.tick`, so **every
snapshot it built from this story onward carried `server_tick = 0`.**

Nothing depended on it and nothing failed. The reconciler orders by `last_acked_seq`, not by tick;
`RemotePawns` — the one thing that derives a timeline from `server_tick` — is not in the harness's
delivery path at all, since `_arrive_downstream` hands the snapshot straight to the `Reconciler`.
So a server whose clock was frozen at zero produced a suite that passed for two stories.

Delta encoding was the first thing to read it. It found a client whose newest assembled tick was
permanently zero, so the ack was zero, no baseline was ever usable, and **the server sent a full
snapshot every tick while five of the six new tests passed.** The sixth was written first and
exists only to catch that.

The harness derives its clock the way `MatchDirector` does now — one net tick every second physics
frame, counted rather than timed.

**The lesson is about harnesses specifically:** a fake whose unused fields hold plausible defaults
is a fake that lies the moment somebody starts using them. Zero is a plausible tick.

## `disagreement()` measured the wrong thing, and three tests believed it

**Found in US-0035, 2026-08-15.** The harness's headline API returned the distance between the
client's live position and the server's live position, and three tests compared it against
`TUN-NET-RECONCILE-THRESHOLD`.

**In a predicting architecture that distance is never zero and is not an error.** The client
simulates input the instant it is pressed; the server has not seen it yet. What was being measured
is the **prediction lead** — a healthy one is non-zero, and it grows with speed.

Measured: **0.0733 m at stroll and 0.1500 m at run — exactly 2.00 commands at both** — against a
threshold of 0.10 m, while the reconciler's own error over 120 samples was **0.00000 m**. So the
assertions passed only because the harness never drove faster than a walk, and were one speed rung
away from failing over a defect that did not exist.

Renamed to `prediction_lead()`, with `reconciliation_error()` added beside it reading
`Reconciler.last_error` — the comparison in which both sides describe the same moment. All three
call sites repointed.

**Trap 4, in the harness written to catch trap 4**: the assertion was true, and it was not the
question.

## What building it found

**The first version added every node twice.** The harness parented its nodes to the test and
returned them, and the test adopted them again — `Condition "p_child->data.parent" is true` on
every client. The harness owns what it makes now and frees it in `tear_down()`, which matters
beyond tidiness: GUT frees a test instance between *scripts*, not between tests, so three clients
would have become six, all still driven and all still sampling the same input. That is the same
defect the reconciliation suite hit from the other direction.

**And a comment in this file was wrong before the code was.** It said a poor profile ought to
produce more replays, or the latency dial was not connected to anything. Measured: **zero
replays, at every profile**, and that is the right answer — the client and the server run
identical code from identical commands, so *being late is not the same as being wrong*. What
latency actually costs is how stale a correction is when one is genuinely needed. The test now
asserts zero and says why.

## What it does not do: per-client input

Every client samples the same global `InputMap`, so they all receive the same command on a given
frame. They are genuinely different pawns — different spawns, different positions, independent
histories and reconcilers — but scripted **divergent** input needs an injectable sampler, which
is its own change and is not pretended to here.

## Test notes

| Test | Asserts |
|---|---|
| `test_integration_harness.gd` | Three clients agree with the server at all four profiles; three clients really are three pawns with three wire slots; they really moved; **latency alone costs no corrections** |

**`test_frame_rate_independence.gd` is NOT built, and the reason is worth reading.** It was
specified to run a match at 30, 60 and 144 fps *display* rates — and a headless process has no
display rate to vary, so the test as written cannot exist here. The property it was to prove is
guarded structurally instead: `test_no_gameplay_in_process.gd` forbids `_process` anywhere
server-side outright, so gameplay **cannot** be on the render clock rather than merely not being
on it today. That is a stronger guarantee than a three-rate comparison, and it is not the same
guarantee — a client-side visual that read gameplay state per frame would still slip past it.
Recorded, not rounded up.

## Notes

A mock cannot surface prediction bugs, because the bug IS the difference between two real
implementations of the same step function.
