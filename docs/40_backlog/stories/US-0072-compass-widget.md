---
id: US-0072
title: HUD — Compass widget
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-27
depends_on: [BIBLE-UI-UX, TDD-11-UI, ADR-0006]
---

# US-0072 — HUD: Compass widget

| | |
|---|---|
| **Milestone** | M5 |
| **Epic** | `EPIC-HUD` |
| **Systems** | `SYS-HUD`, `SYS-COMPASS` |
| **Estimate** | M |
| **Depends on** | ~~US-0065~~ — **nothing.** The server half (US-0057, US-0058) has been on the wire since M4, and the Compass needs no scoring |

## Description

The game's central instrument: CompassVm plus CompassWidget.

## Acceptance criteria

- [x] Renders a CONE with soft gradient edges — never a hard-edged needle.
      Drawn as radial slices whose alpha falls to zero at both rims. The bearing
      carries `TUN-COMPASS-CONE-WOBBLE`'s deliberate lie, so a crisp needle would
      draw an uncertain value as a certain one.
- [x] 220 px, centre-bottom, 64 px from the edge.
      Anchored rather than positioned, so it holds at any resolution.
- [x] Pulse phase advances at DISPLAY rate; period comes from the 30 Hz authoritative distance.
      `CompassWidget._process` advances it; `CompassVm.period()` reads the bucket
      through `CompassMath.period_for`. **A frame longer than a period wraps in a
      loop rather than one subtraction** — an alt-tab would otherwise leave the
      phase above 1.0 and the ring drawn inside out.
- [x] Ring scale eases OUT; ring alpha eases IN — the onset is the sharp event.
      Asserted as a measurement rather than a shape: a quarter of the way through a
      period the ring has covered **more than 55 %** of its travel and lost **less
      than 15 %** of its alpha. Matched easings redden it.
- [x] Lock arc fills clockwise.
- [x] Emits EVT-COMPASS-PULSED for audio to subscribe to.
      `EventBus.compass_pulsed`, on the frame the phase wraps. **Nothing listens
      yet** — `Audio.play()` is a stub until US-0075 — which is why the widget
      emits unconditionally rather than checking for a subscriber.
- [x] NEVER shows a numeric distance.
      The widget calls no `draw_string` and holds no `Label`, which is the
      strongest version: there is nothing to hand a number to.
- [x] CompassVm holds NO world position, applies NO wobble, performs NO extrapolation.
      All three guarded in `test_compass_invents_nothing.gd`, structurally and
      behaviourally: no `Vector3` field, no `wobble` anywhere client-side, and four
      seconds of frames leave the bearing bit-identical.
- [x] Encodes nothing in hue: distance is cadence, direction is position, lock is arc fill.
      Every colour in the widget is asserted below 0.12 saturation, so none of them
      *can* be a signal. This is why UI_UX_SPEC §7.3 needs no colourblind-safe
      Compass palette — there is nothing to be blind to.

## Test notes

`test_compass_vm.gd` asserts the period against the sampled table at every listed distance.
`test_compass_no_wobble_clientside.gd`, `test_compass_no_position.gd`.

## Notes

Ease-out on scale with ease-in on alpha means the ring expands fast and fades slow, so ONSET is
the sharp event. Onset is what peripheral vision detects; a symmetrical pulse reads as a throb
and cadence becomes much harder to judge.

The protocol prevents leaks; these widget prohibitions prevent INVENTION.

---

## What this story actually built, beyond the Compass

**`EventBus` HAD TWENTY SIGNALS AND ZERO EMITTERS.** It was declared at M0, guarded ever since,
and wired to nothing — `SIGNAL_AND_EVENT_BUS.md` has said throughout that the bridge from the
snapshot *"belongs to the first presentation node that wants it"*. The HUD is that node, so
`HudBridge` is part of this story rather than of US-0073, and everything downstream now has a bus
that carries traffic.

**It emits on CHANGE, never on arrival** — a snapshot lands thirty times a second and a tier
changes a handful of times a match. **The Compass is the deliberate exception**: its bearing moves
almost every tick by construction, since the wobble is a function of the tick, so a change test
there would pass every time and cost a comparison to do it.

**`NOTHING` IS −1 RATHER THAN 0.** Zero is a real tier and a real bearing, so a bridge seeded with
zero would swallow the opening state of a match and the HUD would stay blank until the player's
suspicion happened to move.

## Three findings

**`CompassVM` COULD NOT BE THAT, AND THE HOUSE STYLE ALREADY SAID SO.** `test_file_naming.gd`
splits a `class_name` on every capital, so `CompassVM` demands `compass_v_m.gd`. `NpcPool`,
`RpcRouter` and `NpcView` show the established answer: acronyms are title-cased. It is
**`CompassVm`**, and eleven documents that named it before any code existed were aligned to the
code. A pure identifier rename, nothing semantic.

**AND AN ARCH GUARD HAD A FALSE POSITIVE THAT ONLY A HUD COULD FIND.**
`test_suspicion_is_never_predicted.gd` forbids a client writing `.tier =` — and that is a
substring of `.tier ==`, so it fired on `HudBridge` **comparing** a mirrored field, which is
reading rather than deciding. The needles carry a trailing space now. **That narrows the match
without weakening the rule**: `gdformat` guarantees the space after an assignment and CI checks
the formatting, so every real write still matches and only comparisons stop matching. No client
had ever needed to *read* a mirrored gameplay field before, which is why it took until now.

**AND A GDSCRIPT LAMBDA CAPTURES AN `int` BY VALUE.** The pulse test counted wraps inside a
lambda and read zero — and the failure reads as *the signal never fired* rather than as *the test
cannot see it*. An array is captured by reference.

## Falsified

Five planted defects, all red: matched easings (the pulse becomes a throb), a view model that
extrapolates its bearing, a bridge that invents a persona on reveal, a change-gated Compass, and a
widget that draws a distance.
