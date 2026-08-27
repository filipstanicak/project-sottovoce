---
id: BIBLE-UI-UX
title: UI/UX Specification
version: 0.1.0
status: draft
owner: Lead Game Designer
last_updated: 2026-08-03
depends_on: [GDD-06-UI-AUDIO, TDD-11-UI, BIBLE-ART, ADR-0006]
---

# UI/UX Specification

> **Context restated.** In Project Sottovoce the HUD is not a presentation layer over the
> mechanics — it *is* their delivery system. The Compass is how you hunt. The prey warning is how
> you survive. The score feed is how you learn. A UI bug here is a gameplay bug: a Compass
> showing a stale bearing is not a cosmetic defect, it is the game lying to the player about the
> only thing it tells them.
>
> **The constraint that shapes every decision below:** the player's eyes belong on the crowd.
> Every HUD element must be readable in **≤ 0.5 s** (`TUN-UI-READABILITY-TARGET`), in peripheral
> vision, without being looked at directly.

---

## 1. Layout grid

1920 × 1080 reference. All positions scale proportionally; nothing is pixel-anchored.

| Property | Value |
|---|---|
| Safe area | 5 % inset — 96 px horizontal, 54 px vertical |
| Base unit | **8 px** at reference scale. Every margin, padding and size is a multiple |
| Columns | 12, gutter 24 px |
| Scaling mode | `canvas_items`, `expand`, aspect `keep_height` |
| Minimum supported | 1280 × 720 |
| Ultrawide | Elements anchor to a centred 16:9 band; the Compass never leaves it |

### 1.1 Element placement

```
┌─────────────────────────────────────────────────────────────┐
│  ┌──────────┐              ┌──────┐                         │ ← safe area
│  │ CONTRACT │              │ 4:38 │  E timer                │
│  │ PORTRAIT │              └──────┘                         │
│  │    B     │                                               │
│  └──────────┘                                               │
│                                                             │
│                                                             │
│                          ·   ·                              │
│                        ·  F  ·   crosshair (screen centre)  │
│                          ·   ·                              │
│                                                             │
│                                                  ┌────────┐ │
│                                                  │ +100   │ │
│  ┌────────┐                                      │ Silent │ │
│  │   ◐    │  C tier                              │ +150   │ │
│  │NOTICED │                                      │Patient │ │
│  └────────┘        ╭──────────╮                  └────────┘ │
│                    │    ▲     │  A COMPASS         D feed   │
│  ┌───┐┌───┐        │  ╱   ╲   │  centre-bottom              │
│  │ Q ││ F │  G     │ ╱ cone ╲ │                             │
│  └───┘└───┘        ╰──────────╯                             │
└─────────────────────────────────────────────────────────────┘
```

| Element | Anchor | Size | Rationale |
|---|---|---|---|
| **A Compass** | Bottom-centre, 64 px from edge | 220 × 220 | Most-consulted element. Centre-bottom is reachable by peripheral vision without moving the eyes off the crowd |
| **B Contract portrait** | Top-left | 180 × 220 | Consulted rarely (on assignment, after a lock). Corner is correct |
| **C Tier indicator** | Left, above abilities | 160 × 72 | Glanceable; near the abilities it constrains |
| **D Score feed** | Right, above centre | 320 × 220 | Peripheral by design — must be readable *without* looking |
| **E Match timer** | Top-centre | 120 × 48 | Matters intensely for ~40 s of 480; ignorable otherwise |
| **F Crosshair** | Screen centre | 3 px dot | The one element that must be exact |
| **G Ability slots** | Bottom-left | 2 × 64 px | Below the tier indicator that governs their cost |

**Nothing occupies the centre 60 % of the screen.** That region is where players read faces and
gait, and it is kept clear deliberately.

---

## 2. Type scale

Single family, three weights, five sizes. A modular scale at 1.25.

| Role | Size | Weight | Use |
|---|---|---|---|
| `DISPLAY` | 48 px | Bold | Match timer, results placement |
| `HEADING` | 32 px | Bold | Screen titles, results names |
| `BODY-LARGE` | 24 px | Medium | **Score-feed bonus names**, tier word |
| `BODY` | 19 px | Regular | Lobby ability descriptions, menu items |
| `CAPTION` | 15 px | Medium | Audio captions, cooldown seconds, key labels |

