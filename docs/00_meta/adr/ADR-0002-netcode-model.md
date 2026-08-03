---
id: ADR-0002
title: Server-authoritative netcode model
version: 1.0.0
status: accepted
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0001, TUN-INDEX]
supersedes: none
---

# ADR-0002 — Server-authoritative netcode model

## Context

The game is decided at 2.5 m (`TUN-KILL-RANGE`) and 3.0 m (`TUN-STUN-RANGE`), in a crowd,
with a 1.4 s committed animation and a 0.4 s contest window. Three facts follow:

1. **Small positional errors change outcomes.** A 30 cm discrepancy is the difference
   between a kill landing and a stun landing first. Netcode error is not cosmetic here.
2. **The most valuable thing a cheater could do is trivial to attempt.** Claiming "I killed
   player 3" is one message. Claiming "my suspicion is 0" is another. Both must be
   impossible by construction, because [`../SCOPE_FENCE.md`](../SCOPE_FENCE.md) OUT #9
   defers all anti-cheat beyond server authority.
3. **Suspicion and detection are gameplay, not presentation.** Whether you are visible to
   your pursuer must be decided in one place. If clients decide their own visibility, the
   game has no rules.

Against this: the local pawn must feel immediate. `TUN-FEEL-INPUT-TO-ANIM-MAX` is 80 ms,
which is less than a single round trip on most connections. Some form of prediction is
mandatory.

The design tension is therefore the standard one — authority versus responsiveness — but
with an unusual weighting: this game can tolerate *remote* players being 100 ms in the past
far better than most action games, because the remote players are usually walking at
1.4 m/s and pretending to be NPCs. The interpolation cost is small precisely because the
game is about slowness.

## Options considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Server-authoritative, client prediction for the local pawn only, snapshot interpolation for remotes, lag compensation for kill/stun** | Cheating is structurally hard; the local pawn feels immediate; remote motion is smooth; the well-understood model. | Prediction/reconciliation is genuinely difficult to get right; lag compensation introduces "killed behind cover" moments. | **Chosen** |
| Full deterministic lockstep | Tiny bandwidth; perfect consistency. | Input latency equals the worst peer's RTT — fatal for an 80 ms feel budget. Determinism across float platforms is a research project. Any desync is unrecoverable. | Rejected |
| Client-authoritative movement with server validation | Simplest to build; perfect local feel. | A client that lies about position can teleport-kill. Validation heuristics are an arms race we explicitly deferred. | Rejected |
| Peer-to-peer with a host player | No server hosting cost. | The host has a latency advantage in a game decided by 0.4 s windows, and host migration mid-match would corrupt the contract cycle. | Rejected |
| Server-authoritative with **no** client prediction | Much simpler; perfectly consistent. | Local pawn latency = RTT. At 60 ms RTT this misses the feel budget; at 120 ms it is unplayable. | Rejected — but see Consequences |

## Decision

**Server-authoritative simulation at 30 Hz (`TUN-NET-SERVER-TICK`), with:**

1. **Client input at 60 Hz** (`TUN-NET-CLIENT-INPUT-RATE`), sent as sequenced input
   commands. Two commands per server tick, so a 16 ms input is never lost to tick aliasing.
2. **Client-side prediction for the local pawn only.** The client runs the same movement
   code as the server against its own input, and reconciles when the server's authoritative
   state for that tick arrives. Reconciliation replays the unacknowledged input buffer.
   Errors below `TUN-NET-RECONCILE-THRESHOLD` (10 cm) are smoothed silently over
   `TUN-NET-RECONCILE-SMOOTH-TIME`; larger errors trigger a replay.
3. **Snapshot interpolation for all remote entities**, including NPCs, at a fixed
   `TUN-NET-INTERP-BUFFER` of 100 ms. No extrapolation.
