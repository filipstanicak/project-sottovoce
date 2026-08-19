---
id: US-0031
title: Delta encoding and rate LOD
version: 1.0.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-18
depends_on: [ADR-0007, TDD-04-NET, BIBLE-PERF-BUDGET]
---

# US-0031 — Delta encoding and rate LOD

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-SNAPSHOT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0030 |

## Description

Send only entities whose quantised state changed since the client's last acknowledged snapshot,
and send distant entities at a reduced rate.

## The protocol had no way for a client to acknowledge a snapshot

`NET-C2S-INPUT` carried no ack and the snapshot header had no baseline field, so the first half of
this story was a protocol decision rather than an implementation.

**`client_tick:u16` paid for it, and cost nothing.** That field was specified as advisory-only —
ADR-0010's §4 open question asked whether it should be sent at all, and answered *"keep for
diagnostics"*. In practice `InputSampler` set it to `_seq`, and `test_input_sampled_once.gd`
asserted the two were **identical**. It was two bytes of a number already in the packet, sent at
60 Hz, on an upstream budget already at **112 % of `TUN-NET-BUDGET-UP`** (17.9 against 16 kbit/s).

It is `acked_tick` now: the newest snapshot tick the client has assembled. Upstream is unchanged,
and TDD-03 §4's open question is closed.

**The forgeability rule is untouched.** It is still client-supplied and still orders nothing;
contests resolve on the server receive tick. What a lying client gains is a delta it cannot
assemble, which it then cannot acknowledge, so the server falls back to a full send. **It can
waste its own bandwidth and nobody else's.**

## The baseline is what the client acknowledged, never what was last sent

Snapshots ride the unreliable `STATE` channel, so *sent* says nothing about *arrived*.
Delta-ing against the last **sent** snapshot is the classic version of this bug: it works
perfectly until one packet drops, and from then on every delta is applied to a baseline the client
does not have. It does not reproduce on a LAN, and the symptom is a remote player frozen or
teleporting on a connection that looks healthy.

If the client's ack stops advancing, `SnapshotDelta` keeps using that older baseline — which the
client demonstrably holds, because it acknowledged it — and the deltas simply grow. Past
`Snapshot.MAX_BASELINE_AGE`, or with no ack at all, it sends the whole world. **There is no path
that produces a delta the client cannot apply.**

## `present_slots`: the one field delta encoding made necessary

Before this story, *absent from the snapshot* meant *gone*. It now means *unchanged*. Without a
separate statement of who exists, a player who disconnects **while standing still** is omitted for
being unchanged and is never freed — they stand in the district for the rest of the match.

One byte, one bit per slot, written even on a full snapshot where the records imply it: a format
whose shape depends on a flag is a format that gets read wrong on the branch nobody tested.

## Acceptance criteria

- [x] **Per-client acknowledged-snapshot bookkeeping.** `SnapshotDelta`, pure — records in,
      records out — so what a delta omits can be asked directly rather than by standing a server
      up. Released on disconnect, because ENet reuses peer ids and an inherited baseline is one the
      new peer never received.
- [x] **An entity whose quantised state is unchanged is omitted.** **Quantised** is the load-
      bearing word: comparing the `Vector3`s would be wrong in both directions — 3 mm rounds to the
      same centimetre and would be sent as a change nobody could see, while a yaw crossing a 1.4°
      boundary changes its byte where `is_equal_approx` says it did not.
      `Snapshot.remote_fingerprint()` lives beside the writer so the two cannot come apart, and a
      test asserts equal fingerprints serialise to identical bytes.
- [x] **Entities beyond 45 m are sent at 10 Hz rather than 30 Hz.** **Built**, and **scoped to
      NPCs on purpose.** §7.1 budgets remote pawns at
      30 Hz with no LOD, and §7.2 justifies the 10 Hz tier by *"those NPCs are outside all
      gameplay radii anyway"*, which is not true of a **player** at 46 m. Applying this criterion
      to players as written would be a design error. It lands with `SYS-CROWD` in M3.
      — **AND IT WAS WORTH 36 POINTS: 155 % → 119 %.** §7.2's two numbers were bare prose with no
      `TUN-` IDs, because until US-0030 there was no crowd for the rule to apply to; they are
      `TUN-NET-NPC-RATE-LOD-RADIUS` and `TUN-NET-NPC-RATE-LOD-HZ` now, with the document's own
      values, plus invariants 30 and 31.
      **THE STAGGER IS THE HALF THAT WOULD HAVE SILENTLY NOT HAPPENED.** Sending the whole slowed
      band on one tick divides the *mean* by the stride and leaves the *peak* exactly where it was
      — and **the kbit/s figure is identical either way**, so nothing about the budget would have
      revealed it. Staggered by `(tick + index) % stride`, the shape `CrowdBands` already uses;
      the worst tick carries about a third of the band. TDD-04 §7.1.2.
