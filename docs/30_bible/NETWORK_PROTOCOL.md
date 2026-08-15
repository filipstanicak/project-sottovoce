---
id: BIBLE-NET-PROTOCOL
title: Network Protocol — Message Reference
version: 0.1.0
status: draft
owner: Technical Director
last_updated: 2026-08-03
depends_on: [TDD-04-NET, ADR-0002, ADR-0007, ADR-0010]
---

# Network Protocol — Message Reference

> **This document is deliberately duplicated from
> [`../20_tdd/04_networking.md`](../20_tdd/04_networking.md) §6**, because it is looked up
> constantly and a lookup that requires reading a chapter is a lookup nobody does.
>
> The TDD chapter owns the *reasoning*. This document owns the *reference*. If they disagree,
> the TDD wins and this file is a bug — `test_protocol_docs_sync.gd` asserts they declare the
> same messages.
>
> **That guard was claimed here from M0 and only written on 2026-08-15.** For two milestones this
> note told every reader the two documents were checked against each other when nothing checked
> them. No drift had accumulated, which was luck. It compares message **IDs**, not payload
> columns — the two tables carry different columns on purpose, so a row-equality test would fail
> on formatting and be deleted within a week.

---

## 0. `peer_id` on the wire is a slot

**Every `peer_id:u8` in this document is a slot number, not the engine's peer id.** Godot hands
out random 32-bit peer ids; `scripts/net/protocol/slot_table.gd` maps one onto the other, and
**slot 0 is reserved to mean nobody** so an unfilled record decodes as absent rather than as
player one. See TDD-04 §6 for why the byte was kept rather than the schema widened.

---

## 1. Transport

| Property | Value |
|---|---|
| Peer | `ENetMultiplayerPeer`, dedicated server, star topology. **No peer-to-peer traffic ever** |
| Port | 27015 default (`--port`) |
| Max peers | 6 (`TUN-LOBBY-MAX-PLAYERS`) |
| Timeout | 10.0 s (`TUN-NET-TIMEOUT`) → disconnect, cycle repaired |

### 1.1 Channels

| Ch | Mode | Carries | Why separate |
|---|---|---|---|
| **0 `STATE`** | Unreliable, unordered | `NET-S2C-SNAPSHOT`, `NET-C2S-INPUT` | Highest volume. Stale data is worthless; retransmission would deliver an old snapshot after a fresh one |
| **1 `EVENT`** | Reliable, ordered | Kills, stuns, score, contracts, ability starts, phase changes | Must arrive, in order. A lost `SCORE-EVENT` is a score that never existed |
| **2 `SESSION`** | Reliable, ordered | Handshake, lobby, tuning sync, join/leave | Low volume, correctness-critical |

**The split matters most under packet loss.** Without it, a retransmitted score event would delay
every subsequent snapshot, and the symptom would be remote players stuttering whenever anyone
scored — a networking bug that looks like a gameplay bug.

---

## 2. Client → Server

**Every row must have a non-empty authority check.** `test_no_client_authority.gd` fails
otherwise.

| ID | Ch | Rel | Rate | Payload | Authority check |
|---|---|---|---|---|---|
| `NET-C2S-HELLO` | X | Rel | once | `protocol_version:u16`, `build_hash:u64`, `tuning_hash:u64` | Version and build must match; else reject with reason. **The tuning hash can never refuse a peer** — it is carried so the server can answer a mismatch with `NET-S2C-TUNING-SYNC` instead of always or never sending one (US-0025) |
| `NET-C2S-LOADOUT` | X | Rel | lobby | `persona:u8`, `ability_a:u8`, `ability_b:u8`, `passive:u8` | Rejected unless phase == LOBBY. IDs within the MVP set. Abilities must differ |
| `NET-C2S-READY` | X | Rel | lobby | `ready:bool` | Rejected unless phase == LOBBY |
| `NET-C2S-INPUT` | S | Unrel | **60 Hz** | `seq:u16`, `move:2×i8`, `yaw:u8`, `pitch:i8`, `buttons:u16`, `acked_tick:u16` — **hand-packed, 12 B; see §2.3** | Sender owns a living pawn. `seq` newer than last processed. **Applies to the sender's pawn, looked up from the peer id — never from the payload** |
| `NET-C2S-ABILITY-REQUEST` | E | Rel | on demand | `slot:u8`, `aim_origin:3×f32`, `aim_dir:3×f32` | Slot equipped; cooldown expired **on the server**; GCD respected; aim **clamped** server-side |
| `NET-C2S-BLEND-REQUEST` | E | Rel | on demand | `target_id:u16` | Target exists, within join radius, has capacity |
| `NET-C2S-SKIP-RESULTS` | X | Rel | once | — | Phase == RESULTS. Skip requires **unanimous** consent |
| `NET-C2S-PING` | S | Unrel | 1 Hz | `client_time:u32` | None needed — echo only |

