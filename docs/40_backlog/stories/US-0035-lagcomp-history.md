---
id: US-0035
title: Lag compensation history buffer
version: 1.0.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-15
depends_on: [ADR-0010, TDD-04-NET]
---

# US-0035 — Lag compensation history buffer

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-PREDICTION` |
| **Systems** | `SYS-NET-LAGCOMP` |
| **Estimate** | S |
| **Depends on** | US-0034 |

## Description

A 500 ms ring buffer of pawn and NPC transforms, recorded every tick. **Recording only** — kill
and stun do not exist until M4.

Building it early means the buffer is proven before anything depends on it, and the M4 work is
validation logic rather than infrastructure.

## The story's one real correctness property: which tick a frame belongs to

Everything else here is a ring buffer, and ring buffers are easy. The part that could be silently
wrong for two milestones is **what tick number a recorded transform carries.**

A rewind resolves against a tick a client observed **in a snapshot**. If the history and the
snapshot are stamped on different timelines, every rewind reaches one tick further into the past
than it asked for — past the ceiling `TUN-NET-LAGCOMP-MAX` exists to impose — and **nothing fails
until M4**, in code nobody would then suspect.

So the first thing this story did was measure where the snapshot's timeline actually is.

## What that measurement found

**The snapshot was built BEFORE the tick's stage loop, not after.** `MatchDirector` emitted a
single `net_ticked` at the top of `_net_tick()`, and `SnapshotBuilder.send_all` was connected to
it — so a snapshot stamped tick N carried the world from the end of tick N−1.

**Two comments claimed the opposite.** `server_root.gd` said *"LAST in the tick, so every record
carries the position this tick ended at"*, and `snapshot_builder.gd` repeated it. Both had been
there since US-0030.

**Nothing was broken, and that is why it survived.** Measured over 120 samples at run speed, the
client's reconciliation error was **0.00000 m** — the snapshot was internally *consistent*, its
`own_position` and its `last_acked_seq` describing the same moment. The only symptom was the
**label**: `RemotePawns` derives `server_time` from `snapshot.server_tick`, so every remote entity
was drawn one tick further into the past than `TUN-NET-INTERP-BUFFER` declares — an effective
**133 ms against a documented 100**.

`MatchDirector` now has two signals. `net_ticked` fires before the stages, `tick_completed` after
them, and both the snapshot builder and the history hang off the second.
`test_tick_completed_is_last.gd` asserts the emission order directly, because this exact claim was
reasoned about twice and written into two comments, and was wrong in both.

## Acceptance criteria

- [x] **15 entries at 30 Hz, 2.5× the maximum 200 ms rewind.** Derived from
      `TUN-NET-LAGCOMP-HISTORY` at the server tick rate, never written as `15` — a hardcoded
      length would let somebody widen the rewind ceiling and discover at M4 that the ring had
      quietly stopped reaching far enough.
- [ ] **Records pawn and NPC transforms every tick.** Pawns yes, **NPCs no** — and as of
      US-0060 the reason has changed from "there is no crowd yet" to **"nothing would read
      them"**. §8.2 rewinds NPC positions "because they determine LOS occlusion and blend
      membership", and both premises are false in the built game: `has_los` masks `WORLD`
      only, so NPCs cannot occlude by construction (GDD-03 §9.2, US-0056), and a blended
      player is killable normally (GDD-02 §3.2 rule 3). Kill validation performs no
      line-of-sight query at all. Recording 78 NPC transforms a tick would take the ring from
      **28.1 KB to about 130 KB** for no consumer. `LagCompRecorder._gather()` is still where
      they would join. Left unticked rather than reworded, and the amendment is in ADR-0010
      and TDD-04 §8.2.
- [x] **`rewind(tick, around, radius)` returns a `RewoundWorld` for entities near a point only.**
      §8.3's optimisation: fewer than 10 entities per validation rather than 96, which is what
      decides whether lag compensation is affordable per kill.
- [ ] **Memory stays around 23 KB.** Measured at **28.1 KB** for 96 entities × 15 ticks — 20 bytes
      per record against §8.3's 16. The id is **stored rather than implied**: a dense array
      indexed by wire slot would be four bytes cheaper and would name the wrong player after a
      rejoin, which is exactly the inheritance failure US-0037 exists to prevent. §8.3 is amended
      with the measured figure; the criterion is left unticked because it is not true as written.
- [x] **The invariant `lagcomp_max <= history / 2` is asserted.** Invariant 16 was already in
      `TuningInvariants`, and `test_all_cross_field_invariants_hold` would pass identically if it
      had never been written — so `test_the_lagcomp_invariant_is_live` now **falsifies** it against
      a raised ceiling.

## Why the ring is pure and the recorder is not

`LagCompHistory` takes plain arrays and returns a `RewoundWorld`. It holds no pawns, reaches no
autoload but `Tuning`, and knows nothing about a crowd it will one day record.

`LagCompRecorder` is the half that walks the world, and it is a separate object for the reason
`RpcRouter` learned in US-0026: **a buffer whose contents arrive through a global cannot be asked
a question in a test.** Every assertion about rewinding is written against data the test chose,
so a rewind test fails for rewind reasons.

**The recorder keys by peer, not by wire slot.** The slot is what a snapshot names a player by and
it is reused the moment somebody leaves — a rewind resolving a kill against slot 3 could name the
player who inherited it rather than the one who was there.

## What `RewoundWorld` deliberately cannot carry

Positions and yaw. Not suspicion tier, not contract assignment, not cooldowns — §8.2 keeps all
three **current**, because each would hand an attacker something the present has already taken
away: a tier the victim has left, a contract no longer theirs, a cooldown already spent.

The way to keep that true under a year of M4 pressure is to have nowhere to put them.

## An absent entity is not reported at the origin

`RewoundWorld.position_of()` defaults to `Vector3.INF`, not `Vector3.ZERO`. At M4 a kill validated
against the origin would succeed from anywhere in the district for anybody standing near the
corner of the map. The fallback has to be unmistakable rather than plausible.

## Test notes

| Test | Asserts |
|---|---|
| `test_lag_comp_history.gd` | The ring is 15 entries and derived from tuning; it covers 2× the max rewind; an empty history answers with an **empty world, not null**; a rewind returns the *past* and not the present; the oldest frame is overwritten rather than the ring grown; the radius excludes distant entities; an absent entity is `INF` and not the origin; a tick past the ring **clamps** rather than failing; the memory is measured |
| `test_tick_completed_is_last.gd` | `net_ticked` → pawn substeps → `tick_completed`, in that order; both fire once per tick; **nothing completes in the lobby** |
| `test_lag_comp_records_the_world.gd` | A real director and a real `PawnHost` over the district's collision fill the ring; the newest frame is where the tick **ended**; the oldest frame is genuinely behind the newest; two pawns record separately; a **departed pawn stops being recorded**; the lobby is not recorded |
| `test_tuning_ranges.gd` | Invariant 16, falsified against a raised ceiling |

Rewind *correctness* — a kill valid at 150 ms and invalid at 250 — is M4's `test_lagcomp_rewind.gd`
and is not attempted here. There are no consumers to be correct for.

## Notes

Rewinding only entities within about 7.5 m of the action keeps the per-validation cost at fewer
than 10 entities rather than 96.

**A tick outside the ring clamps rather than failing.** §8.1's own clamp should make that
unreachable; if it is ever reached, the safe answer is the oldest world actually held — which is
*less* far into the past, never more — rather than an error that fails a legitimate kill.