4. **Server-side lag compensation for kill and stun validation only** — see ADR-0010.
5. **No client prediction of any gameplay state.** Suspicion, detection, tier, cooldowns,
   contracts and score are computed on the server and replicated. The client renders a
   *mirror*, never a simulation, of these.

Point 5 is the one that matters most and is the easiest to erode. A client-side suspicion
estimate "just for the HUD" would drift, and a HUD that disagrees with the server about
your own tier is worse than no HUD.

## Consequences

### Positive
- Kill, stun, suspicion, contract and score are unforgeable without server compromise. This
  is what allows [`../SCOPE_FENCE.md`](../SCOPE_FENCE.md) OUT #9 to defer everything else.
- The server's simulation is the only simulation, so it is the only thing that needs testing
  for correctness. The headless test harness in
  [`../../30_bible/TEST_PLAN.md`](../../30_bible/TEST_PLAN.md) §4 exercises the real thing.
- Remote players interpolated 100 ms in the past is nearly free in feel terms here, because
  remote players are usually moving at 1.4 m/s: 100 ms is 14 cm of positional lag.
- Prediction is confined to one system (the pawn's movement), so the hard part of netcode
  lives in one file and is unit-testable in isolation.

### Negative — stated honestly
- **"I was killed behind cover" will happen.** Lag compensation means the server sometimes
  rewinds the world to a state where you were visible. This is an unavoidable consequence
  of favouring the shooter's view, and it is mitigated (ADR-0010) but not eliminated. The
  200 ms clamp bounds how bad it can get.
- **Prediction and reconciliation is the highest-bug-density code in the project.** Budget
  for it: `RISK-NETCODE` is the highest-probability risk in the register.
- The movement code must be *shared* between client and server and must be free of
  frame-rate dependence and non-deterministic input (no `randf()`, no `Time.get_ticks_msec()`
  in the step function). Enforced by review and by a determinism test.
- Suspicion arriving from the server means the HUD's tier indicator is up to
  `RTT/2 + tick` behind reality. At 30 Hz and 60 ms RTT that is ~50 ms. Acceptable; measured
  and asserted in the test plan.
- Bandwidth is dominated by NPC transforms (ADR-0007), not players. The budget is worked in
  [`../../20_tdd/04_networking.md`](../../20_tdd/04_networking.md) §7 and is tight.

### Neutral / follow-on
- `TUN-NET-INTERP-BUFFER` is fixed rather than adaptive in MVP (ASM-0021), deliberately, so
  that balance testing is not confounded by netcode that changes between sessions.
- A "no-prediction" debug mode is required, not optional: it is the only way to tell a feel
  bug from a prediction bug. Specified in
  [`../../20_tdd/12_build_and_ci.md`](../../20_tdd/12_build_and_ci.md) §5.

## Compliance

- [ ] No RPC exists that lets a client assert a gameplay outcome. The catalogue in
      [`../../30_bible/NETWORK_PROTOCOL.md`](../../30_bible/NETWORK_PROTOCOL.md) has an
      `Authority check` column, and no client→server message may have it empty.
- [ ] `SuspicionSystem`, `DetectionSystem`, `ContractSystem`, `ScoreSystem` and
      `AbilitySystem` are instantiated only when `multiplayer.is_server()`.
- [ ] The client's copies of those systems' outputs are read-only view models.
- [ ] Movement step code contains no call to `randf`, `Time.*`, or `delta` from `_process`.
- [ ] `test_prediction_reconciliation.gd` passes: given a synthetic 150 ms RTT and a
      divergent server correction, the client converges within
      `TUN-NET-RECONCILE-SMOOTH-TIME` with no visible snap.

## Revisit trigger

Reopen if measured per-client bandwidth exceeds `TUN-NET-BANDWIDTH-BUDGET-DOWN` (96 kbit/s)
after the ADR-0007 mitigations, or if reconciliation cannot be made stable for the
traversal state machine — in which case the fallback is to make traversal manoeuvres
server-confirmed-before-visible rather than predicted, accepting a latency cost on vault
and mantle only.