| Rule | Value |
|---|---|
| Minimum size anywhere | **15 px** at reference (≈ 10 px at 720p) |
| Line height | 1.4× |
| Tracking | +2 % on `BODY-LARGE` and above |
| Numerals | **Tabular** — score values must not reflow as digits change |
| Contrast | ≥ 7:1 against its own backing plate (WCAG AAA) |
| Backing | Every text element has a plate or outline. **Text is never drawn directly over the world** |

**Tabular numerals matter more than they sound.** A score feed whose `+100` and `+150` have
different widths produces horizontal jitter in peripheral vision, which reads as motion and pulls
the eye — the exact opposite of what the feed is for.

---

## 3. The Compass widget

The game's central instrument. Specified to the frame.

### 3.1 Anatomy

```
              ▲ north-relative? NO — camera-relative
        ╭─────────────╮
        │      ╱▒╲     │  ← direction cone, half-width 12°
        │     ╱▒▒▒╲    │     wobble ALREADY APPLIED server-side
        │    ╱▒▒▒▒▒╲   │
        │   ┌───────┐  │  ← lock arc, fills clockwise from top
        │   │   ●   │  │  ← pulse ring, scales + fades
        │   └───────┘  │
        ╰─────────────╯
             220 px
```

| Part | Spec |
|---|---|
| **Direction cone** | Filled arc, half-width `TUN-COMPASS-CONE-HALFWIDTH` 12°, camera-relative. Soft gradient edges — **never a hard-edged needle**, because the visual must communicate imprecision |
| **Pulse ring** | Concentric ring, scale 1.0 → 1.35, alpha 0.9 → 0.0 over one period |
| **Lock arc** | Outer ring, fills clockwise, 0 → 360° over `TUN-COMPASS-LOCK-FILL-TIME` |
| **Centre dot** | Static reference point |

### 3.2 The pulse animation curve

The period comes from `CompassMath.pulse_period(distance)` — Core, unit-tested against the
sampled table in [`../50_tuning/TUNABLES.md`](../50_tuning/TUNABLES.md) §4.2. The widget only
animates the *phase*.

```gdscript
## phase advances at DISPLAY rate; period comes from the 30 Hz authoritative
## distance. A 144 Hz and a 60 Hz client see the same CADENCE, smoothed differently.
phase += delta / period
if phase >= 1.0:
    phase -= 1.0
    EventBus.compass_pulsed.emit()      # Audio subscribes here

# Ring scale: ease-out, so the pulse LEAVES quickly and the eye registers onset
ring_scale = 1.0 + 0.35 * ease_out_cubic(phase)
ring_alpha = 0.9 * (1.0 - ease_in_quad(phase))

# Cone brightness: a brief flash on each pulse, so the pulse is visible
# even when the player is looking at the cone rather than the ring
cone_brightness = 1.0 + 0.25 * (1.0 - ease_out_quint(phase))
```

**Ease-out on scale, ease-in on alpha.** The ring expands fast and fades slow, so the *onset* is
the sharp event. Onset is what the eye detects in peripheral vision; a symmetrical pulse reads as
a throb rather than a beat, and cadence becomes much harder to judge.

### 3.3 What the widget must never do

Each corresponds to a rule the protocol already enforces. The protocol prevents leaks; these
prevent **invention**.

| Never | Why |
|---|---|
| Compute distance from a world position | It has a `distance_bucket`, not a position, and must not acquire one |
| Apply its own wobble | Wobble is server-side and deterministic per contract, so every peer sees the same cone. A client-side wobble would be a second, unlearnable lie |
| Extrapolate the bearing forward | The Compass must never contain information newer than the simulation |
| Show a numeric distance | Deletes the entire point of a cadence-encoded channel |
| Point north | It is camera-relative. A north-relative compass is a map |

---

## 4. The tier indicator

Encodes tier in **shape + colour + word simultaneously**, so it survives monochrome and every
colourblind palette.

| Tier | Shape | Word | Screen effect |
|---|---|---|---|
| Anonymous | `○` open circle | `ANONYMOUS` | none |
| Noticed | `◐` half-filled | `NOTICED` | none |
| Exposed | `▲` filled triangle | `EXPOSED` | Screen-edge vignette over `TUN-UI-DAMAGE-VIGNETTE-TIME` 0.8 s |

### 4.1 The active-source list

Below the tier, a compact list of contributing sources, updated from the snapshot's
`active_sources` bitfield:

```
  ◐ NOTICED
    sprinting · alone
```

**This exists to answer "why am I visible?" before the player asks it.** Part 3's failure mode 3
is "suspicion is opaque" — a player who cannot attribute their suspicion cannot learn from it,
and the total alone is not attributable.

