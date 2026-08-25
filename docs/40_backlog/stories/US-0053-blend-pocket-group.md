---
id: US-0053
title: Blend actions — pocket and walking group
version: 0.2.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-25
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-07-SUSPICION]
---

# US-0053 — Blend actions: pocket and walking group

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-SUSPICION` |
| **Systems** | `SYS-BLEND` |
| **Estimate** | M |
| **Depends on** | US-0052 |

## Description

The two crowd-dependent blend actions: standing in a pocket of at least four NPCs, and occupying
a walking-group formation slot.

## Acceptance criteria

- [x] Pocket requires at least 4 NPCs within 3.5 m, RE-VALIDATED EVERY TICK.
- [x] Group requires an assigned slot and staying within 0.8 m of it.
- [x] Entry takes 0.35 s; exit 0.30 s.
- [x] Suspicion crushes to zero over 1.2 s.
- [x] Exceeding stroll speed, taking damage, or being stunned breaks the blend.
      **The speed break is live; damage and stun have no caller** — `SYS-KILL` is US-0060 and
      `SYS-STUN` is US-0061. `report_damage()` and the `Stunned` check are built and tested.
- [x] A pocket dropping below four NPCs breaks the blend THAT TICK.
- [x] Blend grace of 1.0 s after exit arms the Blended bonus.
      Nothing reads it yet: `SCORE-BLENDED` is `SYS-SCORE`'s.
- [ ] The player adopts the persona-appropriate clone idle — a parity-set clip.
      **There are no animation clips in this project, on either rig.** The same blocker as M3's
      exit. `PawnStateId.BLENDED` is also still unreachable — see the notes, because the reason
      is not the missing clip.

## Test notes

`test_blend_revalidated.gd` is the critical one. `test_blend_grace.gd` asserts 0.9 s after exit
qualifies and 1.1 s does not. `test_blend_not_cover.gd` asserts a blended pawn is killable.

## Notes

A blend is not a state you enter and keep — it is a condition re-validated every tick. A blend
that silently keeps working after its conditions lapse is the "I thought I was hidden" bug class.

Blend protects anonymity, never the body.

---

## What was found building it

**`PawnContext.peer_id` HAS HAD NO WRITER SINCE M1, AND THE FIRST THING TO READ IT WOULD HAVE
BEEN CONFIDENTLY WRONG.** `PawnHost._build_record` never set it, and nothing had ever read it —
so nothing was broken. `SYS-BLEND` asking `CrowdFormations` which slot a player holds would have
asked about peer **zero**, and `group_of_peer(0)` matches the first group whose `player_peer` is
`NO_PEER`: a player who never joined a group would have read as **standing in the first unclaimed
slot**. An empty answer would have been survivable; this is a plausible wrong one. `PawnHost`
fills it now, `test_pawn_host.gd` asserts it, and `BlendSystem` takes the peer as an argument
anyway — a field that has been a lie once is not one to start trusting.

**`BlendSystem` IS NOT A `GameSystem`, AND THE DOCUMENTS DECIDED IT RATHER THAN CONVENIENCE.**
`MatchDirector` permits one system per stage. TDD-07 §1's diagram draws blend resolution as
**step 1 inside the `SYS-SUSPICION` box**, and TDD-01 §4.1's rationale for *crowd before
suspicion* already reads "…and **blend-pocket validity depends on NPC positions**" — so the blend
belongs to stage 4. It is a pure `RefCounted` that `SuspicionSystem` owns, which is the shape
`ContractCycle`/`ContractSystem` and `SnapshotDelta`/`SnapshotBuilder` already use, and it keeps
the decision askable in a test with no director present. **A new `blend` stage was considered and
rejected**: it would have meant amending a normative diagram six documents reference to express
an ordering both of them already express.

**THE CRUSH BRANCH HAD NEVER EXECUTED.** `SuspicionMath.integrate()` has had a linear crush since
US-0051 and `blending` was permanently false, so the one path that *reduces* suspicion outside
decay was dead code with a passing unit test. `test_suspicion_system.gd` now drives 100 → 0
through the real system.

**AND ITS FIRST ASSERTION WAS OFF BY ONE TICK, NOT WRONG ABOUT THE RULE.** Measured 97.22 where
it expected 100.0 — and 2.78 is exactly `TUN-SUSPICION-MAX` over `TUN-BLEND-CRUSH-TIME` at one
net tick. `blend.resolve()` is step 1 of the pass, so on the tick the entry window closes the
record is already `HELD` when the integrator reads it, and the crush legitimately runs that tick.
The harness was measuring the boundary from the wrong side.

**THE GRACE ARMS ON A BREAK AS WELL AS ON A DELIBERATE EXIT**, which no document decided. The
alternative hands a hunter a way to deny +200 by sprinting past a pocket and scattering it —
paying the reckless approach the whole design exists to charge for. An interrupted **entry** arms
nothing, or the bonus would be reachable by tapping the key near a crowd.

**`PawnStateId.BLENDED` IS STILL UNREACHABLE, AND THE MISSING CLIP IS NOT WHY.** Nothing has ever
transitioned into it. It cannot simply be entered by the server: the pawn state machine is
**predicted**, and a transition that depends on server-only knowledge — how many NPCs are within
3.5 m — is one the client cannot reproduce, so it would diverge every tick of every blend. The
two available answers are (a) predict the *press* optimistically on both peers and let the server
break it, the way a vault is predicted and validated, or (b) never predict it and drive the pose
from `blend_state` in the mirrored block. That is a real decision with prediction consequences
and it is not in this story's criteria; the blend works without it, and the camera's
`fov_blend` is the visible thing it would buy.

**AND THERE IS A SECOND, WRONG SUSPICION LADDER IN `scripts/pawn/`.** `PawnState.suspicion_rate()`
and twelve overrides implement the whole thing again — roof toll, decay, climb, vault, and
`BlendedState`'s crush — and **nothing in the shipped game calls any of it**. It is not merely a
duplicate, it is a duplicate that disagrees: `scripts/pawn/` contains no `gain_open`, no
`decay_delay`, no `stillness_mult` and no speed ceiling, so a player standing alone in an empty
plaza costs **−8/s** there and **+6/s** in `SuspicionMath` — opposite signs on the mechanic that
makes an empty plaza dangerous — and tap-sprinting is free. Four unit-test files assert it in
detail, which is exactly what makes it look maintained. **Reported, not removed**: it is thirteen
call sites across eleven files plus two test files, and it deserves its own change and its own
argument rather than riding along with a feature.

