---
id: US-0093
title: A hop when nothing resolves, scaled by the speed state
version: 1.0.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-13
depends_on: [GDD-02-PLAYER]
---

# US-0093 — The speed-scaled hop

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-TRAVERSAL` |
| **Systems** | `SYS-TRAVERSAL`, `SYS-PAWN` |
| **Estimate** | S |
| **Depends on** | US-0017–0020, US-0090 |

## Description

Asked for by the owner, when told that Space in the open does nothing today:

> Depens on the move state, if its normal stroll, then just a tiny hop. If i am runnign or
> sprinting, it should be a bigger jump but not horizontaly more verticaly.

## What it changes

GDD-02 §7.2 case 7 — the no-match case — reads:

> | 7 | No match | **Nothing** — input consumed, no animation | Silence, not a flail. A failed
> traverse must never look like a bug. |

**That row becomes a hop.** It is a smaller reversal than US-0094's, but it is one: "silence, not
a flail" was a deliberate answer to a specific failure mode, and the argument behind it survives —
a *failed* traverse must still never look like a bug. What changes is that pressing Space in open
ground is no longer a failed traverse. It is a jump, and it does what the player expected.

The forgiveness windows are untouched: cases 1–6 still win, so a hop never steals a vault.

## Proposed shape

**An impulse, not a state.** `ctx.velocity.y` is set and the existing airborne handling takes
over — gravity in `LocalPawnDriver._apply_motion`, and §7.2 **case 1** (airborne with a ledge
inside `TUN-TRAVERSE-MAGNET-RADIUS`) already turns a hop that ends near a ledge into a grab, for
free.

That is worth stating as the reason: a `Jump` state would mean a fifteenth `PawnStateId`, new
edges in the normative §3 diagram, and a second place that owns Space. An impulse means the
resolver stays the only owner of `INPUT-TRAVERSE`, and the pawn stays in whatever locomotion state
it was already in — which is also what keeps the suspicion rate correct without a new rule.

| PROPOSED | Value | Why |
|---|---|---|
| `TUN-TRAVERSE-HOP-STANDING` | ~2.6 m/s ⇒ ~0.34 m | Idle, blend-walk, stroll. The "tiny hop". |
| `TUN-TRAVERSE-HOP-COMMITTED` | ~4.2 m/s ⇒ ~0.90 m | Run and sprint. Bigger, **and vertical** — no horizontal boost is added, so the arc's length comes only from the speed the player already had. |

Neither has a row in TUNABLES.md. Minting the IDs is part of building this.

**Two values, not a curve**, because the ladder is four discrete rungs and a smooth
speed→height function would reintroduce the slider the ladder exists to replace.

## The question the owner has not answered

**Does jumping cost anonymity?**

It was raised when the hop was chosen and not ruled on, so it is recorded here rather than
invented. Design law 1 prices *speed*, and a hop is not speed — but a person jumping on the spot
in a market is not behaving like a civilian, and the crowd is the game's substrate.

| Option | Consequence |
|---|---|
| **No extra cost** — the hop inherits whatever the current state charges | Simplest, and consistent with the impulse shape. A blend-walking player can hop repeatedly for free while suspicion decays, which is either harmless or a silly-looking exploit depending on how the crowd reads it (M3). |
| **A one-off suspicion cost per hop** | Prices the conspicuousness directly. Needs a new tunable and a rule for a *repeated* hop, which is a spam problem, not a balance number. |
| **Defer to M3** | The question is really "does the crowd react to a jump", and there is no crowd until M3. |

**Recommendation: no extra cost now, revisit at M3** when NPC startle exists and the answer can
be observed rather than argued. Recorded so it is a decision rather than an omission.

## Why this is not built yet

**It changes what Space does when nothing resolves, and that is exactly what the M1 feel gate
counts.** US-0024's checklist line 2 is *ten deliberately sloppy vaults all resolve*, tallied by
the debug readout as `#` resolved and `.` produced nothing. Once Space always produces *something*,
"nothing happened" stops being observable and the tally stops meaning what the checklist says it
means.

So: **run the gate first**, then build this. If the gate is judged against a controller that is
mid-change, the judgement is worth less than the time it took.

## Traps

1. **Trap 4 — assert the shape.** "The pawn's `y` increased" is true of a pawn walking up a ramp.
   Assert against the state it hopped from and the absence of added horizontal speed.
2. The hop must **not** fire while already airborne, or it is a double jump nobody asked for and
   the roofs open up.
3. `ctx.grounded` is written by the driver *after* `step()`. Read it, do not infer it.

## Acceptance criteria

None are ticked. Nothing is built.

- [ ] Space with no traversal match produces a vertical impulse; cases 1–6 still win.
- [ ] The impulse is `TUN-TRAVERSE-HOP-STANDING` from idle/blend-walk/stroll and
      `TUN-TRAVERSE-HOP-COMMITTED` from run/sprint.
- [ ] **No horizontal velocity is added** — the arc's length is whatever the player already had.
- [ ] A hop that ends near a ledge still resolves into a ledge grab (§7.2 case 1).
- [ ] No hop while airborne.
- [ ] GDD-02 §7.2 case 7 is rewritten, and §7's "silence, not a flail" argument is kept for the
      case it still governs — a traverse that genuinely fails.
- [ ] The suspicion decision above is recorded in TUNABLES, whichever way it goes.