### 4.2 The vignette is the only full-screen effect

Reserved entirely for Exposed. It is the visual language of failure, and it is deliberately ugly.
Nothing else in the game takes the whole screen.

---

## 5. The score feed

| Property | Value |
|---|---|
| Max simultaneous lines | `TUN-UI-SCOREFEED-MAX-LINES` 4 |
| Line lifetime | `TUN-UI-SCOREFEED-DURATION` 4.0 s (raisable to 8 s) |
| Stagger within one kill | `TUN-UI-SCOREFEED-STAGGER` 0.12 s |
| Entry | Slide 16 px + fade, 0.15 s |
| Exit | Fade only, 0.3 s |
| Layout | Value right-aligned (tabular), name left-aligned below |

### 5.1 Why the stagger matters

Four bonuses arriving simultaneously is **one** event. Arriving 0.12 s apart they are **four**,
each individually readable — and the sequence is measurably more satisfying, which is a real
effect and not a small one.

Paired with `SFX-SCORE-BONUS-LARGE` pitching up per position in the stack, a four-bonus kill
*ascends*. This is the cheapest high-value feedback in the project.

### 5.2 Penalties are visually distinct

`−50 Reckless` uses the penalty treatment: different plate, different weight, no ascending pitch.
The one negative event must never read as a smaller positive one.

---

## 6. The crosshair

The one widget with a hard correctness requirement.

| State | Appearance |
|---|---|
| Default | 3 px dot |
| Kill available | Dot + ring, 18 px |
| Stun available | Dot + bracket pair (distinct shape, not just colour) |

> **The ring appears if and only if pressing kill would succeed.**

Fed by server-computed `kill_ready` / `stun_ready` flags in the snapshot — **never** by a
client-side range check, which would disagree with lag-compensated validation.

Part 2's failure mode 7 is "kill feels unresponsive". A lying crosshair is worse than no
crosshair, and `test_crosshair_truth.gd` asserts agreement across 500 randomised poses.

---

## 7. Colour palettes

All colour comes from a `Palette` resource injected into every widget. **No widget names a colour
literal** (`test_no_colour_literals.gd`).

### 7.1 The four palettes

| Palette | For |
|---|---|
| `DEFAULT` | Trichromatic vision |
| `DEUTERANOPIA` | Red-green, most common |
| `PROTANOPIA` | Red-green |
| `MONOCHROME` | Total colour blindness, and the **verification palette** for every other design |

### 7.2 The persona identity hues

Reserved by the colour-language law ([`ART_BIBLE.md`](ART_BIBLE.md) §3). Chosen so the four remain
distinguishable in every palette — which is why they differ in **value** as well as hue.

| Persona | Default | Deuteranopia | Protanopia | Monochrome value |
|---|---|---|---|---|
| Vetraio | Amber | Amber | Amber | 78 % |
| Cantatrice | Rose | Blue-violet | Blue-violet | 45 % |
| Lucerna | Cyan | Cyan | Cyan | 62 % |
| Pesatore | Jade | Yellow | Yellow | 30 % |

**The monochrome column is the real test.** Four hues spanning 30–78 % value are distinguishable
by brightness alone, which means the identity channel never depends on hue discrimination.

### 7.3 The colourblind-safe Compass

The Compass encodes **nothing** in hue:

| Information | Encoding |
|---|---|
| Distance | **Cadence** — temporal, hue-free |
| Direction | **Position** of the cone |
| Lock progress | **Arc fill** |
| Prey warning | **Flash + shape change + audio sting** |

This was a design requirement before it was an accessibility one, and it happens to solve both.

---

## 8. Motion and animation

| Element | Duration | Curve |
|---|---|---|
| Tier transition | `TUN-UI-TIER-TRANSITION-TIME` 0.25 s | ease-in-out |
| Score-feed entry | 0.15 s | ease-out |
| Score-feed exit | 0.30 s | linear |
| Cooldown sweep | continuous | linear — **must be linear**, so remaining time is readable by angle |
| Vignette | 0.8 s | ease-in |
| Screen transitions | 0.2 s | ease-in-out |

### 8.1 Motion-reduction mode

| Change | |
|---|---|
| Camera FOV locked at 62° | Removes the speed-warning channel |
| **Compensating**: persistent speed-state indicator added to the tier widget | A *different* channel, not a removed one |
| Compass pulse: ring scaling reduced, opacity flash retained | Cadence preserved exactly |
| Score feed: fade only, no slide | |
| Vignette: static alpha, no pulse | |