### 2.1 What is absent, and why that is the point

There is no `NET-C2S-KILL`, no `NET-C2S-STUN`, no `NET-C2S-POSITION`, no `NET-C2S-SUSPICION`,
no `NET-C2S-SCORE`.

**Kill and stun are buttons in the input bitfield**, evaluated server-side against the
lag-compensated world. **A client cannot express the concept "I killed someone" in this
protocol.** That is what allows [`../00_meta/SCOPE_FENCE.md`](../00_meta/SCOPE_FENCE.md) OUT #9
to defer all anti-cheat beyond server authority.

### 2.2 `InputCommand.acked_tick` is client-supplied and orders nothing

**It was `client_tick` until US-0031.** That field was specified as advisory-only — sent for
diagnostics — and turned out to be set to `seq`, with an integration test asserting the two
identical. It carried two bytes of a number already in the packet, at 60 Hz, on an upstream budget
already at **112 % of `TUN-NET-BUDGET-UP`**. Delta encoding needed exactly two bytes.

It now carries **the newest snapshot tick the client has assembled** — the baseline the server may
delta against (§4).

The rule that mattered is unchanged. It is client-supplied and therefore **forgeable**, and it is
**never** used to order events or resolve contests; contest resolution uses the **server receive
tick** (ADR-0010). `test_no_client_time_in_kill.gd` asserts `KillSystem` and `StunSystem` never
read it.

What a lying client gains is nothing: name a baseline you do not hold and you are sent a delta you
cannot assemble, which you then cannot acknowledge, so the server falls back to a full snapshot.
**It can waste its own bandwidth and nobody else's.**

### 2.3 `NET-C2S-INPUT` is hand-packed, and yaw/pitch are wider than the table says

**12 bytes**: `seq:u16`, `move:2×i8`, `yaw:u16`, `pitch:i16`, `buttons:u16`, `acked_tick:u16`.
`InputCodec` owns the layout.

Until US-0095 it went out as **six loose RPC arguments**, which Godot variant-encodes at **56
bytes** — the M2 gate measured upstream at 253 % of budget because of it.

**The table above says `yaw:u8` and `pitch:i8`. The codec uses `u16`/`i16`, and it costs the same
on the wire.** A `PackedByteArray` argument costs 8 bytes of Variant wrapper plus the payload
rounded up to four, so 10 and 12 bytes both cost 20. The narrower fields save nothing, and they
cost two measured things:

- `pitch:i8` would **stair-step the camera** — `camera_rig.gd` reads `look_pitch` directly, and
  180° in 256 steps is 0.7° a step.
- `yaw:u8` would make a **slow mouse drag stick**: the sampler accumulates look, and a frame
  moving less than 0.7° would round back where it started.

**The client quantises at SAMPLE time.** It predicts with the command it holds and the server
simulates with the command it received; one rounding step between them is a divergence on every
frame, absorbed silently by the reconciler.

---

## 3. Server → Client

| ID | Ch | Rel | Rate | Payload |
|---|---|---|---|---|
| `NET-S2C-WELCOME` | X | Rel | once | `peer_id:u8`, `tuning_hash:u64`, `map_id:u8`, `phase:u8` |
| `NET-S2C-TUNING-SYNC` | X | Rel | on mismatch | Full `TuningProfile` (~6 KB). Client adopts — **corrected, never kicked** |
| `NET-S2C-LOBBY-STATE` | X | Rel | on change | `players[]{peer_id, persona, ready}`. **Loadouts deliberately excluded** |
| `NET-S2C-MATCH-START` | X | Rel | once | `match_seed:u64`, `start_tick:u32`, `crowd_count:u8` |
| `NET-S2C-SNAPSHOT` | S | Unrel | **30 Hz** | §4 |
| `NET-S2C-CONTRACT-ASSIGNED` | E | Rel | on change | `contract_peer:u8`, `reason:u8`. **No persona, position or identity hint** |
| `NET-S2C-KILL-RESULT` | E | Rel | on event | `killer:u8`, `victim:u8`, `tick:u32`, `bonus_group:u16`. **Sent only to killer and victim** |
| `NET-S2C-STUN-RESULT` | E | Rel | on event | `stunner:u8`, `target:u8`, `tick:u32`, `valid:bool`, `lockout_ticks:u16` |
| `NET-S2C-ABILITY-STARTED` | E | Rel | on event | `peer:u8`, `ability:u8`, `origin:3×f32`, `dir:3×f32`, `tick:u32`. **Broadcast to all clients in tell radius — the legibility law on the wire** |
| `NET-S2C-ABILITY-DENIED` | E | Rel | on event | `slot:u8`, `reason:u8`. Requester only |
| `NET-S2C-PREY-WARNING` | E | Rel | on event | **`tick:u32` only** — see §5 |
| `NET-S2C-SCORE-EVENT` | E | Rel | on event | `event_id:u32`, `tick:u32`, `kind:u8`, `actor:u8`, `subject:u8`, `base:i16`, `mult:u8`, `group:u16` |
| `NET-S2C-PHASE-CHANGED` | E | Rel | on change | `phase:u8`, `tick:u32`, `multiplier:u8` |
| `NET-S2C-MATCH-END` | E | Rel | once | Full `ScoreEvent` log (~24 KB) for the results fold |
| `NET-S2C-PLAYER-JOINED` | X | Rel | on change | `peer_id:u8`, `persona:u8` |
| `NET-S2C-PLAYER-LEFT` | X | Rel | on change | `peer_id:u8`, `persona:u8` |
| `NET-S2C-PONG` | S | Unrel | 1 Hz | `client_time:u32`, `server_tick:u32` |