- [x] **A lost ack degrades to a full send rather than corrupting state.** Both ends. The server
      falls back to full when the baseline is unknown, too old, or discarded; the client **drops**
      a delta whose baseline it lacks rather than assembling a plausible wrong world — and a
      dropped snapshot never becomes an ack, so the error cannot fail to converge.
- [ ] **Measured downstream is within 96 kbit/s at 6 players and 90 NPCs.** **Now measured, and
      missed: 114.0 kbit/s, 119 %** with culling and rate LOD both built (was 155 % with culling
      alone) (`test_crowd_wire_cost.gd`, on the real builder's serialised
      bytes at the worst spawn point). The 93.5 kbit/s / 97 % this line used to carry was a
      projection whose two change fractions had never met a crowd — measured, they are 0.776 and
      0.761 against 0.55 and 0.70, which is 112 % **even with** the two mechanisms above built.
      **What is left is the NPC delta, and it is worth about seven points** — 119 % as built
      against 112 % projected — because **0.776 of visible NPC records change every tick anyway**.
      **It needs a protocol change, not just a builder change**: remote pawns carry `present_slots`
      so *absent* can mean "unchanged" rather than "gone", and the NPC block has no equivalent.
      **A change to a bible document, for seven points, against a miss that would still be 12 %**
      — the trade is recorded rather than taken. ADR-0007 and a smaller cull radius are the other
      two candidates and neither is priced. TDD-04 §7.1.1 and §7.1.2.

## What building it found

**Delta encoding was completely inert in the integration harness, and every other assertion passed
anyway.** `IntegrationHarness` never advanced `ctx.tick`, so every snapshot it had ever built
carried `server_tick = 0` — from US-0036 onward. Nothing depended on it and nothing failed: the
reconciler orders by `last_acked_seq`, not by tick.

Delta encoding was the first thing to read it, and it read a client whose newest assembled tick was
permanently zero. The ack was zero, no baseline was ever usable, and **the server sent a full
snapshot every tick while all six tests in the new file passed except one.**

That one was `test_the_stream_really_contains_deltas`, written first and specifically to catch
this. Trap 3's family — a feature silently inert while its suite goes green — and the fifth
instance in this project. The harness derives its clock the way `MatchDirector` does now.

## Test notes

| Test | Asserts |
|---|---|
| `test_snapshot_delta.gd` | No ack means a full send; an unchanged record is omitted and a changed one is not; a new slot is always sent; the comparison is **quantised** (3 mm omitted, 5 cm sent); equal fingerprints serialise identically; a lost ack **grows** the delta and never corrupts it; an unrepresentable or discarded baseline falls back to full; the ack never walks backwards; peers do not share a baseline; a departed peer leaves none behind |
| `test_snapshot_assembler.gd` | A full snapshot always assembles; an omitted record is inherited; **a delta whose baseline is gone is dropped, not guessed**; a dropped snapshot does not become an ack; a vanished slot is not inherited forever; an out-of-order snapshot does not walk the ack back; a chain of ten deltas stays correct; history is bounded |
| `test_delta_encoding_closes_the_loop.gd` | **The stream really contains deltas**; a standing player settles to exactly the 55-byte fixed block with no remote record; a moving player is still sent and still agrees; three clients agree with deltas live; a departing player vanishes; churn leaves no baselines |

`test_crowd_bandwidth.gd` and `test_upstream_bandwidth.gd` are **not written** — both need the
crowd. `test_upstream_bandwidth.gd` is still expected to fail when it exists.

## Notes

Upstream measures ~18 kbit/s against a 16 kbit/s budget. The cause is packet overhead, not
payload — 28 bytes of header carrying 9 bytes of input at 60 Hz. **Repurposing `client_tick` kept
it from getting worse but did not fix it**; the fix is still coalescing two commands per packet,
at up to 16 ms added latency against an 80 ms feel budget. Measure before committing.
