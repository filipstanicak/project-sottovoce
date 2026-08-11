---
id: US-0024
title: Feel latency measurement harness
version: 1.0.0
status: in-progress
owner: Technical Director
last_updated: 2026-08-11
depends_on: [GDD-02-PLAYER, BIBLE-TEST-PLAN]
---

# US-0024 — Feel latency measurement harness

| | |
|---|---|
| **Milestone** | M1 |
| **Epic** | `EPIC-CAMERA` |
| **Systems** | `SYS-PAWN` |
| **Estimate** | S |
| **Depends on** | US-0023 |

## Description

Automated measurement of input-to-visible-animation latency, plus the M1 feel-gate checklist.

## Acceptance criteria

- [ ] `test_feel_latency.gd` measures input to first animation frame change.
      **Built, and it cannot reach the animation.** The harness exists and measures three of the
      five stages `FeelChain` declares; `ANIMATE` is blocked because no clip exists to change
      pose, and `PRESENT` because headless CI has no display.
      `test_feel_chain.gd::test_the_animation_stage_is_still_blocked` goes red the day a clip
      lands, and says what to finish.
- [ ] Measured latency is at or under 80 ms at 60 fps with prediction active.
      **Two blockers, both named.** The measured stages come in at 16.7–33.3 ms, well inside 80 —
      but that is a *lower bound* on a chain missing its last two stages, and **prediction does
      not exist yet** (US-0032, M2), so "with prediction active" cannot be true of any number
      taken today.
- [x] No animation except KillAnim reaches the 1.4 s commitment ceiling.
- [ ] The M1 feel-gate checklist is run and logged: instant slowdown from every state, ten sloppy
      vaults all resolve, FOV ladder perceptible without nausea.
      **Runnable now — see the checklist below. It needs the owner at the controls, and no test
      may tick it.**

## Test notes

The automated measurement is a proxy. It can read 78 ms while the game still feels sluggish
because of animation blend curves — so the manual checklist is required alongside it, not
instead of it.

---

## What the harness measures, and what it refuses to

`FeelChain` declares five stages between a key press and the player's eye:

| Stage | What happens | Measured? |
|---|---|---|
| `SAMPLE` | `InputSampler` polls the input into an `InputCommand` | yes |
| `SIMULATE` | `PawnStateMachine.step()` produces a velocity and a state | yes |
| `APPLY` | `LocalPawnDriver` moves the body | yes |
| `ANIMATE` | the blend tree reacts and the mesh changes pose | **no — no clips exist** |
| `PRESENT` | the frame reaches the display | **no — headless CI has no display** |

Every number the harness prints carries `FeelChain.coverage_note()` beside it. That is not
decoration: a bare "33 ms, within budget" in a log gets quoted later as input-to-animation
latency, which is not what it is.

## What it found

| Measured | Ticks | ms |
|---|---|---|
| Run → blend-walk | 1 | 16.7 |
| Sprint → deceleration begins | 1 | 16.7 |
| Press → first velocity, from rest | 2 | 33.3 |
| Press → body actually moves, from rest | 2 | 33.3 |

**One tick down, two up**, and the second one is `IdleState.step()` integrating toward its own
target of zero before handing over to `Stroll`. So ADR-0012's "the defensive option is cheap;
the aggressive one is not" turns out to be visible at tick resolution — the only place in the
project where that claim is measured rather than described.

### Two measurement bugs, both caught in the harness itself

1. **The settle looked like a response.** A freshly spawned pawn slides 0.088 m on its first
   frame resolving onto the floor. Measuring position change without settling first reported a
   1-tick response to a key that had not been read yet. Trap 4 — *assert the shape of a result,
   not its magnitude* — applies hardest to the instrument.
2. **`SceneTree.physics_frame` straddles the driver.** Counting tree frames makes the reading
   depend on node order. The harness counts `LocalPawnDriver.pawn_stepped` instead, which fires
   after `step()` and `_apply_motion` have both run.

Neither would have failed a test. Both would have put a wrong number in a document.

## Criterion 3: the word that matters is *unskippable*

`test_commitment_ceiling.gd` classifies every committed state by **whether the player can get
out**, not by how long it lasts. Duration alone is the wrong test, and `Climb` is why: a 9 m
façade at `TUN-SPEED-CLIMB` takes **3.2 s**, more than twice the ceiling, and does not breach it
— pulling away from the wall lets go on any tick. A commitment you can back out of is not a
commitment.

| State | Worst case | Way out |
|---|---|---|
| `KillAnim` | 1.4 s | none — *exactly at* the ceiling, and the only thing allowed there |
| `Vault` / mantle | 0.55 / 0.95 s | none, so the duration is what protects the player |
| `StunAnim` | 0.7 s | none. Half the kill: defence is faster than offence |
| `Climb` | 3.2 s | **the player lets go**, any tick |
| `Drop` | ~2.1 s roof→street | none below FATAL. Not an animation — see below |
| `Stunned` | 4.0 s | none, and exempt: §5 governs what you *commit to*, not what is done to you |

### Recorded, not silently exempted

