---
id: US-0025
title: Net autoload and peer lifecycle
version: 1.0.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-14
depends_on: [ADR-0002, TDD-04-NET, BIBLE-NET-PROTOCOL]
---

# US-0025 — Net autoload and peer lifecycle

| | |
|---|---|
| **Milestone** | M2 — **the first story in it** |
| **Epic** | `EPIC-TRANSPORT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0024 |

## Description

`ENetMultiplayerPeer` setup, the three channels, peer join and leave, RTT measurement, and the
handshake.

## The shape it was built in

**The decisions are pure; the wiring is not.** `Handshake` and `Messages` hold every branch that
*decides* something — which channel a message travels on, whether a peer is admitted, whether the
server must correct its tuning — and neither touches a socket, a node or an autoload. `Net` is
what carries those answers to a connection.

That split is why five of the seven criteria below are proven by unit tests that stand nothing
up. What is left in `Net` is only the part a real transport must be running to reach.

### Two disagreements, two different answers

| Disagreement | Answer | Why |
|---|---|---|
| Protocol version, build hash | **reject, with a reason** | The peers cannot read each other's packets. Continuing produces garbage that looks like line corruption |
| Tuning hash | **correct the client, never kick** | The client can read everything; it merely holds different numbers, and the server can send it the right ones |

`Handshake.check()` does not take a tuning hash **as an argument at all**. That is the strongest
available statement of the rule: there is no parameter through which tuning could ever refuse a
peer.

### A socket is not a player

A peer that has connected at the transport level has proved nothing. `Net.player_count()` counts
peers that completed `NET-C2S-HELLO`, and the server sends a connected socket nothing but a
welcome or a rejection until it has spoken.

## Decisions taken here, and what they cost

### `build_hash` is derived from the protocol surface

**The corpus asks for a `build_hash:u64` and never says where it comes from.** Two readings:

1. A CI-stamped build id. Rejects two builds that differ in a shader; accepts two that differ in
   the wire format. That is backwards for a check whose job is "can we read each other".
2. A hash over the protocol surface itself — the version, the message catalogue and channel
   assignments, and the `InputBits` wire order.

**Taken: (2).** It is computable identically on both peers with no build system at all, and it
covers exactly what a mismatch breaks. **Open question:** if a release ever needs to refuse an
older client that happens to share a wire format — for an anti-cheat or a hotfix reason — this
cannot express it, and a stamped id would have to be added beside it rather than instead of it.

### `NET-C2S-HELLO` gained a third field

`tuning_hash:u64`. The catalogue says `NET-S2C-TUNING-SYNC` is sent **on mismatch**, and a server
that never learns the client's hash could only send it *always* or *never*. Always is six
kilobytes on every join and hides a real disagreement inside a routine transfer.

Both protocol documents are updated. Nothing was on the wire yet, so this breaks no peer.

### RTT has two sources, deliberately

The **server** reads ENet's own continuously measured statistic. The **client** smooths its own
ping/pong samples in `RttTable`.

Not redundancy — a refusal. Lag compensation rewinds the world by an amount derived from RTT, so
an RTT a client could inflate is an RTT a client could use to reach further into the past.
`client_time` is client-supplied and therefore forgeable (§2.2), so the server never folds it into
anything. ADR-0010's whole argument, applied one layer down.

### `NET-S2C-COMPASS` is left without a channel

GDD-03's acceptance criteria name it as a payload to inspect. The protocol catalogue has no row
for it, and TDD-04 §10 says compass data is per-observer and **rides in the snapshot**. Two
readings, one of which means a message that does not exist. Giving it a channel here would settle
a design question by implementation, so `channel_for()` returns `-1` for it until whoever builds
`SYS-COMPASS` decides.

### `NET-S2C-PLAYER-LEFT` was never an ID

Both protocol tables wrote the pair as ``NET-S2C-PLAYER-JOINED`` / ``-LEFT`` on one row, so the
harvest never saw the second name and `Ids` never declared it. Split into its own row; the ID now
exists. A reminder that **`Ids` is only as complete as the tables' formatting.**

## Acceptance criteria

- [x] Server creates on port 27015 by default, max 6 peers. — `LaunchConfig.DEFAULT_PORT`, passed
      through `boot.gd`; asserted end to end in `test_net_peer_lifecycle.gd`.
- [x] Three channels: STATE unreliable, EVENT reliable ordered, SESSION reliable ordered. — the
      numbers are pinned in `Messages.Channel`, every message's channel is declared in one table,
      and `channel_for()` refuses an ID it has never heard of rather than defaulting to STATE.
- [x] `NET-C2S-HELLO` validates protocol version and build hash; mismatch rejects with a reason.
- [x] `NET-S2C-WELCOME` returns peer id, tuning hash, map id and phase.
- [x] Tuning hash mismatch triggers `NET-S2C-TUNING-SYNC`; the client is CORRECTED, never kicked.
- [x] Peer timeout at 10 s is treated as a disconnect. — `TUN-NET-TIMEOUT` applied per connection
      via `ENetPacketPeer.set_timeout`, floor and ceiling pinned to the same value so ENet cannot
      back off from the number TUNABLES states.
- [ ] **Ping and pong maintain per-peer RTT.** Built, and **the client half is untested against a
      real wire.** `RttTable` is unit-tested; the server half reads ENet and needs no pongs. What
      is unproven is the round trip — see below.

## What is NOT proven, and why it is not ticked

**The full handshake round trip has no automated test, and cannot have one here.** `Net` is an
autoload, so a process holds exactly one of it; an RPC resolves by node path, so a second `Net` at
a second path could not answer the first. Proving `NET-C2S-HELLO` end to end in CI needs two
processes, which is **US-0036's integration harness**.

It *was* run by hand, 2026-08-14, two real processes:

```
SERVER  Net: listening on 28777, up to 6 peers, 3 channels
SERVER  Net: peer 1526710570 connected, awaiting hello
CLIENT  Net: welcomed as peer 1526710570, map 0, phase 0, tuning 1057634729
```

That is evidence, not a guard. `test_net_peer_lifecycle.gd` asserts the half a single process can
reach: the port is really opened, a real ENet client really arrives, and a connected socket is
**not** counted as a player.

## What the hand run found

**Godot's peer ids are 32-bit random numbers**, not the `peer_id:u8` both protocol tables
declare — the run above was welcomed as peer **1526710570**. Nothing is broken today because
nothing is serialised by hand yet, but the snapshot format (US-0029) cannot pack that into a byte.
Either the server maps peer ids onto small slot numbers for the wire, or the schema is wrong.
**Recorded, not decided** — it belongs to whoever builds the snapshot.

## Test notes

| Test | Asserts |
|---|---|
| `test_messages.gd` | Channel numbers are the wire; an undeclared message has no channel; **no forbidden message can be sent**, in both directions |
| `test_handshake.gd` | Admit, both rejections, the order they are checked in, and that tuning can never refuse |
| `test_rtt_table.gd` | First sample whole, spikes decay, peers do not share an estimate, a departed peer is forgotten, a negative sample cannot poison it |
| `test_net_peer_lifecycle.gd` | The port opens, a real client connects, **a socket is not a player**, `stop()` releases the port |

`test_channel_separation.gd` — a reliable flood not delaying snapshot delivery — needs a snapshot
stream to delay. It belongs with US-0030.

## Notes

The channel split matters most under packet loss. Without it a retransmitted score event would
delay every subsequent snapshot, and the symptom would be remote players stuttering whenever
anyone scored — a networking bug that looks like a gameplay bug.
