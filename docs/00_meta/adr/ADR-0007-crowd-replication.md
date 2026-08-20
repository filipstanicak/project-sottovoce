---
id: ADR-0007
title: Crowd replication strategy
version: 1.0.0
status: accepted
owner: Technical Director
last_updated: 2026-08-03
depends_on: [ADR-0002, ADR-0003, TUN-INDEX]
supersedes: none
---

# ADR-0007 — Crowd replication strategy

## Context

60–90 NPCs must appear in the same places on every client. The obvious question is whether
to *send* their positions or to *derive* them.

The tempting answer is derivation: give every client the same seed, run the same
deterministic simulation, send nothing. At 90 NPCs × 30 Hz this saves the majority of the
bandwidth budget.

The reason it is wrong here is specific to this game: **the crowd is not scenery, it is
gameplay state.**

An NPC's exact position determines:

| Determination | Tunable | Consequence of a 1 m divergence |
|---|---|---|
| Whether a player is inside a blend pocket | `TUN-BLEND-POCKET-MIN-NPC`, `TUN-BLEND-POCKET-RADIUS` | A player believes they are blended and is not. |
| Whether the open-ground suspicion source applies | `TUN-SUSPICION-OPEN-RADIUS` | A player accrues suspicion they cannot account for. |
| Whether a walking-group slot is joinable | `TUN-BLEND-GROUP-JOIN-RADIUS` | An input silently fails. |
| Whether line of sight is broken for a Compass lock | `TUN-COMPASS-LOCK-REQUIRES-LOS` | A lock completes on one machine and not another. |
| Whether a player collides with an NPC | `TUN-SUSPICION-GAIN-NPC-BUMP` | A 15-point suspicion impulse appears from nothing. |

Any client/server divergence in NPC position is therefore a *gameplay* divergence, and the
symptom is the worst possible kind: the game appearing to break its own rules, unreproducibly.

Determinism in GDScript across Windows and Linux, with float math, navmesh queries, and
avoidance steering, is not achievable without enormous effort — and any single divergence
compounds silently over an 8-minute match.

## Options considered

| Option | Bandwidth | Divergence risk | Verdict |
|---|---|---|---|
| **Server-simulated, transforms replicated with quantisation, culling and LOD** | High but budgetable | None by construction | **Chosen** |
| Client-deterministic from a shared seed | ~Zero | Unbounded; silent; compounds | Rejected |
| Hybrid: server-replicates NPCs near players, clients simulate distant ones | Medium | Divergence at the handover boundary, which is where players are | Rejected |
| Server-replicates only NPCs that are *gameplay-relevant* (near a player), clients render decorative distant crowds from a seed | Medium | None for gameplay; distant crowd may differ cosmetically between clients | **Rejected for MVP, retained as the fallback** |

The fourth option is genuinely reasonable and is the designated fallback if the bandwidth
budget fails. It is not chosen now because "gameplay-relevant" has a fuzzy boundary
(`TUN-COMPASS-RANGE-MAX` is 60 m and a player can *see* further than that), and getting the
boundary wrong reintroduces exactly the bug class this ADR exists to prevent. Bandwidth is
the cheaper problem to solve first.

## Decision

**The server owns all NPC state. Clients receive quantised transforms and animation state
per NPC in the snapshot stream. NPCs are not independently simulated on clients.**

Appearance is the exception: **which persona each clone wears is derived on the client from
`match_seed` + NPC index** (ASM-0025), because appearance never changes and replicating it
per-tick would be pure waste. The server sends the seed once at match start.

Bandwidth is managed by four mechanisms, in order of impact:

1. **Distance culling.** NPCs beyond `TUN-NET-NPC-CULL-RADIUS` (70 m) from a client are not
   sent to that client at all. On a 120 × 120 m map with the client near the centre this
   culls little; near a corner it culls roughly half. 70 m is deliberately larger than
   `TUN-COMPASS-RANGE-MAX` (60 m) so a culled NPC can never affect anything the client can
   perceive.
2. **Quantisation.** Position to `TUN-NET-QUANT-POS` (1 cm) as 16-bit fixed-point per axis
   relative to a map-local origin; yaw to `TUN-NET-QUANT-YAW` (1°) as 8 bits; animation state
   as a 4-bit enum plus a 6-bit normalised phase. **6 bytes per NPC per snapshot**, plus a
   1-byte index.
3. **Delta encoding.** Only NPCs whose quantised state changed since the client's last
   acknowledged snapshot are sent. A standing idle NPC costs nothing. In practice 40–60 % of
   the crowd is idle or occluded at any moment.
4. **Rate LOD.** NPCs beyond `TUN-PERF-CROWD-LOD-MID` (45 m) are sent at 10 Hz rather than
   30 Hz, and interpolated over the longer interval. At walking speed the interpolation error
   is under 15 cm — far below any gameplay threshold, and those NPCs are beyond every
   gameplay radius in the table above.

### Worked budget (6 players, 90 NPCs, worst case)