A roof-to-street drop is 8.5 m of fall (~1.3 s) plus `TUN-TRAVERSE-DROP-STAGGER` (0.8 s), with
nothing below FATAL interrupting either part. **~2.1 s is the longest no-input window a player
can walk into by choice.** It is not an animation, so criterion 3 is met — but the number is
larger than the stated ceiling and belongs somewhere a reader will find it. US-0020 chose that
stagger deliberately as "a window during which you can be killed"; this is a note, not a
challenge to it.

---

## The M1 feel gate — the owner's checklist

**Run this yourself. No test may tick it**, and an agent reporting it as passed would be
reporting a subjective judgement it did not make.

```bash
godot --headless -- --server --port 27015 --max-players 6
```

```bash
godot -- --connect 127.0.0.1:27015
```

**One command, and no server.** `boot.gd` loads `client_root.tscn` with or without `--connect`;
the "client, menu" log line names a menu that does not exist. The two-terminal recipe elsewhere in
this corpus is for testing the network topology, not for playing.

Controls: **WASD** move · **Left Ctrl** blend-walk · **Left Shift** run (hold ~0.35 s for Run) ·
**double-tap Shift** sprint · **Space** traverse · **Middle mouse** crowd-scan.

The mouse is **captured on launch**. **Escape** releases it so the window can be left; **click**
takes it back. Both arrived in #48, along with the fix for a vertical axis that had been inverted
since US-0021 — the first attempt to run this checklist is what found them, which is the argument
for the checklist existing at all.

A readout appears top-left in any debug build (`scripts/debug/feel_readout.gd`, attached at
runtime by `LocalPawnDriver` — never by a scene, because the release presets strip that folder):

```
STATE   Sprint
SPEED    6.20 m/s
LENS     72.0 deg
HEIGHT   0.10 m

TRAVERSE  ##.#####.#
          8 of 10 resolved
```

**It tells you what you cannot feel and nothing else** — which state you were in, what the lens
is doing, and how your last ten traverse presses went. It deliberately does *not* say whether
slowing felt instant. A readout that answered that would replace the judgement the gate is asking
for with a number about the judgement.

### 1. Slowing down is instant from every state

For each row: reach the state, then hit **Left Ctrl** and judge whether the pawn slows *on the
press* or a beat after it. Use the readout to confirm you were in the state you meant to be in
— **not** to decide whether it felt instant. If you need the numbers to tell, the answer is
already no.

| Reach it by | State | Instant? |
|---|---|---|
| stand still | Idle | |
| W | Stroll | |
| W + Shift, tap | Jog | |
| W + Shift, held past 0.35 s | Run | |
| W + Shift + double-tap Shift | Sprint | |
| Space at a low wall, press Ctrl mid-vault | Vault | (expected: **not** until it ends — 0.55 s) |
| Space at a tall façade, press back mid-climb | Climb | (expected: lets go into a drop) |

### 2. Ten deliberately sloppy vaults all resolve

Approach a low wall ten times at bad angles, off-centre, late, and at different speeds. Press
Space each time. Count how many produce a vault rather than nothing.

**Ten of ten, or the forgiveness windows need work.** The readout tallies it: `#` resolved,
`.` produced nothing. Score: ___ / 10

### 3. The FOV ladder is perceptible without being nauseating

Accelerate stroll → jog → run → sprint and back down, several times, then hold **middle mouse**
to crowd-scan. Two questions, both required:

- Can you feel the lens widening *before* you would have read a number? (It must be perceptible.)
- Does repeated up-and-down cause any discomfort? (It must not.)

If the second answer is yes, the lever is `TUN-CAM-FOV-BLEND-RATE` (90 °/s), and
motion-reduction must be discoverable *before* someone feels ill — GDD-02 §9.4 failure mode 6.

### Log the result here

| Line | Verdict | Date | Note |
|---|---|---|---|
| Slowing is instant from every state | | | |
| Ten sloppy vaults resolve | | | |
| FOV ladder perceptible, not nauseating | | | |
| Input → animation ≤ 80 ms | **cannot be judged** | — | no animation exists |

---

## What this story does not do

- **No animation measurement.** Criteria 1 and 2. The tripwire in `test_feel_chain.gd` is what
  makes this a deferral rather than an omission.
- **No prediction.** Criterion 2's "with prediction active" needs US-0032, in M2. Today's client
  simulates rather than predicts, which is the same code path minus reconciliation.
- **Nothing in `test/metrics/`.** The folder is declared in TDD-02 and empty, and **CI does not
  run it** — a harness placed there would never execute. That is the fourth declared-but-not-real
  thing this milestone has turned up; it is recorded here rather than fixed, because wiring a new
  suite into CI is not this story's scope.
- **No fix for the double-sampled input** — it got its own change, and is **closed**. Found
  while wiring the readout: `InputSampler.sample()` ran twice per physics frame, so `SprintGate`
  counted at double rate and `TUN-SPEED-SPRINT-HOLD` opened in 0.2 s instead of 0.4 — the
  deliberate friction §1.5 spends a page defending, at half price. Fixed in
  [#44](https://github.com/Slimexsan/project-sottovoce/pull/44) by making `LocalPawnDriver` the
  only caller of `sample()` and moving `command_sampled` onto it. Re-measured after the fix:
  **24 emissions to open a gate specified at 24 ticks.** The checklist above is safe to run as
  written; sprint arms at the speed it is meant to.
