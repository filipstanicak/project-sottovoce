---
id: US-0073
title: HUD — tier, portrait, crosshair, abilities, timer
version: 0.2.0
status: in-progress
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [BIBLE-UI-UX, TDD-11-UI]
---

# US-0073 — HUD: tier, portrait, crosshair, abilities, timer

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-HUD` |
| **Systems** | `SYS-HUD` |
| **Estimate** | M |
| **Depends on** | US-0072 |

## Description

The remaining widgets, each a pure renderer fed by a view model.

## Acceptance criteria

- [x] Tier indicator encodes SHAPE and COLOUR and WORD simultaneously.
      Open circle, half-disc, filled triangle — **drawn rather than typed**, so the
      shape channel does not depend on a font having `○◐▲`. Asserted by the three
      tiers **disagreeing** on word and colour, because a widget returning the same
      value twice has silently collapsed to one channel.
- [x] Tier indicator lists ACTIVE SUSPICION SOURCES whenever any contributes.
      From `SuspicionSources.of()`'s own bitfield, in a **fixed order** rather than
      bitfield order — a line that reshuffled itself as sources came and went would
      be unreadable exactly when it matters. Every bit in `SuspicionSources.ALL` is
      asserted to produce a word, because a bit with no string is a reason the
      player is never told and the line would simply be one item shorter.
- [x] The numeric suspicion value appears NOWHERE in the shipping HUD.
      `EventBus.suspicion_value_changed` carries it and **no widget subscribes**.
      The signal exists for the debug overlay, which every release preset strips.
- [x] Exposed adds a screen-edge vignette — the only full-screen effect in the game.
      A separate node from the tier indicator **on purpose**: they carry the same
      fact and are not the same kind of thing, and folding them together would make
      *"does this take the whole screen"* a property of a branch rather than of a
      node. Fades over `TUN-UI-DAMAGE-VIGNETTE-TIME`, read rather than written.
- [ ] Contract portrait shows UNKNOWN until a lock completes, then the persona permanently.
      **Half done, and the other half is not a stub — it is ASM-0030.** UNKNOWN,
      the reveal on lock, and the reset on reassignment are built. **Which persona
      is not on the wire and must not be**: a client learns its contract's
      appearance by *looking*, and the lock exists to make that looking cost
      something. The honest source is the mesh the client is already drawing
      (US-0046's `PersonaBody`), which needs the lock to name a slot. Adding the
      persona to a payload instead is the leak `NETWORK_PROTOCOL` §9 forbids.
- [x] Crosshair ring appears IF AND ONLY IF pressing kill would succeed, from a SERVER flag.
      `kill_ready`, computed by `SYS-KILL` against the same contract, range, cone,
      lockout, concealment and — since ADR-0015 — line-of-sight rules the press is
      judged by. **The widget cannot lie because it cannot compute**: it is guarded
      against naming a distance, a range, a position or `KillRules`.
- [x] A distinct crosshair treatment for a valid stun target.
      Four corner brackets against a ring — **a shape, not a colour** (§6), so the
      two verbs stay distinguishable on the monochrome palette.
- [ ] Ability slots show radial cooldown sweeps, LINEAR so remaining time is readable by angle.
      **Blocked: there are no abilities.** `SYS-ABILITY` is US-0066 and
      `cooldown_a_tick` / `cooldown_b_tick` are on the wire with no writer.
- [x] The passive is NOT shown in the HUD.
      Nothing renders one and there is no passive field in any view model.
- [ ] Timer shows the final-phase bar and a persistent 2x marker.
      **Blocked: there is no match.** `SYS-MATCH` is US-0079 at M6, so `phase`,
      `ticks_remaining` and `multiplier` are on the wire and never move.
- [x] Nothing occupies the centre 60 percent of the screen except the 3 px crosshair.
      Tier top-left, portrait top-right, Compass centre-bottom, vignette a frame.
      The crosshair is a 3 px dot anchored dead centre.

## Test notes

`test_crosshair_truth.gd` asserts agreement with server kill validity across 500 randomised
poses. `test_tier_monochrome.gd`.

## Notes

The active-source list answers "why am I visible?" before the player asks. A player who cannot
attribute their suspicion cannot learn from it.

A lying crosshair is worse than no crosshair. If prediction and server validation disagree, fix
the agreement or make the ring server-confirmed.

---

## Eight of eleven, and the three findings this story turned up

**`Palette` DID NOT EXIST AND NEITHER DID ITS GUARD.** UI_UX_SPEC §7 has said since M0 that *"all
colour comes from a `Palette` resource injected into every widget"* and named
`test_no_colour_literals.gd` as the enforcement. **Both were fiction** — trap 14 in a bible
section — and it is why `CompassWidget` shipped four colour literals in US-0072. Both exist now,
the Compass is retrofitted, and the guard caught this story's own vignette on its first run.

**Only the `DEFAULT` palette is authored, deliberately.** §7.1 needs four and the monochrome one
is the *verification* palette for the other three; those are `US-0083`'s at M6. **The seam is what
is expensive to add late**, and the seam is what this built.

**AND AN ARCH GUARD FORBADE THE HUD FROM NAMING A TIER.**
`test_suspicion_is_never_predicted.gd` banned any `SuspicionMath.` or `SuspicionSources.` in
client code — and the tier indicator has to name `Tier.EXPOSED` to compare against a tier the
server sent, and `SuspicionSources.SPRINT` to decode a bitfield the server sent. **Neither is
arithmetic; both are vocabulary**, and that distinction is the guard's own: its note on
`FORBIDDEN_WRITES` already reads *"a client may read what the snapshot gave it"*.

**The narrowing is the case of the first character after the dot.** Functions here are
`snake_case` and constants are not, and `gdlint` holds that on every file in CI — so
`SuspicionMath.evaluate_tier(` is still caught and `SuspicionMath.Tier.EXPOSED` is not, without
the list having to enumerate function names it would then fall behind on. **It has its own
counterfactual**, because a narrowing that reduced to *"nothing is ever forbidden"* would leave
every assertion in that file passing.

## And then somebody looked at it (2026-08-27)

`tools/hud_probe.tscn` boots the real client and captures the HUD in eight scripted states.
**Four defects, none of which any test in this repository could have caught**, which is the same
thing the inverted camera, the unlit district and the swapped A/D each proved.

| Found by looking | |
|---|---|
| **The tier indicator was completely invisible** | The debug district map is on layer **127**, the HUD on layer 1, and its opaque panel sat exactly on the tier block. Every capture showed the corner as debug output and nothing else. **The debug tool moved, not the HUD** — it is stripped from every release preset and §1 owns the placement. Same call as `DistrictMap.RESERVED_WIDTH`, one layer out. |
| **The cone read as a needle** | §3.1 forbids that in as many words. The cone is only 24° wide and the falloff was `across²`, which puts four fifths of it under a quarter alpha — all a player saw was the bright core. `sqrt` keeps the edges soft and lets the full width read. **A needle drawn from a wobbled bearing communicates the opposite of what the wobble means.** |
| **The vignette tinted the entire frame red** | Two causes. `Color(r, g, b)` defaults to **opaque**, so the alpha that is the whole tuning shipped at 1.0 by omission; and `REACH` 0.22 on two edges leaves only 56 % clear, so the *"centre 60 %"* criterion was ticked against a number that missed it. Now 0.5 and 0.18. |
| **It drew as concentric rectangle outlines** | `draw_rect(..., false, width)` strokes a visible line per band, so the vignette read as a nested wireframe. *Deliberately ugly* means oppressive, not *looks like a rendering fault*. Four per-edge gradients now. |

**AND THE PROBE'S FIRST READING WAS WRONG, WHICH IS WORTH MORE THAN THREE OF THE FOUR.** It
captured the cone pointing **down** for a bearing of zero and that reads exactly like a widget
inverted by π. The widget was right: **the cone is camera-relative**, and the client scene's rig
has its own yaw. The probe unhooks the camera before the two cone diagnostics now, and says why.
An instrument that is wrong in a plausible direction is worse than no instrument.

## Falsified

Five planted defects, all red: two tiers sharing a word, a source bit losing its word, a portrait
surviving a reassignment, a vignette firing at Noticed, and a widget naming `Color.RED`.