| Component | Calculation | Bytes/s |
|---|---|---|
| Near NPCs (≤ 45 m, assume 45 visible, 30 Hz, 55 % changed) | 45 × 0.55 × 7 B × 30 | 5 197 |
| Far NPCs (45–70 m, assume 30 visible, 10 Hz, 70 % changed) | 30 × 0.70 × 7 B × 10 | 1 470 |
| Remote players (5, 30 Hz, full state 14 B) | 5 × 14 × 30 | 2 100 |
| Local pawn authoritative correction (30 Hz, 18 B) | 18 × 30 | 540 |
| Gameplay state (suspicion tier, compass, cooldowns; event-driven, est.) | — | 400 |
| Score events (~600/match ≈ 1.25/s × 40 B) | — | 50 |
| ENet + UDP/IP overhead (~28 B/packet, 30 packets/s) | 28 × 30 | 840 |
| **Total** | | **10 597 B/s ≈ 85 kbit/s** |

Against `TUN-NET-BANDWIDTH-BUDGET-DOWN` = 96 kbit/s: **fits, with 11 % headroom.** That
headroom is thin, which is why the fallback option is documented rather than discarded.

## Consequences

### Positive
- Blend membership, open-ground suspicion, line of sight and collisions are computed against
  one authoritative crowd. The entire class of "I thought I was hidden" bugs is impossible.
- The server can be tested headlessly with no client, and its crowd is *the* crowd.
- Adding a gameplay dependency on NPC position later is free — it already works.
- Lag compensation (ADR-0010) can rewind NPCs too, so a Cinderfall cloud or a blend pocket
  is validated against the world as the acting player saw it.

### Negative — stated honestly
- **This is the largest single consumer of bandwidth in the project**, at roughly 63 % of the
  downstream budget. The headroom is 11 %. If `TUN-CROWD-COUNT-MAX` rises, or if the map
  opens up so culling stops helping, this fails.
- Server CPU carries the whole crowd simulation, inside `TUN-PERF-SERVER-TICK-BUDGET`.
- Delta encoding requires per-client acknowledged-snapshot bookkeeping — more state on the
  server, and a known source of subtle bugs when a client's ack is lost.
- Quantisation to 1 cm means an NPC's replicated position differs from the server's by up to
  5 mm. All gameplay radii have margins far larger than this, but it is a real, if tiny,
  divergence — the claim is "no *consequential* divergence", not "bit-identical".

### Neutral / follow-on
- The fallback (replicate near, seed-derive far) is designed but not built. If the budget
  fails at M3, that is the move, and the boundary must be set at ≥ 70 m so it stays outside
  every gameplay radius.

  > **THE BUDGET DID FAIL AT M3, AND THE FALLBACK IS NOT THE MOVE.** Downstream measured
  > **112 %** with culling, rate LOD and the NPC delta all built (TDD-04 §7.1.2). The boundary
  > this note mandates — ≥ 70 m — is exactly where `TUN-NET-NPC-CULL-RADIUS` already sits, so
  > every NPC the fallback would stop replicating is one the builder already refuses to send.
  > **Measured at zero records past 70 m, over all six spawn points**
  > (`test_cull_radius_price.gd`). The saving is nil.
  >
  > **It is still worth building, for the opposite reason to the one written here.** A client
  > currently draws *empty street* past 70 m; the fallback would put a crowd back on the horizon.
  > That is a rendering change and a `RISK-ANONYMITY-LEAK` question — a district that visibly
  > ends at a radius tells a player exactly how far they can be seen from — not a bandwidth one.
  >
  > **And the boundary does not close it either.** Swept through the real builder with the
  > rate-LOD radius held fixed and every row starting from an identical crowd, the curve is flat:
  > 113 % at 70 m and **110 % at invariant 17's floor of 60 m**. Culling that much harder removes
  > 22 % of the reachable crowd and about 3 % of the bytes, because everything it removes is
  > already sent at a third of the rate. So neither this fallback nor the radius is the lever, and
  > what remains needs a smaller record, a lower crowd update rate, or a bigger budget.
- 10 Hz far-NPC updates require the interpolation buffer to stretch for those entities. The
  implementation must interpolate on *received timestamps*, not on a fixed assumed interval,
  or the two rates will fight.

## Compliance

- [ ] `NpcBrain` and `CrowdDirector` are instantiated only when `multiplayer.is_server()`.
- [ ] The client's `NpcView` has no `step()`, no navigation agent and no state machine.
- [ ] `TUN-NET-NPC-CULL-RADIUS >= TUN-COMPASS-RANGE-MAX` is asserted by
      `test_tuning_ranges.gd` (invariant §17.17).
- [ ] `test_crowd_bandwidth.gd` runs a synthetic worst case (90 NPCs, 6 clients, all moving)
      and asserts measured bytes/s per client is within `TUN-NET-BANDWIDTH-BUDGET-DOWN`.
- [ ] `test_clone_roster_parity.gd` derives the clone roster from a fixed seed on three peers
      and asserts identical hashes.
- [ ] Blend, suspicion and LOS queries read from the server's NPC collection, never from a
      client-side view.

## Revisit trigger

Reopen immediately if `test_crowd_bandwidth.gd` fails, or if the measured 95th-percentile
per-client rate exceeds 90 kbit/s in a real 6-player playtest. The first move is the
documented fallback, not raising the budget.