**The trade is stated to the player** in the options screen, because motion-reduction removes the
FOV warning and players should know they are making that exchange.

---

## 9. The 0.5 s readability test

The chapter's gate. Run at every UI milestone.

### 9.1 Procedure

1. Capture every HUD state: each tier, each Compass distance band, 0–4 feed lines, each crosshair
   state, both ability cooldown states, the final-phase timer.
2. Show each to a tester for **500 ms**, then blank.
3. Ask: *"What is your suspicion tier? Is your target near or far? Can you kill right now?"*
4. **≥ 90 % accuracy across ≥ 5 testers, per state.**

### 9.2 Repeat under

- Each of the four palettes.
- Motion-reduction on.
- **Peripheral presentation** — tester fixates screen centre; HUD in the periphery. This is the
  realistic condition, and the one elements are actually designed for.

### 9.3 Automation boundary

`test_hud_readability.gd` renders and **archives** every state for the manual test. It does not
score legibility — automated legibility scoring is a research problem, and the manual test with
real people is the actual measure. The automation exists so no state is forgotten.

---

## 10. Screens

| Screen | Requirement |
|---|---|
| `MainMenu` | Host / Join (direct IP) / Options / Quit |
| `Lobby` | **An information surface, not a menu.** Every ability's cooldown, suspicion cost and **tell** shown, because loadouts lock for the whole match. Personas visible to all; **loadouts visible to none** |
| `HUD` | Live during PLAYING and FINAL. Never unloaded mid-match — reloading drops view-model state including the pulse phase |
| `Results` | 25 s, unanimous skip only. **The per-bonus breakdown is the screen's purpose**; placement is just the frame |
| `Options` | Video, audio buses, input rebinding, accessibility |

### 10.1 The lobby's information requirement

Loadouts are locked for 8 minutes across every respawn. A player choosing blind will be stuck
with a bad pick for the whole match, and the mitigation is not to unlock loadouts — it is to make
the choice informed. **Every ability's tell is stated in one sentence in the lobby**, so a player
can choose without having used it.

---

## 11. Acceptance criteria

- [ ] Every element sits on the 8 px grid within the 5 % safe area.
- [ ] No element occupies the centre 60 % of the screen except the 3 px crosshair.
- [ ] All text ≥ 15 px at reference, ≥ 7:1 contrast, on a plate or outlined.
- [ ] All numerals tabular.
- [ ] The Compass renders a **cone**, never a needle, and shows no numeric distance.
- [ ] `CompassVm` holds no world position and applies no wobble.
- [ ] Pulse period matches the TUNABLES §4.2 table at every listed distance within 1 ms.
- [ ] The tier indicator encodes shape **and** colour **and** word.
- [ ] The active-source list appears whenever any source contributes.
- [ ] The Exposed vignette is the only full-screen effect.
- [ ] Score-feed bonuses arrive staggered; penalties visually distinct.
- [ ] The crosshair ring agrees with server kill validity across 500 poses.
- [ ] All four palettes exist; no widget names a colour literal.
- [ ] All three tiers distinguishable in `MONOCHROME`.
- [ ] Motion-reduction adds the compensating speed indicator.
- [ ] Every HUD state passes the §9 test at ≥ 90 % across ≥ 5 testers, in every palette.
- [ ] The lobby states every ability's cooldown, suspicion cost and tell.
- [ ] No user-facing string literal in any widget.

---

## 12. Open questions

| # | Question | Position | Needed by |
|---|---|---|---|
| 1 | Is 220 px enough for the Compass to be readable peripherally at 1080p? | Test at M5. If not, grow it before moving it — position is more load-bearing than size | M5 |
| 2 | Should the contract portrait show the full persona on reveal, or only a silhouette class? Full narrows ~78 candidates to ~12. | Full for MVP (ASM-0030) — it is what the player saw during the reveal anyway. Degrade to class only if `TEL-TIME-TO-KILL` drops sharply after first lock | M5 |
| 3 | No HUD indication of stun-lockout remaining when you are the stunned player. Being unable to act with no visible reason is the worst kind of opacity. | Add to the tier widget at M5. Small addition, real cost if omitted | M5 |
| 4 | Should the score feed show *which contract* a bonus was for during a fast multi-kill? | No. It would need identity information the protocol deliberately withholds | — |
| 5 | Peripheral readability (§9.2) may be the binding constraint and is the least-tested condition. | Make it the *first* condition tested at M5, not the last | M5 |