---

## 4. Snapshot payload

> **`present_slots` IS NOT REDUNDANT, AND IT IS THE ONE FIELD DELTA ENCODING MADE NECESSARY.**
> Before US-0031, absent from a snapshot meant *gone*. It now means *unchanged* — so without a
> separate statement of who exists, a player who disconnects while standing still is omitted for
> being unchanged and **is never freed**. They stand in the district for the rest of the match.
>
> It is written even on a full snapshot, where the records imply it. One byte buys a single decode
> path, and a format whose shape depends on a flag is a format that gets read wrong on the branch
> nobody tested.

```
NET-S2C-SNAPSHOT — per client, per tick
├── header
│   ├── server_tick        u32
│   ├── last_acked_seq     u16      this client's last processed InputCommand
│   ├── flags              u8
│   └── baseline_age       u8       ticks back to the delta baseline; 0 = FULL
├── own_pawn                        FULL — the prediction authority
│   ├── position           3×f32
│   ├── velocity           3×f32
│   ├── state_id           u8
│   ├── state_timer_ticks  u16
│   └── grounded           bool
├── own_gameplay                    NEVER predicted
│   ├── suspicion          u8       0..100
│   ├── tier               u2
│   ├── active_sources     u8       SPRINT ROOF CLIMB OPEN RUN — drives the HUD source list
│   ├── cooldown_a_tick    u16
│   ├── cooldown_b_tick    u16
│   ├── blend_state        u4
│   ├── kill_ready         bool     drives the crosshair — must not lie
│   └── stun_ready         bool
├── compass
│   ├── bearing            u8       wobble ALREADY APPLIED server-side
│   ├── distance_bucket    u8       0.5 m buckets to 60 m — never an exact distance
│   ├── lock_fraction      u8
│   └── portrait_revealed  bool
├── match
│   ├── phase              u8
│   ├── ticks_remaining    u16
│   └── multiplier         u8
├── present_slots          u8       WHO EXISTS this tick, one bit per slot
├── remote_pawns[]                  only those whose QUANTISED state changed
│   ├── peer_id            u8
│   ├── position           3×i16    1 cm, map-local
│   ├── yaw                u8       1 deg
│   ├── state_id           u8
│   ├── anim_phase         u6
│   └── render_state       u2       PLAIN | TINTED | HARD — COMPUTED PER OBSERVER
└── npcs[]                          delta; culling and rate-LOD are M3's
    ├── index              u8
    ├── position_xz        2×i16    1 cm, map-local
    ├── height             u8       5 cm  — see below
    ├── yaw                u8       1 deg
    └── anim_state         u3 + phase u5      == 8 bytes per NPC including index
```

**THE CROWD RECORD IS COARSER THAN THE PLAYER RECORD, AND THAT IS WHERE THE BUDGET LIVES.**
Ninety NPCs against six players: a byte saved on an NPC is worth fifteen saved on a remote pawn.

`x` and `z` keep their centimetre, because the crowd's horizontal position is read by the
suspicion radius and by the compass. **`y` is a byte at 5 cm** because nothing reads a crowd
member's height at all — the suspicion radius is horizontal, the compass is a bearing, and the
strata are 3.5 m apart. The animation is `u3` state and `u5` phase in one byte: eight states is
more than the crowd declares, and 32 phase steps is finer than a walk cycle can be read at the
45–70 m these records are sent from.

This record was **10 bytes** as first specified, and §7.1 budgeted it at 7 — the index and a
`3×i16` position alone are seven. US-0029 built the format, measured it, and projected the
district's worst case at **108.3 kbit/s against a 96 budget**. At 8 bytes it projects to
**93.0 kbit/s**. `test_snapshot_size.gd` measures it on every run.

---

## 5. What the protocol deliberately does not carry

