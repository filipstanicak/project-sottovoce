---
id: US-0023
title: Crowd-scan input
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-07
depends_on: [GDD-02-PLAYER]
---

# US-0023 — Crowd-scan input

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-CAMERA` |
| **Systems** | `SYS-CAMERA` |
| **Estimate** | S |
| **Depends on** | US-0022 |

## Description

The held crowd-scan input: slower look sensitivity, narrower FOV, capped movement.

Reading the crowd is the game's central act, so it gets its own button rather than being an
emergent consequence of standing still.

## Acceptance criteria

- [x] Look sensitivity multiplied by 0.45 while held.
- [x] FOV narrows to 48 degrees — narrower than any speed state.
- [x] Movement capped at blend-walk speed.
- [ ] Ambience ducked slightly; footstep sources sharpened.
      **Blocked on there being any audio.** `Audio` is a stub whose `play()` does nothing;
      the dispatcher, the bus layout and every duck rule are US-0075. Nothing to duck.
- [x] Grants NO mechanical advantage: no reveal, no highlight, no tag.
- [x] Available as hold or toggle.

## Test notes

Verify no gameplay state changes while scanning.

**That is the hard half, because it is an absence.** `test_crowd_scan_grants_nothing.gd` steps
two identical pawns with identical input differing only in the scan bit and compares the whole
`PawnContext` field by field. `velocity` is the only permitted difference, because it is the
documented cost. A future change that quietly granted something shows up as a field that stopped
matching, and has to justify itself here.

`test_crowd_scan.gd` drives the real client: the real `InputMap` binding, the real sampler, the
real rig. It measures the same 100 px of mouse motion twice and asserts the ratio is 0.45.

## Notes

Crowd-scan is the game's aim-down-sights and deliberately grants nothing mechanical. It grants
slower, closer, quieter looking — the advantage is entirely in the player's own perception. This
is the clearest single statement of what kind of game this is.

---

## The trap: the cap is on the SPEED, never on the STATE

`INPUT-SLOW` caps speed **and** routes to `BlendWalk`. Reusing that path for scan is one line
shorter and would have been a serious design defect: `BlendWalk`'s suspicion **decays**. A player
holding scan for a moment would launder the suspicion they had accrued sprinting, and a button
that launders suspicion is precisely the mechanical advantage §4.3 spends the entire feature
refusing to grant.

So the cap is applied in `LocomotionState._integrate()` alongside slow's, and the state is left
alone. A scanning runner keeps Run's label, pays `TUN-SUSPICION-GAIN-RUN`, and moves at a
civilian's pace. **A pure cost, never a discount** — which is what makes 01_vision.md §6.1's loop
tension real: you cannot read the crowd while crossing it at speed.

## Buttons before look

`InputSampler.sample()` now resolves the buttons **before** the look, where it used to do the
opposite. `INPUT-SCAN` scales look sensitivity and is hold-or-toggle, so whether it is held is
only known once `InputLatch` has resolved. Sampling look first applied a toggled scan one frame
late — sixteen milliseconds nobody would feel, and a command whose own fields disagreed with each
other, which is the kind of thing a replay finds and a human does not.

`_sample_buttons` reads `_command.move`, so move still goes first. The order is now move →
buttons → look, and `test_crowd_scan.gd` fails if it is put back.

## Scan wins over motion reduction

GDD-02 §9.4 disables FOV changes **with speed** — the ladder, which moves constantly without
being asked. Crowd-scan is a change the player holds a button for, and it is the game's central
act. Removing it from motion-reduction players would hand them §9.4's own failure mode 9: a
competitive disadvantage bought with an accessibility setting.

`CameraFov.wanted()` therefore checks `scanning` first. **One line to reverse** if that reading is
ever judged wrong, and it is flagged here because §9.4 does not address the interaction directly.

## Where the whole feature lives

`CameraRig`, `InputSampler` and one `minf` in `LocomotionState` — and that is the point.
`CameraRig.is_scanning()` exists for the tests and is read by nothing else, because there is
nothing to grant. A scan that reached `SYS-COMPASS` or `SYS-CROWD` would have become an ability.

`test_crowd_scan_grants_nothing.gd` asserts that exactly **two** files under `scripts/pawn/`
mention the scan bit: the cap, and the accessor on `InputCommand` that exposes it. A third has to
argue for itself.

## What this story does not do

- **No audio.** Criterion 4, above. US-0075.
- **No movement-state change.** By design, permanently. See the trap above.
- **Nothing for the Compass.** §4.3: "unchanged — scanning gives no extra information, only
  better perception of existing information." `SYS-COMPASS` is M5 and must stay unaware that
  crowd-scan exists.
