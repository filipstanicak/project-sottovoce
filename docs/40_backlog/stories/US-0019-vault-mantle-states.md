---
id: US-0019
title: Vault and mantle states
version: 1.0.0
status: done
owner: Technical Director
last_updated: 2026-08-05
depends_on: [TDD-06-PAWN, BIBLE-ANIMATION-SPEC]
---

# US-0019 — Vault and mantle states

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-TRAVERSAL` |
| **Systems** | `SYS-TRAVERSAL` |
| **Estimate** | S |
| **Depends on** | US-0018 |

## Description

StateVault, branching internally on height between vault and mantle. Root motion is used here,
which is one of only two places it is permitted.

## Acceptance criteria

- [x] Vault: 0.55 s, obstacles up to 1.1 m, zero suspicion cost.
- [x] Mantle: 0.95 s, obstacles 1.1 to 2.3 m, climb-rate suspicion for its duration.
- [ ] Both use root motion for exact hand and foot placement.
- [x] Both are interruptible by COMBAT-priority transitions.
- [x] Durations match their tunables exactly.

**Root motion is unmet and cannot be met yet: there are no animation clips.** `ANIM-VAULT` and
`ANIM-MANTLE` are rows in ANIMATION_SPEC §3.2 and nothing under `assets/` but a `.gdkeep`. What
US-0019 delivers is the thing root motion would drive: a displacement computed from the geometry
and interpolated over the tuned duration. See "Which layer owns position" below — the answer
turned out to matter more than the animation does.

## Test notes

`test_anim_durations_match_tunables.gd` covers the durations.
`test_root_motion_policy.gd` asserts root motion appears only on traversal clips.

**Neither exists.** Both scan animation clips, and there are none; a guard over an empty set
reports success and teaches everyone to trust it. The durations are asserted directly against
their tunables in `test_vault_state.gd` instead, which is the half that can be true today.

## Notes

Vault costing zero suspicion is deliberate — it is the only free athletic move and the backbone
of ground-level route-finding. Chained vaults are geometry-limited; watch telemetry in case
vault-chaining becomes a dominant travel mode.

---

## Which layer owns position

ANIMATION_SPEC §4 permits root motion for traversal, reasoning that "the displacement is
identical on every peer because the geometry is". That is true of the *geometry* and not
automatically of the *clip*: an animation advanced by frame time, on a client that is
interpolating, is not the same source of truth as one advanced by tick count on a headless
server.

So the simulation owns position and the animation is matched to it. `TraversalResolver.plan()`
commits a start, a target and an arc peak **once, at the instant of the press**, from that
tick's probe reading; `VaultState` interpolates them by tick. Root motion, when clips arrive,
aligns hands and feet within that displacement rather than deciding it.

Planning once is the load-bearing part. The probes refresh every physics frame, so a state that
recomputed its target mid-manoeuvre would chase the wall it is currently crossing — and would
chase it a frame differently on the server than in the client's replay.

## What this story found

### 1. An uninterruptible state could never end

`step()` requested its own exit at the state's own priority, and `transition()` compared
`priority <= interrupt_priority` before admitting it. A state that declines NORMAL interrupts
therefore declined **its own completion** and held the pawn forever.

`Vault` is built that way by design — GDD-02 §3.1 says "Yes (to COMBAT+)", so you cannot change
your mind about a wall halfway over it. **`KillAnim` has been built that way since US-0013**, for
the stronger reason that a landed kill must not be un-killed, and nothing had ever noticed
because nothing had ever run it.

The symptom is not an error. It is a player frozen mid-vault, or a killer who never gets control
back, in a game whose only escape is dying.

Interruption is something done *to* a state by something else. A state ending is not that.

### 2. The driver overwrote the vault's position every frame

`LocalPawnDriver` ran `move_and_slide()` and read back where the physics engine put the body.
With the vault's velocity frozen — which it must be, or the approach speed lands the pawn
somewhere the plan did not choose — that is nowhere. The vault computed a perfect arc and the
pawn did not move.

Invisible to every unit test, because the unit tests call `step()` directly. `PawnState.
drives_position()` now names the distinction, and US-0020's `Climb` and `Drop` will need it too.

### 3. Any obstacle thinner than the probe step had no measurable top

The obstacle-top cast sat one `TUN-TRAVERSE-GAP-PROBE-STEP` (0.4 m) past the face, so on a
0.4 m-thick wall it landed exactly on the far edge and measured the floor behind it —
`obstacle_top = INF`, no vault. A fence, a railing, a market-stall edge: the metrics bible
constrains vaultable geometry's *height* and says nothing about its thickness.

Now three samples at 0.25×, 0.5× and 1× the step, taking the **highest** surface found. The
lowest would be the floor.

## What this story does not do

- **No animation.** No clips exist. `test_root_motion_policy.gd` and
  `test_anim_durations_match_tunables.gd` are owed and recorded here.
- **No climb, no drop.** US-0020. A traverse at a façade or an edge still resolves correctly
  and then push_errors, because those states are declared and unimplemented — deliberately
  noisy, since the alternative is silence and silence looks like the resolver being wrong.
- **No landing check.** The vault trusts the plan's target. A player who vaults into a space an
  NPC has since walked into will overlap them for a frame; that is `SYS-CROWD`'s problem and
  M3's.