**The design's information rules are enforced at the payload level, not in the UI.** A rule that
lives only in a widget can be broken by a different widget; a rule that lives in the wire format
cannot be broken at all.

| Not sent | Would break | Enforced by |
|---|---|---|
| Contract's **persona** | The crowd's entire value — collapses ~78 candidates to ~12 | `NET-S2C-CONTRACT-ASSIGNED` carries `peer_id` only |
| Contract's **exact position** | Deletes the search | `bearing` + `distance_bucket` only |
| Contract's **elevation** | The Compass is 2D by design | No z component anywhere in `compass` |
| Contract's **suspicion or tier** | You see the consequence, never the value | Not in the payload |
| **Prey-warning direction** | The panicked scan of a crowd is the best moment in the game | `NET-S2C-PREY-WARNING` carries **only a tick — there is no field to leak** |
| Other players' **suspicion values** | Anonymity | `render_state` is 2 bits, per observer |
| Other players' **cooldowns or loadouts** | Kit-reading is a skill | Not in the payload |
| A **global kill feed** | Would reveal how the contract cycle shifted, for free | `NET-S2C-KILL-RESULT` goes to killer and victim only |
| NPCs beyond 70 m | — | Culled server-side |

> **If the client never receives it, no future UI change, mod, or bug can reveal it.**

---

## 6. Bandwidth

| Direction | Budget | Measured (worst case) | Status |
|---|---|---|---|
| Down | `TUN-NET-BANDWIDTH-BUDGET-DOWN` 96 kbit/s | ~83.5 kbit/s | **87 % — fits, 13 % headroom** |
| Up | `TUN-NET-BANDWIDTH-BUDGET-UP` 16 kbit/s | ~18 kbit/s | **⚠ MISSES BUDGET** |

**The upstream miss is packet overhead, not payload** — 28 bytes of UDP/ENet header carrying 9
bytes of input, 60 times a second. The fix is coalescing two input commands per packet, halving
the packet rate while preserving the 60 Hz sample rate, at a cost of up to 16 ms added latency
for the first command in each pair (against an 80 ms feel budget).

`test_upstream_bandwidth.gd` is written to **fail until this is resolved**, deliberately.

### 6.1 The four downstream mechanisms

| # | Mechanism | Saving |
|---|---|---|
| 1 | Distance culling at 70 m (> Compass range, so a culled NPC cannot affect anything perceivable) | 0–50 % |
| 2 | Quantisation — position 1 cm, yaw 1°, anim 4+6 bits = **7 B/NPC** | ~60 % vs floats |
| 3 | Delta encoding — only NPCs whose quantised state changed | ~40 % |
| 4 | Rate LOD — NPCs beyond 45 m at 10 Hz | ~20 % |

---

## 7. Lag compensation

| Aspect | Value |
|---|---|
| Applies to | **Kill and stun validation only.** A third call site requires an ADR amendment |
| Rewind | `clamp(rtt/2 + 100 ms, 100 ms, 200 ms)` |
| History | 500 ms ring at 30 Hz = 15 entries; ~23 KB |
| Optimisation | Only entities within ~7.5 m of the action are rewound — typically < 10, not 96 |

| Rewound | Not rewound |
|---|---|
| Player positions and yaw | Suspicion tier (current) |
| **NPC positions** — they determine LOS occlusion and blend membership | Contract assignment (current) |
| Cinderfall volumes | Cooldowns (current) |
| Blend membership (derived from rewound NPCs) | |

**The ceiling is the important half.** It caps how far into the past a high-ping player may
reach, putting the cost of a bad connection on the player who has one.

---

## 8. Adding a message

1. Confirm it does not let a client assert an outcome (§2.1).
2. Assign a `NET-(C2S|S2C)-*` ID; add it to `GLOSSARY.md` Appendix A and `scripts/core/ids.gd`.
3. Add a row here **and** in [`../20_tdd/04_networking.md`](../20_tdd/04_networking.md) §6 —
   `test_protocol_docs_sync.gd` asserts they match.
4. C2S: write the authority check **first**, before the handler.
5. Choose the channel by the §1.1 table.
6. Add a payload-schema test.

---

## 9. Acceptance criteria

- [ ] Every C2S message has a non-empty authority check, and the handler calls `_authorise` first.
- [ ] No C2S message contains an outcome field.
- [ ] `NET-S2C-PREY-WARNING` has exactly one field.
- [ ] No payload contains the contract's persona, exact position, elevation or tier.
- [ ] `render_state` is computed per observer.
- [ ] `KillSystem` / `StunSystem` never read `client_tick`.
- [ ] This document and TDD-04 §6 agree (`test_protocol_docs_sync.gd`).
- [ ] Downstream within budget; upstream miss tracked and failing loudly.
