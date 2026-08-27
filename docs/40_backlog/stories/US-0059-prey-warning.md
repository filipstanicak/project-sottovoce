---
id: US-0059
title: The prey warning
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-26
depends_on: [GDD-03-SOCIAL-STEALTH, TDD-07-SUSPICION, BIBLE-AUDIO]
---

# US-0059 — The prey warning

| | |
|---|---|
| **Milestone** | M4 |
| **Epic** | `EPIC-DETECTION` |
| **Systems** | `SYS-DETECTION` |
| **Estimate** | S |
| **Depends on** | US-0058 |

## Description

The prey's warning: a marker showing **where** their pursuer is, once that pursuer has been
careless enough to reveal themselves.

**RE-AUTHORED 2026-08-26 (ADR-0013).** This story used to specify a *directionless* warning —
a tick and nothing else, enforced at three layers. The reference marks a revealed pursuer on
the compass with **bearing and distance**, so this does too. The tier gate is unchanged and is
now the load-bearing half: it is the reference's rule as well as ours, and it is what still
leaves a competent hunter invisible.

## Acceptance criteria

- [x] Fires when the pursuer is within `TUN-COMPASS-WARN-RADIUS` 15 m AND at least Noticed.
- [x] An ANONYMOUS pursuer fires NO warning at any range, and draws no marker. Swept over five
      ranges from 0.5 m to 14.9 m, because one sample cannot tell a tier gate from a range gate
      that happens to be tighter than the sample. *The "draws no marker" half is vacuous today
      — nothing draws anything — and is ticked on the message not being sent.*
- [x] Re-trigger cooldown `TUN-COMPASS-WARN-COOLDOWN` 2.5 s prevents strobing at the tier
      boundary. **And a new pursuer defeats it**, which no criterion asked for — see below.
- [x] `NET-S2C-PREY-WARNING` carries a **world bearing and a distance bucket**, and no third
      field. `TUN-COMPASS-WARN-GIVES-DIRECTION` is `true`.
- [x] **The payload names nobody.** No persona, no wire slot, no colour — nothing from which a
      client could identify *which* of the people on that bearing is the player. Asserted
      structurally, not by a widget: the Compass lock (ASM-0030) is the only thing in the game
      that earns an identity.
- [ ] The bearing is a **world** angle, rotated into view space by the client each rendered
      frame — the same decision `SYS-COMPASS` made in US-0057, and for the same reason: a
      camera-relative bearing computed server-side lags the mouse by the round trip.
      **The server half is done and asserted; nothing rotates anything, because there is no
      widget.** `CompassVm` and the HUD are US-0084, M5 — the same blocker as US-0057's
      seventh criterion.
- [x] The distance is a `Quantise.BUCKET_STEP` bucket, so nothing downstream holds exact
      metres.
- [ ] The audio sting is mono and centred, with no 3D emitter. **Blocked: there is no call
      site.** `Audio.play()` is an empty stub until US-0075 and `EventBus` may hold no `func`,
      so the bridge that would play it belongs to the first presentation node that wants the
      signal. Asserting the rule now would be a guard over zero call sites — vacuously green,
      which is trap 3 and is worse than leaving the box empty.
- [x] The warn tier threshold equals the stun tier threshold, asserted as an invariant
      (§17.8). "I was warned about them" and "I can stun them" stay the same condition.

## As built, 2026-08-26 — seven of nine

**IT COSTS NOTHING, BECAUSE IT RIDES A PASS THAT WAS ALREADY LOOKING.**
`DetectionSystem._resolve_pair` already computes `hunted_by` for the render state, and that is
exactly the relationship the warning is about. The evaluation is a distance, a tier comparison
and a cooldown lookup on pairs the early-out ladder has already admitted — no second pass, no
raycast, `raycasts_last_tick` unmoved.

**THE COOLDOWN RE-ARMS WHEN THE PURSUER CHANGES, AND NO CRITERION ASKED FOR IT.** It is
`CompassLock`'s own US-0058 lesson in a second place: keyed on the prey alone, a repair handing
them a new pursuer would leave the new one **silenced for up to `TUN-COMPASS-WARN-COOLDOWN`**
— 2.5 s of the prey's only warning, suppressed by a relationship that no longer exists. The
re-arm is then bounded so alternating pursuers cannot produce a warning every tick.

