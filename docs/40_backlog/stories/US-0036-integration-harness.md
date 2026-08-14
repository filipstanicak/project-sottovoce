---
id: US-0036
title: Headless 3-client integration harness
version: 1.0.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-14
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
