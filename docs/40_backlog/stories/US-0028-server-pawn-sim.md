---
id: US-0028
title: Server-side pawn simulation
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-20
depends_on: [ADR-0002, TDD-04-NET, TDD-06-PAWN]
---

# US-0028 — Server-side pawn simulation

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-TRANSPORT` |
| **Systems** | `SYS-PAWN`, `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0027 |

## Description

The server instantiates a PawnServer per peer and drives it with received InputCommands, using
the identical state machine the client predicts with.

## The same code, not merely the same state machine

ADR-0008 requires the server and the client's prediction to run the same `PawnStateMachine` and
the same `PawnState` classes. **They always did — and that was only half a tick.**

The other half is the fifteen lines that decide who owns position during a traversal, when
gravity applies, and what is written back from the physics body. Those lived in
`LocalPawnDriver` alone. Writing a second copy for the server would have been a divergence in
prediction with a green suite on either side of it: **every unit test calls `step()` directly and
never reaches that code at all** — which is trap 7's family, and how a vault that computed a
perfect arc and never moved the pawn passed every test in US-0019.

So it was extracted to `PawnMotion`, and both drivers call it. That is the story's real content;
the rest is wiring.

## Decisions taken here

### The repeat rule walks `ctx.pawns`, not the queues

A peer with a pawn and an **empty** queue is exactly the case the repeat exists for, and that
peer has no queue entry to be found by.

### A peer that has never sent a command is not stepped

There is no intent to extend. `InputCommand.empty()` is not "the player is standing still" — it
is "we have never heard from them", and a pawn that has not yet moved must not start.

### Spawn selection is a placeholder and says so

`SYS-SPAWN` (US-0062) decides *where* a pawn appears, from the contract cycle and the crowd.
`PawnHost` places one at a declared point, round-robin, so that M2 has something to replicate.
Any part of the real rule here would be a rule in the wrong layer.

## Acceptance criteria

- [x] One `PawnServer` per connected peer, spawned on join, freed on leave. Spawning twice is
      refused: a second hello must not leave two pawns simulating against the same inputs, one of
      which nothing would ever free.
- [x] Input queued per pawn and applied in sequence order, two substeps per net tick.
- [x] The server runs the SAME `PawnStateMachine` and `PawnState` classes as the client — **and
      the same `PawnMotion`**, which is the half that was not shared before.
- [x] Missing input for a tick repeats the last command rather than stalling.
- [x] The server is authoritative over position, velocity and state — the client never writes
      them. There is no path by which a client's number reaches `ctx.position`: the only thing
      that arrives from the wire is an `InputCommand`, and every field of it is a button or a
      stick.
- [x] Traversal probes run server-side against the same WORLD layer.

## What the tests found

**`test_pawn_host.gd` failed on its own probe assertion the first time it ran**, and the failure
was worth more than the test. `PawnHost` in isolation has no world geometry — so every pawn in
that file was *falling*, and `test_input_moves_the_authoritative_pawn` was passing on it. "The
pawn moved more than half a metre" is true of a pawn dropping out of the district. **Trap 4, in
the same shape it took in US-0019.** The file now instantiates the map's collision, asserts the
travel *horizontally*, and asserts the pawn is still grounded at the end.

## Test notes

| Test | Asserts |
|---|---|
| `test_substep_matches_server.gd` | The real client and the real server, given the client's own sampled commands, land in the **same place** — not merely within `TUN-NET-RECONCILE-THRESHOLD`. Through a speed change too, which is where a mismatched `dt` shows first |
| `test_pawn_host.gd` | A real pawn from the real scene; one per peer; spawning twice refused; input moves it horizontally and leaves it grounded; the probes see the district |
| `test_match_director.gd` | A missing command repeats the last one; a full tick is not padded; a peer that has never sent one is not stepped |

The story asked for the divergence to be *within* the reconcile threshold. It is zero, and both
are asserted separately — so if float error ever does creep in, the file says whether it matters
or merely exists.

## Test notes

`test_substep_matches_server.gd` asserts a client predicting two 1/60 substeps lands within the
reconcile threshold of a server applying the same two commands.

## Notes

Repeating the last command on a missing input rather than stalling is deliberate: a stalled pawn
produces a position the client cannot have predicted, guaranteeing a reconciliation every time a
packet drops.

## The input queue paid for a late command twice (2026-08-20)

Landed under this story after the owner reported *"I press D to go right and it feels as if S is
tapped in between"*. Two defects, and the second was caused by the fix for the first.

1. **A LATE COMMAND WAS PAID FOR TWICE.** `_drain` applied the whole queue and `_repeat_last` then
   padded any tick that received fewer than `_frames_per_tick` with a **stale repeat**. Arrival is
   bursty even on localhost, so a tick that got one command applied `[new, stale-repeat]` and the
   next applied all three of its arrivals on top - **five steps for four commands**, measured as
   the applied sequence `[1, 1, 2, 3, 4]`. The extra step integrates a direction the client never
   predicted. The repeat is right for a **lost** command and wrong for a merely **late** one, and
   late is the common case.
2. **AND CAPPING THE DRAIN CAUSED A SECOND DEFECT.** A deficit became unrepayable, since the client
   produces exactly `_frames_per_tick` per tick, so every starved tick added *permanent* lag -
   measured from the controls as a mean reconciliation error of **0.068 m biased BACK**, under
   `TUN-NET-RECONCILE-THRESHOLD` so it never snapped and never corrected. One command is 7.5 cm at
   `TUN-SPEED-RUN`, which is that number. `CATCH_UP` is 1: a deficit of N clears in N ticks.

**`CATCH_UP` IS THE ONE PLACE A CLIENT'S SEND RATE COULD BUY DISTANCE**, since every applied command
is a step of movement. Bounded twice - the queue is capped by `TUN-NET-INPUT-BUFFER-SIZE` and
`SequenceGate` refuses replays - but **nothing checks a client's send rate**, and that belongs with
US-0026's authority work. The pre-US-0028 code drained the whole queue and was strictly more
exposed.

The overlay built to find this is `scripts/debug/net_readout.gd`, attached by `LocalPawnDriver` in
debug builds only. Its baseline is exact: standing still, 300 comparisons, error 0.000 m, 0 replays.

The owner's verdict on the result: *"It works perfectly."*
