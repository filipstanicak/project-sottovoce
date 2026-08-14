---
id: US-0029
title: Snapshot format and serialisation
version: 1.0.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-14
depends_on: [TDD-04-NET, BIBLE-NET-PROTOCOL]
---

# US-0029 — Snapshot format and serialisation

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-SNAPSHOT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0028 |

## Description

The binary snapshot layout and its serialise/deserialise pair, plus quantisation helpers.

## Peer ids never reach the wire

Godot hands out a **random 32-bit id** per peer — a real one from a two-process run was
**1 526 710 570** — and the catalogue declares `peer_id:u8` in seven places: the remote-pawn
record, `NET-S2C-WELCOME`, `-PLAYER-JOINED`, `-CONTRACT-ASSIGNED`, `-KILL-RESULT`,
`-STUN-RESULT` and `-SCORE-EVENT`.

**The catalogue is right and the engine is the anomaly.** A match holds at most
`TUN-LOBBY-MAX-PLAYERS` 6 players, so a player fits in three bits; the byte is what the bandwidth
budget was written against, and sending the raw id instead costs three extra bytes on every
record that names a player. `SlotTable` maps one to the other, and slot **0 is reserved to mean
nobody** — so a record that was never filled in decodes as absent rather than as player one,
which is the difference between a bug that shows and a bug that names the wrong killer.

A second benefit worth having: a slot number carries no information about the transport, and one
match's slot 2 tells an observer nothing about the next match's.

## The own-pawn block is not quantised, and everything else is

The own block is the authority the client reconciles its prediction against. Rounding it to a
centimetre would spend 1 cm of `TUN-NET-RECONCILE-THRESHOLD`'s 10 cm budget on nothing at all. It
is sent once per snapshot rather than five times, so 24 bytes of float is affordable where 5 × 24
would not be.

## Acceptance criteria

- [x] Layout matches NETWORK_PROTOCOL §4 — every field, in order. **The record SIZES §7.1 quotes
      are unreachable from those fields; see below.**
- [x] Position quantised to 1 cm as 3×`i16` map-local; yaw to 1 degree as `u8`. Clamped rather
      than wrapped: a pawn past the edge should pin there, because that is debuggable and the
      opposite corner is not.
- [ ] **Remote pawn record is 14 bytes; NPC record is 7 bytes including index.** Measured at
      **10 and 10**. Not achievable from §4's own field list — see below. Left unticked rather
      than reworded.
- [x] Round-trip serialise then deserialise is lossless within quantisation. A **truncated**
      buffer decodes to `null` rather than to a half-filled object: a partial decode moves remote
      pawns to plausible wrong places, which is worse than a frame with no update.
- [x] The snapshot contains NO persona, exact position, elevation or tier for the contract.
      Asserted **structurally** — the fields do not exist on the object, so no builder can
      populate them and no widget can read them.
- [x] `render_state` is a 2-bit per-observer field, carried in the remote-pawn record rather than
      anywhere global: the same player at the same suspicion is `PLAIN` to four observers and
      `HARD` to one.

## The record sizes in §7.1 are not reachable from the fields in §4

**This is the story's finding, and it is a design question rather than a defect.**

§4 declares, per NPC: an index `u8`, a position `3×i16`, a yaw `u8`, and an animation `u4 + u6`.
The index and the position **alone** are seven bytes; §7.1 budgets the whole record at seven. The
remote-pawn record is quoted at 14 and its declared fields come to ten. The own block is budgeted
with compass and match at 18 bytes; `own_pawn` alone is 28 by §4's own list.

Measured from `Snapshot.serialise()`:

| Record | §7.1 quotes | Measured |
|---|---|---|
| NPC | 7 B | **10 B** |
| Remote pawn | 14 B | **10 B** |
| Fixed part (header + own + compass + match + counts) | 25 B | **53 B** |

Re-running §7.1's worst case on the measured sizes gives **13 535 B/s ≈ 108.3 kbit/s** against
`TUN-NET-BANDWIDTH-BUDGET-DOWN` 96 — **113 % of budget**, where the document concluded 87 %.

**Nothing here is fixable by editing the serialiser.** The encoding is as tight as the declared
fields allow. The options are the document's own: ADR-0007's fallback (replicate near NPCs,
seed-derive far ones), a smaller payload, or a re-derived budget. TDD-04 §14 open question 1
already asks whether 13 % headroom is enough; the answer is that there is none.

`test_snapshot_size.gd` reports the measurement and marks the projection **pending** rather than
failing — a red suite over a number nobody can fix by editing that file would train people to
ignore it. `test_the_declared_record_sizes_are_not_the_documented_ones` fails the day somebody
reconciles the two, which is exactly when this section should be read again.

## Test notes

| Test | Asserts |
|---|---|
| `test_snapshot.gd` | Every field round-trips; the own block is **not** quantised; the packed gameplay byte survives; a truncated buffer decodes to nothing; a retired state decodes as `NO_STATE`; and the forbidden fields do not exist |
| `test_quantise.gd` | Position and yaw survive within their own step; the district fits the encoding; a position past the edge clamps and a yaw wraps; an oversized field cannot spill into its neighbour |
| `test_slot_table.gd` | Peer ids the shape Godot really produces; slot 0 means nobody; the lowest free slot is reused; more than the lobby holds is refused |
| `test_snapshot_size.gd` | The measured record sizes, and the projected worst case — **pending, over budget** |

`test_payload_omissions.gd` from TDD-04 §12 is folded into `test_snapshot.gd`: the omissions are
properties of the format, and asserting them beside the round trip keeps both in one file.

## Notes

The information rules are enforced in the wire format, not the UI. A rule that lives in a widget
can be broken by a different widget; a rule that lives in the protocol cannot be broken at all.
