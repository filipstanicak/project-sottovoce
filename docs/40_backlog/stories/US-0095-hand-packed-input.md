---
id: US-0095
title: Hand-serialise NET-C2S-INPUT
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-15
depends_on: [TDD-04-NET, BIBLE-NET-PROTOCOL, US-0038]
---

# US-0095 — Hand-serialise `NET-C2S-INPUT`

| | |
|---|---|
| **Milestone** | M2 follow-up (found at the gate) |
| **Epic** | `EPIC-SNAPSHOT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | S |
| **Depends on** | US-0038 |

## Description

The M2 gate measured upstream at **253 % of `TUN-NET-BUDGET-UP`** and found the cause: nothing
hand-serialised `NET-C2S-INPUT`. It went out as **six loose RPC arguments**, and Godot encodes
those as Variants — an `int` is 8 bytes, a `Vector2` 12, a `float` 8 or 12. **Fifty-six bytes** for
what TDD-04 §6.1 budgets at nine.

`Snapshot` packs its own bytes, which is why the downstream figures could be measured at all.
Input never did.

## Acceptance criteria

- [x] **`NET-C2S-INPUT` is packed into a single `PackedByteArray` argument.** `InputCodec`, pure —
      12 bytes in, an `InputCommand` out, with no peer and no world.
- [x] **The client predicts with exactly the values the server receives.** `InputSampler`
      quantises at **sample** time through `InputCodec.quantise_*`, so `serialise` → `deserialise`
      is exactly lossless from there. Asserted with `assert_eq`, not a tolerance — a tolerance here
      would be a tolerance on client/server divergence.
- [x] **A malformed buffer is refused, not partially decoded.** `StreamPeerBuffer` returns zero on
      an over-read rather than failing, so a short buffer would decode as a command holding no
      buttons and no movement — which the server would then simulate.
- [x] **Measured, not projected.** 253 % → **145 %**.
- [x] **The integration harness carries the real bytes.** Input has a wire format now, so a
      harness passing the object would prove nothing about what travels — the same reason its
      downstream half already serialised.

## The gate's own projection was too optimistic, and that is the more useful finding

US-0038 recorded *"hand-packed only → 18.4 kbit/s, 115 %"*. **The real figure is 145 %.**

That projection counted the 10-byte payload as reaching the wire raw. It does not: a
`PackedByteArray` RPC argument costs **8 bytes of Variant wrapper plus the payload rounded up to
four**. Measured:

| Raw payload | On the wire |
|---|---|
| 8 B | 16 B |
| **9–12 B** | **20 B** |
| 16 B | 24 B |

**A projection is not a measurement**, and the gate's table was a projection made one layer above
the thing it described — which is precisely the mistake §7.3 made one layer below. Corrected in
US-0038, TDD-04 §7.3 and `RISK-BANDWIDTH` rather than left standing.

## Why the layout is not §6.1's

§6.1 declares `yaw:u8` and `pitch:i8`. The codec uses **`u16` and `i16`**, and **it costs the same
on the wire** — 10 and 12 raw bytes both round to 20. The narrower fields save nothing, and each
costs something that was measured rather than argued:

- **`pitch:i8` would stair-step the camera.** `camera_rig.gd` reads `command.look_pitch`
  *directly* to place the arm. 180° in 256 steps is 0.7° a step, visible on any slow drag.
- **`yaw:u8` would make a slow drag stick entirely.** The sampler accumulates look; at 1.4° a
  step, a frame moving less than 0.7° rounds back to where it started and the camera does not turn
  at all.

At `u16` the worst error is **0.00275°** — finer than a mouse can express.

## Quantise at sample time, never at send time

The whole correctness story. The client predicts with the command it holds; the server simulates
with the command it received. **If those differ by one rounding step the two diverge on every
frame** — and the reconciler would absorb it silently, so the suite would stay green while every
player on every connection drifted.

`InputSampler` therefore writes already-quantised values into the command. Two details:

- **The look accumulator has to stay separate.** Rounding look *in place* would mean any frame
  whose motion is smaller than half a step rounds back where it started — the sticking failure
  above, caused by the fix rather than the field width. `_look_yaw` and `_look_pitch` hold full
  precision; the command holds what the wire holds.
- **`move` is safe to round in place**, because it is read fresh from the device each frame rather
  than accumulated, so rounding cannot compound or stick.

## What is left, and why coalescing is now the right move

**Packet overhead is 84 % of the budget on its own** — ENet's 28-byte header at 60 packets a
second is 13.4 kbit/s. Even a zero-length command would leave under five bytes per packet of room.
So the payload was the right thing to fix first and cannot be the last.

| | Payload | Total | Of budget |
|---|---|---|---|
| Before (six loose Variants) | 56 B | 40.5 kbit/s | 253 % |
| **Now (packed)** | **20 B** | **23.2 kbit/s** | **145 %** |
| Packed **and** coalesced | 32 B / 30 Hz | 14.6 kbit/s | **91 %** |

**Coalescing is now correct, and it was not before.** Against a 56-byte payload it left the miss
at 211 % while spending up to 16 ms of input latency against an 80 ms feel budget — a bad trade.
Against a packed command the payload doubles per packet but the packet rate halves, so the
dominant term halves and the total lands under budget. §7.3 proposed it from the start and was
right about the mechanism and wrong about which term dominated.

Not built here: it costs input latency, and that is a feel decision to take with the measurement
in hand rather than a bandwidth decision to take alone.

## Test notes

| Test | Asserts |
|---|---|
| `test_input_codec.gd` | A sampled command survives the wire **exactly**; quantisation is idempotent; the worst yaw error is under 0.02°; the payload is 12 B and costs the same as 10 on the wire; a short, empty or over-long buffer is **refused**; every button bit survives; `seq` **wraps** rather than clamping; the ±π and ±90° extremes round-trip |
| `test_upstream_bandwidth.gd` | The input path still hand-serialises; the payload fell by two thirds; the measured upstream now; **packet overhead alone is 84 % of budget**; coalescing would now close it |

**`run_gut.sh` caught its fifth silent skip during this story.** A parameter named `bytes` collided
with an existing local in `IntegrationHarness`, the file failed to parse, and four integration
scripts were skipped — the suite reported **153 passing tests and no failures**. Without the
script-count check that is indistinguishable from a healthy run.
