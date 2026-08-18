---
id: US-0030
title: SnapshotBuilder — culling and quantisation
version: 1.0.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-18
depends_on: [ADR-0007, TDD-04-NET]
---

# US-0030 — SnapshotBuilder: culling and quantisation

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-SNAPSHOT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0029 |

## Description

Per-client snapshot construction with distance culling and quantisation. Per-client rather than
broadcast because render_state and compass data are per-observer.

## The loop closes here

This story was built to **close the loop end to end** rather than in its own order, because
nothing had been observable since M1 and nine of the ten defects in this project were found by
looking at the game. `InputSender` and `RemotePawns` are pulled forward from US-0032 and US-0034
for the same reason, and both are deliberately minimal — the parts that make them *good* are
still their own stories.

Two real processes, on 2026-08-14:

```
SERVER  server topology wired: net -> router -> director -> pawns -> snapshots
SERVER  Net: peer 1660290033 welcomed — 1 player(s)
SERVER  pawn spawned for peer 1660290033 at (12, 0, 36)
SERVER  Net: peer 400847904 welcomed — 2 player(s)
CLIENT  Net: welcomed as peer 1, map 0, phase 2, tuning 1057634729
CLIENT  client is slot 1
CLIENT  remote pawn appeared in slot 2
```

## The client could not send anything at all

**Godot addresses an RPC by node path, and the receiving peer looks up the same path.**
`RpcRouter` sat at `/root/ServerRoot/NetServer/RpcRouter` — a path that does not exist on a
client — so there was no node for a client to call it from, and `NET-C2S-INPUT` was unsendable.
US-0026 built the whole authority chokepoint and nothing had ever reached it. The handshake
worked only because `Net` is an autoload at `/root/Net` on **both** peers.

**The doorway moved to `Net`; the decision stayed with the router.** Every handler there calls
`RpcRouter.authorise()` first and `test_no_client_authority.gd` still refuses one that does not —
the guard's needle changed from `_authorise(` to `authorise(`, and the method is public now
because a private-by-convention method called from another object is worse than an honest public
one.

The general answer, worth knowing before the next surface needs one: **anything the `Net`
autoload creates in `_ready()` is at the same path on every peer too.** `PingClock` is the first
to use it, and it is why the ping/pong could move out of a file that had reached 400 lines.

## Decisions taken here

### The welcome carries the slot, not the peer id

`NET-S2C-WELCOME` declares `peer_id:u8` and Godot's peer ids are 32-bit. What a client is told is
its **wire slot** — the number every other message will use to name it. `GameState.local_peer_id`
holds that.

### `MatchContext` carries the slot table

`SnapshotBuilder` asked `Net.slot_of()` at first, and its test could not then set up a two-player
match: every assertion collapsed to "there is no slot", which stays true whatever the builder
does. **The same mistake the router made in US-0026**, and the same fix — if it is not on
`MatchContext`, a system cannot reach it.

### Remote pawns snap; they do not interpolate

`SnapshotInterpolator` is US-0034 and it is the story that makes this look right. Snapping first
is deliberate: it makes the wire visible before the thing that smooths it, so a replication bug
cannot hide inside an interpolator.

### Absence is the signal that a player left

There is no "player left" record in the snapshot. A client that missed one reliable message would
keep a ghost forever; a client that misses one snapshot recovers on the next.

### The match starts immediately, and that is a placeholder

`SYS-MATCH` owns the phase and it is M4's. Until it exists a server stuck in `LOBBY` would
authorise no input and simulate nothing, so `server_root.gd` sets `ACTIVE` and says so.

## Acceptance criteria

- [x] One snapshot built per client per tick — from `MatchDirector.net_ticked`, at the `snapshot`
      stage, **last**, so every record carries the position the tick ended at.
- [x] **Entities beyond the `TUN-NET-NPC-CULL-RADIUS` cull radius are omitted for that client.**
      Built against the real crowd. `test_snapshot_culling.gd` asserts it, and **the counterfactual
      first**: a scenario with NPCs only on one side of the line satisfies the rule vacuously, and
      so does a builder that sends nothing at all — which is what this one did for two
      milestones, with these three criteria unticked and nothing red. Falsified both ways against
      a planted defect.
- [x] The cull radius is ≥ compass range, asserted as an invariant. **Invariant 17**, and it has
      asserted since M0 — this criterion was already true and merely unticked.
- [x] Culling is POSITIONAL, not visual. Asserted by turning the observer through 180° and
      requiring the same set. **A visual cull would let a player infer, from an NPC popping in,
      that they had just been handed a fresh piece of the district.**
- [ ] **`render_state` computed per observer pair.** The loop is already per observer — which is
      the whole reason this is not a broadcast — and the field is filled with `PLAIN` for
      everyone until `SYS-DETECTION` lands in M3. Unticked because "computed" is not "carried".
- [x] `last_acked_seq` included per client, from the router's sequence gate.

## What the first two-process run found

**`NET-S2C-WELCOME` was sending `GameState.phase` — the CLIENT's read-only mirror — from the
server.** Every joiner was told `LOBBY` while the match was running. Visible in one line of the
log (`phase 0`) and invisible to every test, because no test reads a welcome. The server's own
answer lives with the thing that gates rules on it, so the router now exposes `phase()`.

## Test notes

| Test | Asserts |
|---|---|
| `test_the_loop_closes.gd` | A snapshot carries the other player and **not** the observer; the own block is full and unquantised; the bytes survive the wire and place a real node; a departed player is freed; the sender pushes every sampled command |

`test_npc_cull_radius.gd` asserts the invariant, and waits for culling to exist.

## Notes

70 m exceeds the 60 m compass range so a culled entity can never affect anything the client could
perceive. Visual relevance culling was considered and rejected: pop-in when LOS is established is
a worse artefact in a game about spotting people than the wallhack it would prevent.
