---
id: US-0022
title: Camera FOV ladder
version: 1.0.0
status: done
owner: Lead Game Designer
last_updated: 2026-08-06
depends_on: [GDD-02-PLAYER, TUN-INDEX]
---

# US-0022 — Camera FOV ladder

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-CAMERA` |
| **Systems** | `SYS-CAMERA` |
| **Estimate** | S |
| **Depends on** | US-0021 |

## Description

FOV bound to speed state, transitioning at 90 deg/s.

This is not a style choice, it is a warning system. The widening FOV at speed produces peripheral
distortion that tells the player pre-consciously that they are doing something conspicuous,
before they read the tier indicator.

## Acceptance criteria

- [x] FOV per state: 55 blend, 60 stroll, 65 jog, 69 run, 72 sprint.
- [x] Transitions at 90 deg/s.
- [x] FOV matches the ladder within 1 degree at each steady speed state.
- [x] Each PawnState returns its own camera_fov from CameraTuning.
- [x] Motion-reduction mode locks FOV at 62 and the compensating indicator is added elsewhere.

## Test notes

`test_camera_fov_ladder.gd` samples FOV at each steady state.

**It does so through the real client**, pressing the real `InputMap` actions and reading
`Camera3D.fov` off the real rig, because the three defects this project has shipped furthest
were all of the same shape: correct arithmetic that nothing ever called. Sprint is reached by
the sustained hold rather than the double-tap — `SprintGate` covers both, and a hold is what a
test can express without pretending to know the tick a human would tap on.

Two more files sit under it. `test_camera_fov.gd` proves the arithmetic; `test_camera_fov_rungs.gd`
proves each state names the right rung, and that **no state is off the ladder** — the whole
registry, so a state added later cannot quietly introduce a sixth value.

## Notes

The narrow blend-walk FOV does the opposite job: it compresses the scene and makes distant faces
larger and more comparable. Slowing down literally lets you see more clearly — the thesis
rendered as a lens.

---

## Where the ladder lives, and why not in the camera

On the **states**, one `camera_fov()` each, which the rig asks for through the driver. The
alternative — the rig reading `ctx.velocity` and interpolating — is smaller code and wrong, and
wrong in a way no test would have caught: it would widen during every acceleration ramp, while
the pawn was still labelled Stroll and still paying Stroll's suspicion rate. The lens would be
reporting a different fact from the meter, and the player would learn to trust neither.

The rung is a consequence of the **decision** — pressing run, releasing slow — not of the physics
that follows it.

## Three states that §4.2 does not name

The ladder in §4.2 is a table of speeds. Three implemented states are not speeds, and inheriting
a default silently is how a design decision gets made by nobody:

| State | Rung | Why |
|---|---|---|
| `Blended` | **blend**, 55° | The narrow end exists to make distant faces larger and more comparable, and standing still inside a group *looking at people* is the purest instance of that act in the game. Framing a blended player at stroll would hand them a **wider** view for holding still, which is the ladder backwards. |
| `KillAnim` | stroll, 60° | Neutral. The lens says one thing — how fast you are moving — and a player mid-kill already knows what they are doing. Widening would spend the channel on information the actor has and the victim cannot see. |
| `Stunned` | stroll, 60° | Neutral, same reason. The punishment is already the fixed offset and four seconds of watching; dramatising it with the lens would spend the warning channel on a state the player cannot act on. |

`Vault`, `Climb` and `Drop` were already on the ladder from US-0019/0020 — stroll, jog and run —
chosen so the lens does not jump at the moment the player has least control.

## What was added to the tuning table

- **`TUN-CAM-FOV-MOTION-REDUCED`, 62°.** Promoted from prose: GDD-02 §9.4 gave the value without
  an ID, the same way §4.4 gave the occlusion pull-in without saying where it stops (US-0021).
- **Invariant 21**, the FOV ladder is monotonic. Inverted it would still be a channel — it would
  simply tell a sprinting player they were calm, which is worse than silence, and it is invisible
  to every test that samples one state at a time.
- **Invariant 22**, the locked value sits inside the ladder it replaces. Outside that span,
  motion-reduction would frame *every* speed unusually: a second cost on top of the warning
  channel the mode already gives up.

Both are falsified in `test_tuning_ranges.gd` rather than trusted.

## Motion reduction: the mechanism, not the mode

`CameraRig.motion_reduction` locks the lens, and nothing sets it — the same shape as
`swap_shoulder()` in US-0021. The options screen, `IProfileStore`, the bob and speed-line halves,
and the **persistent speed indicator that compensates for the channel this removes** are all
US-0084. That indicator matters: §9.4 states the trade honestly, and a build that shipped the
lock without it would take a warning channel away from exactly the players least able to spare
one.

The mode **replaces** the ladder rather than damping it. A slower blend still sweeps the same
17°, and the sweep is the part that makes people ill.

## What this story does not do

- **No crowd-scan.** US-0023. `TUN-CAM-CROWDSCAN-FOV` (48°) is deliberately *not* in the set of
  values a state may return: it is a mode, not a rung, and it arrives through a different path.
- **No speed lines and no camera bob.** §4.2 describes peripheral distortion; what exists is the
  FOV change that produces it. The particle and post-process halves belong to M6 polish.
- **Still no key bound to the shoulder swap.** Unchanged from US-0021, and still waiting on a
  seam for camera-only inputs.
