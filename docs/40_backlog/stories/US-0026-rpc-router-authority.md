---
id: US-0026
title: RpcRouter and authority checks
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-14
depends_on: [ADR-0002, TDD-04-NET, BIBLE-NET-PROTOCOL]
---

# US-0026 — RpcRouter and authority checks

| | |
|---|---|
| **Milestone** | M2 |
| **Epic** | `EPIC-TRANSPORT` |
| **Systems** | `SYS-NET-REPLICATION` |
| **Estimate** | M |
| **Depends on** | US-0025 |

## Description

The single validation chokepoint for every inbound client message. No client message reaches a
system without passing through it.

## The shape it was built in

**The router decides nothing about the game.** It answers one question — *may this peer be saying
this, now* — and hands what survives to whoever is listening. Whether an ability is off cooldown,
whether a kill lands, whether a target is in range: those are systems' questions, they need world
state, and they are asked later.

That boundary is what makes the authority rule checkable **by reading**. The router is small
enough that a source scan can prove every door calls the chokepoint first, which is a stronger
guarantee than any runtime test could give — a runtime test would have to *be* the adversary.

| Piece | Kind | Holds |
|---|---|---|
| `Authority` | pure | §6.1's authority column as a table: `msg -> [needs_player, when, needs_pawn]` |
| `SequenceGate` | pure | One `u16` per peer, and the wrap arithmetic |
| `RpcRouter` | Node | The `@rpc` doors, the roster, and the signals systems listen to |

### Signals, not calls

The router does not know `SYS-COMBAT` exists. US-0028 connects the server pawn simulation to
`input_received`; nothing in the router changes when it does. A router that called systems
directly would be edited every time one was added, and **every edit is a chance to add a handler
that forgets to authorise**.

### The roster is the router's own

The first version asked `Net.has_player()` on every message. It is worse, for a reason worth
recording: **a router whose answers come from a global cannot be asked a question in a test.**
Every assertion collapsed to "the peer is not a player", which stays true whatever the phase and
pawn tracking are doing — three tests passed that way and proved nothing, including one that
would have passed with pawn tracking deleted entirely. The router now keeps its own roster, fed
by `Net.peer_joined` / `peer_left`. State the router owns is state a test can set.

## Decisions taken here

### Warmup is not playing

`NET-C2S-INPUT` is legal in `ACTIVE` and `FINAL` only. A pawn exists during warmup, so
`has_pawn` is true and **only the phase stands between an input and the simulation** — which is
the whole reason phase is checked rather than inferred from the pawn.

### Input arrives as arguments, not as a `PackedByteArray`

TDD-04 §10 sketches `c2s_input(payload: PackedByteArray)`, and that is right — but packing it
means choosing the quantisation (`TUN-NET-QUANT-POS`, `TUN-NET-QUANT-YAW`) and the `u16`/`i8`
widths of §6.3, which is **US-0029's** decision. A placeholder format invented here is a format
US-0029 would have to delete, and would be on the wire meanwhile. §10 is a sketch of interfaces;
§6.3 is the wire, and it stays unwritten until its own story.

### A dropped sequence is not logged

UDP reorders. A late packet is the transport working as designed, and logging each one would bury
the refusals that mean something under sixty lines a second.

## The wrap is the whole sequence gate

`seq` is a `u16` sent 60 times a second, so it **wraps about every 18 minutes — inside a single
match**. A gate written as `seq > last` passes every ordinary case, passes every test anyone
would think to write, and then rejects *every input for the next eighteen minutes*, because 0 is
not greater than 65535. The pawn stops responding, the server logs nothing, and no line of the
code looks wrong.

`is_newer()` compares the signed distance in modular arithmetic instead: anything within half the
range ahead is newer. Symmetric, wrap-free, no special case at the boundary — and `HALF - 1` and
`HALF + 1` are both asserted, because the window's edge is the only place the two formulations
disagree.

## Acceptance criteria

- [x] Every C2S handler calls `_authorise` FIRST, with no path around it. — proven by source
      scan, in two parts: that the call exists, and that **nothing but the sender lookup precedes
      it**. A handler that validates after acting has already acted.
- [x] Every C2S message in NETWORK_PROTOCOL §2 has a non-empty authority check. — `Authority.RULE`
      is compared against `Messages.CHANNEL_FOR` **in both directions**: a message with no rule,
      and a rule for no message. `NET-C2S-HELLO` is the one exclusion and it is not an oversight —
      it establishes whether a peer is a player at all, so requiring authority for it is circular.
- [x] Input applies to the SENDER's pawn, looked up from the peer id — never from the payload.
      Nothing in the payload names a pawn; the question cannot be asked in this protocol.
- [x] Stale or replayed sequence numbers are dropped.
- [x] Lobby-only messages are rejected outside the LOBBY phase.
- [x] Rejections log with peer id and reason, and are announced as `message_denied` so a test can
      assert **why** rather than only that nothing happened.

## Two guards TDD-04 promised in M0 and nobody had written

Both are named in §12 and neither existed. This is the pattern the corpus warns about — *check
that X is a file, and that something runs it* — so both were written here, and both were
falsified against a planted violation before being trusted:

| Guard | Planted violation | Caught |
|---|---|---|
| `test_no_client_authority.gd` | an `@rpc("any_peer")` handler with no `_authorise` | yes |
| `test_no_client_authority.gd` | a handler that emits *before* authorising | yes |
| `test_client_cannot_assert_outcome.gd` | `damage:u8` added to a C2S row in the catalogue | yes |

**The first version of the authority scan found zero handlers and passed.** `SourceScanner.
code_lines()` strips string literals so a guard is never tripped by its own documentation — and
the thing being matched *is* a string literal, the `"any_peer"` inside the annotation. A guard
that scans the wrong way is vacuously green forever. It reads raw lines now, and
`test_handlers_exist_to_be_checked` refuses a scan that finds almost nothing.

## Test notes

| Test | Asserts |
|---|---|
| `test_authority.gd` | Every message has a rule and every rule a message; unknown is refused rather than allowed; forbidden is refused even from a fully authorised player; warmup is not playing; the most fundamental disagreement is reported first |
| `test_sequence_gate.gd` | Replay, reorder and gap; **the wrap, both directions**; the window's edge; peers do not share a sequence; a recycled peer id inherits nothing |
| `test_rpc_router.gd` | The chokepoint admits, refuses, names the reason, uses the phase it was told, and forgets a peer completely |
| `test_no_client_authority.gd` | Every client-facing door authorises, and authorises first |
| `test_client_cannot_assert_outcome.gd` | No C2S row carries an outcome; no forbidden message has acquired a row |

## Notes

There is no `NET-C2S-KILL` and no `NET-C2S-STUN`. Kill and stun are BUTTONS in the input
bitfield. A client cannot express "I killed someone" in this protocol — that is what lets the
scope fence defer all anti-cheat beyond server authority.