**THE BEARING IS WOBBLED, ON THE SAME RULE THE HUNTER'S OWN READING USES.** GDD-03 §9.1 puts
this marker on the same Compass ring, and one ring must have one rule — a prey whose warning
arrow was exact while their hunting arrow drifted would learn the instrument means two
different things depending on which way it points. Keyed on the **pursuer**, so the lie told
about one hunter is uncorrelated with the lie told about the next. It conceals nobody: at 15 m
the drift is about a metre of lateral error.

**AND `Tuning.ticks()` TAKES THE `TUN-` ID, NOT THE SECONDS.** Trap 7, and it cost a full
arch run to find because the symptom was *"`DetectionSystem` has no ray query to inspect"* in a
test that does not mention the Compass. The parse error is thrown by the autoload's signature
and the failure surfaces as every dependent script failing to compile. **Capturing the whole
run to a file before grepping it is what named it** — the corpus already carried that note from
an unattributed integration failure, and this is the first time it has paid.

**THE TIER GATE IN `_consider_warning` IS UNREACHABLE-AS-DIFFERENT AND IS KEPT ANYWAY.**
Invariant §17.8 pins the warn floor equal to `TUN-SUSPICION-TIER-NOTICED`, so no profile
`Tuning.adopt()` accepts can separate it from `_resolve_pair`'s Anonymous early-out.
**A planted `>= ANONYMOUS` leaves every test in the file green** — measured, not assumed. It is
not deleted because the rung above is an early-out *for cost*, and resting the warning's
correctness on a performance optimisation means widening the ladder later would warn prey about
Anonymous pursuers with nothing failing. The test says what it cannot see.

**A THREE-PLAYER RING HAS NO STRANGERS, AND THIS TEST DID NOT KNOW THAT EITHER.** The first
version placed a "nearby stranger" beside the prey and read one warning where it expected none
— in a cycle of three everybody is somebody's hunter and somebody's prey. The ring is four
players now, and warnings are counted **per recipient** rather than in total, because four
players carry three other live relationships. Same finding as `test_detection_system.gd`'s at
US-0055, second instance.

## Test notes

| File | Asserts |
|---|---|
| `test/unit/systems/detection/test_warning_tier_gate.gd` | The gates, the recipient, the bearing bound, the bucket, and that a nearby *stranger* warns nobody. **Opens with a vacuous-success guard**, because every "no warning" assertion in it is satisfied by a system that never warns anybody |
| `test/unit/core/compass/test_warning_cooldown.gd` | Five seconds of a held chase produce the tuned number of stings rather than 150; a new pursuer defeats the cooldown and is then bounded by it; a refused warning arms nothing; a departed peer leaves nothing behind; the conversion is `ticks` and not `step_ticks`, asserted against the two disagreeing |
| `test/arch/test_warning_names_nobody.gd` | The RPC signature, the field **count**, this document's sibling catalogue row in `NETWORK_PROTOCOL.md`, and `rpc_id` versus `rpc` |
| `test/arch/test_prey_warning_signal_arity.gd` | Re-authored under ADR-0013 and already green: refuses an *identifying* parameter rather than any parameter, and asserts the tunable and the shipped profile agree |

**Falsified against three planted defects.** `within := true` reddened the range assertion;
`_is_new_pursuer` returning false reddened two cooldown assertions; a `slot: int` parameter on
the RPC reddened two arch assertions. **The fourth plant — the tier gate — changed nothing**,
and that is recorded above rather than smoothed over.

~~`test_warning_payload_empty.gd`~~ is superseded: the payload is no longer empty, and what
needed asserting was that neither field *names* anybody. ~~`test_prey_sting_nonpositional.gd`~~
is not written, because there is no call site to guard.
~~`test_warning_thresholds_match.gd`~~ is not written under that name; its property is
`test_prey_warning_signal_arity.gd`'s tier-gate test.

## Notes

**The warning says where, never who.** That is the whole of what survives of the old
three-layer rule, and it matters more than the direction did: a persona on this message would
collapse the crowd from seventy-eight candidates to one, permanently, for free, and there
would be nothing left for a Compass lock to earn.

**The tier gate is the reference's rule, not a divergence from it.** Its threat meter depletes
only when the pursuer goes high-profile *in the prey's line of sight*, and the marker appears
only once it has. A competent hunter still produces nothing at all. Direction is what
carelessness costs.

**One divergence remains and is deliberate:** our suspicion accrues globally, so a hunter who
sprints where the prey cannot see them still reveals themselves. Line-of-sight-gated accrual is
an architectural change (per-observer suspicion rather than one scalar) and is priced
separately.
