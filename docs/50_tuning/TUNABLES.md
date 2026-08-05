---
id: TUN-INDEX
title: Tunables — Single Source of Truth
version: 0.1.0
status: draft
owner: Documentation Architect
last_updated: 2026-08-03
depends_on: [DOC-GLOSSARY]
---

# Tunables — Single Source of Truth

**Every number in Project Sottovoce is defined here, exactly once.** No other document
states a gameplay value; other documents cite the `TUN-` ID. No script contains a gameplay
literal; every value is read from a `TuningProfile` resource whose fields are generated
from this table.

This is the most-referenced document in the corpus. Treat a change to it as a change to the
game.

---

## 1. How to use this document

### 1.1 Row format

Every row has five columns, and none may be empty:

| Column | Meaning |
|---|---|
| **ID** | `TUN-<DOMAIN>-<NAME>`, uppercase, hyphenated. Immutable once merged. |
| **Value** | The shipping default. |
| **Unit** | `s`, `m`, `m/s`, `deg`, `pts`, `/s`, `Hz`, `ms`, `×`, `count`, `%`, `bool`. |
| **Range** | The legal tuning range. Outside it, the value is a bug, and CI asserts this. |
| **Rationale** | One line. *Why this number and not a different one.* Never "feels right". |

### 1.2 The mapping to code

Each domain section maps to one `TuningProfile` sub-resource:

```
data/tuning/default/
├── movement.tres      → MovementTuning     (§2)
├── suspicion.tres     → SuspicionTuning    (§3)
├── compass.tres       → CompassTuning      (§4)
├── combat.tres        → CombatTuning       (§5, §6)
├── contract.tres      → ContractTuning     (§7)
├── abilities/*.tres   → AbilityData        (§8)
├── crowd.tres         → CrowdTuning        (§9)
├── match.tres         → MatchTuning        (§10)
├── scoring.tres       → ScoringTuning      (§11)
├── camera.tres        → CameraTuning       (§12)
└── net.tres           → NetTuning          (§13)
```

Field names are the ID with the domain prefix stripped, lowercased, underscored:
`TUN-SUSPICION-DECAY-BASE` → `SuspicionTuning.decay_base`.

The mechanical rules are in [`../30_bible/DATA_SCHEMA.md`](../30_bible/DATA_SCHEMA.md).

### 1.3 The change procedure

1. Change the value **here**, in the same commit as the `.tres` change. Never one without the other.
2. If the new value is outside the stated Range, change the Range too and say why in the Rationale.
3. Append a line to [`../00_meta/DECISION_LOG.md`](../00_meta/DECISION_LOG.md).
4. If the change affects the balance model, update
   [`BALANCE_MODEL.md`](BALANCE_MODEL.md) and re-run its worked examples.
5. Re-run `gut -gtest=test_tuning_ranges.gd`, which asserts every field is inside its Range.

### 1.4 Authority

Values are **server-authoritative**. A client's `TuningProfile` is overwritten by the
server's at match start (`NET-S2C-TUNING-SYNC`). A client with mismatched tunables is
corrected, not kicked — a mismatch is far more likely to be a stale build than an attack,
and kicking makes that diagnosis harder.

---

## 2. Movement and traversal — `SYS-PAWN`, `SYS-TRAVERSAL`

### 2.1 Speed states

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-SPEED-BLENDWALK` | 1.4 | m/s | 1.2–1.6 | Must equal `TUN-CROWD-NPC-SPEED-STROLL` exactly. If a player at blend-walk moves at a different speed from the NPCs around them, they are readable from motion alone and anonymity is dead. |
| `TUN-SPEED-STROLL` | 2.2 | m/s | 1.8–2.6 | The "purposeful civilian" speed. Fast enough that crossing the map is not tedious (120 m ≈ 55 s), slow enough to remain suspicion-free. This is the speed a good player travels at. |
| `TUN-SPEED-JOG` | 3.4 | m/s | 3.0–3.8 | The first speed that costs anonymity. Priced so a short jog is a real option, not a mistake — a player must be able to reposition under mild pressure without falling out of `SCORE-PATIENT`. |
| `TUN-SPEED-RUN` | 4.5 | m/s | 4.0–5.0 | The commitment speed. 32 % faster than jog, and 3.5× the suspicion cost — the ratio is deliberately unfavourable so that running is a decision, not a default. |
| `TUN-SPEED-SPRINT` | 6.2 | m/s | 5.6–6.8 | 4.4× blend-walk. Fast enough to catch a fleeing target across a plaza, expensive enough (`TUN-SUSPICION-GAIN-SPRINT`) that you reach **Exposed** in 2.8 s. Sprinting is a countdown, not a state. |
| `TUN-SPEED-CLIMB` | 2.8 | m/s | 2.4–3.2 | Faster than stroll, so the roofs really are a highway. Combined with `TUN-SUSPICION-GAIN-CLIMB` this is the "roofs are fast but cost anonymity" trade the level design exists to exploit. |
| `TUN-SPEED-ACCEL` | 18.0 | m/s² | 12–26 | Reaches sprint in 0.34 s. High, because input latency must not feel like sluggishness; the *cost* of sprinting is suspicion, not acceleration. |
| `TUN-SPEED-DECEL` | 24.0 | m/s² | 16–34 | Stopping is faster than starting, so that "stop and blend" is instantly available. This asymmetry is the thesis in the acceleration curve. |
| `TUN-SPEED-TURN-RATE-GROUND` | 540 | deg/s | 360–720 | Turning is not throttled by speed state — a player must always be able to look. |
| `TUN-SPEED-RUN-HOLD` | 0.35 | s | 0.2–0.6 | How long `INPUT-RUN` must be held before Jog escalates to Run. Promoted from prose in 02_player_controller.md §2.2; the escalation is a gameplay timing and belongs here like every other. |
| `TUN-SPEED-SPRINT-HOLD` | 0.4 | s | 0.3–0.6 | Sustained-hold threshold for `INPUT-SPRINT`, the alternative to a double-tap. Deliberately awkward (§1.5): sprinting must be a decision, not a lean on the stick. Promoted from prose. |
| `TUN-SPEED-SPRINT-DOUBLETAP` | 0.25 | s | 0.15–0.4 | Maximum gap between the two `INPUT-SPRINT` presses of a double-tap. The other half of §1.5's deliberate friction, and the half that had no number: the GDD says "double-tap" and never said how fast. Short enough that a nervous re-press does not sprint you; long enough to be reachable under pressure. |
| `TUN-SPEED-STICK-DEADZONE` | 0.15 | × | 0.05–0.25 | Below this, the left stick reads as no input at all. Not cosmetic: `wants_movement()` decides `→ Idle`, so a drifting stick would hold a pawn out of the one state where suspicion decays fastest. |
| `TUN-SPEED-STICK-BLENDWALK-MAX` | 0.3 | × | 0.2–0.45 | Left-stick magnitude at or below which a gamepad walks at blend-walk without holding the modifier (§1.3). Promoted from prose; it is the pad's half of the most important key in the game. |
| `TUN-SPEED-TRIGGER-RUN` | 0.75 | × | 0.5–0.95 | Analogue trigger pull above which `INPUT-RUN` reads as *full* rather than partial — GDD-02 §1.3's "partial pull = jog, full pull = run". Below it the pad is held at jog, which is the rung a player can afford. |
| `TUN-SPEED-BACKPEDAL-MULT` | 0.55 | × | 0.4–0.8 | Backing away from a hunter is possible but slow; the correct defensive answer is to blend, not to retreat. |

### 2.2 Traversal

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-TRAVERSE-VAULT-MAX-HEIGHT` | 1.1 | m | 0.9–1.3 | Waist height. Anything a civilian could plausibly hop. Above this it reads as athletic and becomes a climb. |
| `TUN-TRAVERSE-VAULT-DURATION` | 0.55 | s | 0.4–0.7 | Under the `TUN-FEEL-MAX-COMMIT` ceiling, so a vault never feels like a trap. |
| `TUN-TRAVERSE-MANTLE-MAX-HEIGHT` | 2.3 | m | 2.0–2.6 | Reachable ledge. Above this a climb is required. |
| `TUN-TRAVERSE-MANTLE-DURATION` | 0.95 | s | 0.8–1.2 | Long enough to be a visible commitment from 30 m — a mantle is an information event. |
| `TUN-TRAVERSE-CLIMB-MAX-HEIGHT` | 9.0 | m | 6–12 | One stratum transition (street → balcony, balcony → roof) in a single unbroken climb. |
| `TUN-TRAVERSE-DROP-SAFE-HEIGHT` | 4.0 | m | 3–5 | Below this, drop and keep moving. Above this, the drop-swing manoeuvre is required or the landing staggers. |
| `TUN-TRAVERSE-DROP-STAGGER` | 0.8 | s | 0.5–1.2 | The punishment for panicking off a roof. Not a death sentence; a window during which you can be killed. |
| `TUN-TRAVERSE-GAP-MAX` | 3.2 | m | 2.5–4.0 | The furthest jumpable gap. The metrics bible builds all rooftop gaps at 2.0 m (easy), 2.8 m (committed) or 3.6 m (impossible) so a player never has to guess. |
| `TUN-TRAVERSE-MAGNET-WINDOW` | 0.25 | s | 0.15–0.40 | Ledge-grab forgiveness. The player may press traverse up to 0.25 s late and still catch. Forgiveness is mandatory: parkour here is assisted, not simulated, and a missed grab must be a *decision* error, not an *timing* error. |
| `TUN-TRAVERSE-MAGNET-RADIUS` | 0.6 | m | 0.4–0.9 | Lateral snap distance to a ledge. Same reasoning. |
| `TUN-TRAVERSE-PROBE-COUNT` | 3 | count | 3–3 | Chest, waist, foot. Fixed at three; the resolution priority list in [`../10_gdd/02_player_controller.md`](../10_gdd/02_player_controller.md) §7 assumes exactly these. |
| `TUN-TRAVERSE-PROBE-HEIGHT-CHEST` | 1.35 | m | — | Probe origin heights, measured from pawn origin. |
| `TUN-TRAVERSE-PROBE-HEIGHT-WAIST` | 0.85 | m | — | " |
| `TUN-TRAVERSE-PROBE-HEIGHT-FOOT` | 0.25 | m | — | " |
| `TUN-TRAVERSE-PROBE-LENGTH` | 0.9 | m | 0.7–1.2 | Forward reach of each probe. Longer than the pawn's radius so intent is detected before collision. |
| `TUN-TRAVERSE-INPUT-BUFFER` | 0.20 | s | 0.1–0.3 | A traverse input pressed this long before it becomes valid is queued, not dropped. |
| `TUN-TRAVERSE-GAP-ALIGN-ARC` | 20.0 | deg | 10–30 | Half-arc within which a gap jump auto-aligns to the crossing. Promoted from a bare "±20°" in [`../10_gdd/02_player_controller.md`](../10_gdd/02_player_controller.md) §7.3's forgiveness table, which was the one row there with no ID. Wide enough that eyeballing the far side is enough, narrow enough that it never turns you toward a gap you were not crossing. |
| `TUN-TRAVERSE-GAP-PROBE-AHEAD` | 0.6 | m | 0.4–0.9 | How far ahead of the pawn the downward gap probe starts. Promoted from prose in [`../10_gdd/02_player_controller.md`](../10_gdd/02_player_controller.md) §7.1. Far enough to clear the pawn's own 0.35 m radius, close enough that the edge is detected before the pawn is over it. |
| `TUN-TRAVERSE-GAP-PROBE-DEPTH` | 5.0 | m | 3.0–8.0 | How deep the downward probes look. Deeper than `TUN-TRAVERSE-DROP-SAFE-HEIGHT` so a landing that will stagger is still *found* — resolving to a costly drop is a decision the player gets to make; finding nothing is the game refusing to answer. |
| `TUN-TRAVERSE-GAP-PROBE-STEP` | 0.4 | m | 0.2–0.8 | Spacing of the downward probes marching out to `TUN-TRAVERSE-GAP-MAX`. This is the resolution at which a landing edge is found: coarser and a narrow ledge across a gap is missed, finer and it costs raycasts every frame on every pawn. |

### 2.3 Feel budget

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-FEEL-INPUT-TO-ANIM-MAX` | 80 | ms | 50–100 | Hard ceiling on input-to-visible-response, measured locally with prediction. Above ~100 ms players report the character as "floaty" and stop trusting close-range timing — fatal in a game decided at 2.5 m. |
| `TUN-FEEL-MAX-COMMIT` | 1.4 | s | — | No unskippable animation may exceed this. The kill (`TUN-KILL-ANIM-DURATION`) is exactly at the ceiling and is the only thing allowed there. |

---

## 3. Suspicion — `SYS-SUSPICION`

### 3.1 Scale and decay

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-SUSPICION-MAX` | 100.0 | pts | — | Fixed scale. Every source is expressed as a fraction of "fully exposed", which makes tuning arguments comparable. |
| `TUN-SUSPICION-MIN` | 0.0 | pts | — | Clamped floor. |
| `TUN-SUSPICION-DECAY-BASE` | 8.0 | /s | 6–12 | Full 100 → 0 in 12.5 s of civilian behaviour. Long enough that a mistake has consequences you must live with; short enough that a match is not ruined by one bad five seconds. |
| `TUN-SUSPICION-DECAY-SPEED-CEILING` | 2.2 | m/s | — | Decay applies only at or below this speed — i.e. Idle, blend-walk and stroll. Equals `TUN-SPEED-STROLL`. This single threshold *is* the game's thesis: below it you recover, above it you spend. (ASM-0008) |
| `TUN-SUSPICION-DECAY-DELAY` | 0.6 | s | 0.3–1.2 | Grace period after the last gain before decay resumes. Prevents a player from tapping sprint repeatedly and paying almost nothing. |

### 3.2 Continuous sources

Applied per tick while the condition holds. Additive (ASM-0018).

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-SUSPICION-GAIN-SPRINT` | 25.0 | /s | 20–32 | **Noticed** in 1.2 s, **Exposed** in 2.8 s. Sprinting is a 3-second budget, not a movement mode. This is the single most important number in the game. |
| `TUN-SUSPICION-GAIN-RUN` | 14.0 | /s | 10–18 | **Noticed** in 2.1 s. Run is the "I need to be somewhere" speed: usable for a street's length, not a plaza's. (ASM-0007) |
| `TUN-SUSPICION-GAIN-JOG` | 4.0 | /s | 2–7 | **Noticed** in 7.5 s. Deliberately cheap: `SCORE-PATIENT` permits jog, so a patient player must be able to jog meaningfully without becoming visible. (ASM-0007) |
| `TUN-SUSPICION-GAIN-ROOF` | 18.0 | /s | 14–24 | Being on the rooftop stratum at all, regardless of speed. **Noticed** in 1.7 s. Roofs are fast and empty; a civilian is never up there. This is what stops the roofs from being strictly better. |
| `TUN-SUSPICION-GAIN-CLIMB` | 12.0 | /s | 8–16 | While actively climbing. Lower than roof-presence because a climb is brief and sometimes necessary; the roof you arrive at is what really costs. |
| `TUN-SUSPICION-GAIN-OPEN` | 6.0 | /s | 4–9 | While no NPC is within `TUN-SUSPICION-OPEN-RADIUS`. **Noticed** in 5 s of standing alone. The mechanic that makes an empty plaza a danger zone and makes crowd-seeking a constant background pressure. |
| `TUN-SUSPICION-OPEN-RADIUS` | 6.0 | m | 4–9 | "Alone" means no NPC within this radius. Tuned against the crowd-pocket module spacing so that the designed pockets reliably suppress it and the designed empty spaces reliably do not. |
| `TUN-SUSPICION-GAIN-WHISPERBOLT-WINDUP` | — | — | — | Not a gain — `ABIL-WHISPERBOLT` **forces** the Exposed tier for its wind-up. See §8.2. |

### 3.3 Instant sources (impulses)

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-SUSPICION-GAIN-NPC-BUMP` | 15.0 | pts | 10–22 | Half the way to Noticed for one collision. Bumping is how a careless player betrays themselves in a crowd, and it is also what makes moving *through* a dense pocket a skill rather than a shortcut. |
| `TUN-SUSPICION-GAIN-NPC-BUMP-COOLDOWN` | 0.8 | s | 0.5–1.5 | Minimum interval between bump impulses, so one bad shove into a group is not five stacked charges. |
| `TUN-SUSPICION-GAIN-LOUD-ABILITY` | 40.0 | pts | 30–50 | Applied by `ABIL-CINDERFALL` and `ABIL-LUNGE`. From Anonymous, one loud ability puts you at 40 — **Noticed** immediately, and 5 s of walking to clear. Loud abilities cost your cover, which is exactly the trade they are for. |
| `TUN-SUSPICION-GAIN-FAILED-KILL` | 30.0 | pts | 20–40 | A whiffed or interrupted kill. You lunged at someone and it did not land: everyone watching now knows what you are. |
| `TUN-SUSPICION-GAIN-WITNESSED-KILL` | 25.0 | pts | 15–35 | Applied to the *killer* if any other **player** had line of sight at the moment of initiation. The reason a kill in a theatre space is riskier than a kill in an alley — and the mechanic that makes theatre spaces matter. |

### 3.4 Tiers

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-SUSPICION-TIER-NOTICED` | 30.0 | pts | 25–40 | Entry to **Noticed**. At 30, the player who holds you as a contract sees a faint tint on you. Set at 30 % so that a single instant impulse (bump, 15) does not cross it from zero, but two do. |
| `TUN-SUSPICION-TIER-EXPOSED` | 70.0 | pts | 60–80 | Entry to **Exposed**. Hard silhouette to your pursuer, free Compass lock, and your prey is warned. 70 is reachable from Anonymous by ~2.8 s of sprinting or one loud ability plus one bump plus a second of running. |
| `TUN-SUSPICION-HYSTERESIS` | 5.0 | pts | 3–10 | A tier is exited 5 points below the threshold that entered it. Prevents strobing at the boundary. A flickering tint is not merely ugly — it is an unreliable information channel, and the game is made of information channels. (ASM-0009) |

### 3.5 Blend actions — `SYS-BLEND`

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-BLEND-CRUSH-TIME` | 1.2 | s | 0.8–2.0 | Time from blend entry to suspicion 0, linear from the current value. Long enough that you cannot blend *during* a chase to erase it; short enough that pre-emptive blending is reliably rewarded. |
| `TUN-BLEND-ENTRY-TIME` | 0.35 | s | 0.2–0.6 | Time to physically enter the blend (sit, step into the group, climb into the cart). You are vulnerable and visibly transitioning during it. |
| `TUN-BLEND-EXIT-TIME` | 0.30 | s | 0.2–0.5 | Time to leave. Slightly shorter than entry: escaping a blend under threat must not feel like a trap. |
| `TUN-BLEND-GROUP-JOIN-RADIUS` | 2.5 | m | 2.0–3.5 | How close you must be to a walking group to join it. Matches `TUN-KILL-RANGE` deliberately — the distance at which you can join a group is the distance at which you can be killed in it. |
| `TUN-BLEND-GROUP-SLOT-TOLERANCE` | 0.8 | m | 0.5–1.2 | How far you may drift from your formation slot before the blend breaks. |
| `TUN-BLEND-POCKET-MIN-NPC` | 4 | count | 3–6 | Minimum NPCs within `TUN-BLEND-POCKET-RADIUS` for a standing blend to be valid. Four is the smallest number that reads as "a group" rather than "some people". |
| `TUN-BLEND-POCKET-RADIUS` | 3.5 | m | 2.5–5.0 | The radius in which those NPCs must stand. |
| `TUN-BLEND-BREAK-ON-DAMAGE` | true | bool | — | Being hit or stunned always breaks a blend. |
| `TUN-BLEND-BREAK-ON-SPEED` | 2.2 | m/s | — | Exceeding stroll breaks any blend. Equals `TUN-SPEED-STROLL`. |
| `TUN-BLEND-PROP-CAPACITY` | 1 | count | 1–2 | Players per concealment prop (hay cart, well, wardrobe). One, so that a prop is a *claimable* resource and a second player arriving is a real problem. |
| `TUN-BLEND-PROP-EXIT-VULN` | 0.5 | s | 0.3–0.8 | Window after leaving a prop during which you cannot re-enter it. Prevents door-flickering to dodge a kill. |
| `TUN-BLEND-SCORE-GRACE` | 1.0 | s | 0.5–1.5 | You may initiate a kill up to 1.0 s after leaving a blend and still earn `SCORE-BLENDED`. This is what makes the blend-then-strike play legible and reliable rather than frame-perfect. |

---

## 4. The Compass — `SYS-COMPASS`

### 4.1 Range and pulse

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-COMPASS-RANGE-MAX` | 60.0 | m | 45–80 | Half the map's width. Beyond this the Compass shows the slowest pulse and no more; the contract is "somewhere over there". 60 m guarantees that on a 120 m map you are almost never *without* signal, so the hunt never stalls. |
| `TUN-COMPASS-PULSE-MAX` | 0.90 | s | 0.7–1.2 | Pulse period at maximum range. Slow enough to be background, present enough to be felt. |
| `TUN-COMPASS-PULSE-MIN` | 0.15 | s | 0.10–0.25 | Pulse period at zero distance. 6.7 Hz — fast enough to read as urgency rather than rhythm. This is the sound of the last three metres. |
| `TUN-COMPASS-PULSE-EXP` | 2.2 | × | 1.6–3.0 | Curve shape. See §4.2 for the formula and the sampled table. (ASM-0011) |

### 4.2 The distance → pulse curve

```
normalised   t      = clamp(distance / TUN-COMPASS-RANGE-MAX, 0.0, 1.0)
pulse period p(d)   = TUN-COMPASS-PULSE-MIN
                    + (TUN-COMPASS-PULSE-MAX - TUN-COMPASS-PULSE-MIN)
                    * pow(t, 1.0 / TUN-COMPASS-PULSE-EXP)
pulse rate          = 1.0 / p(d)
```

The reciprocal exponent is the point: `pow(t, 1/2.2)` is **flat far away and steep close in**,
which is the requested ease-in. Sampled:

| Distance (m) | Period (s) | Rate (Hz) | Change in rate vs. previous row |
|---|---|---|---|
| 60 | 0.900 | 1.11 | — |
| 50 | 0.840 | 1.19 | +7 % |
| 40 | 0.774 | 1.29 | +8 % |
| 30 | 0.697 | 1.43 | +11 % |
| 25 | 0.654 | 1.53 | +7 % |
| 20 | 0.605 | 1.65 | +8 % |
| 15 | 0.549 | 1.82 | +10 % |
| 10 | 0.482 | 2.07 | +14 % |
| 5 | 0.392 | 2.55 | +23 % |
| 2 | 0.310 | 3.23 | +27 % |
| 1 | 0.267 | 3.75 | +16 % |
| 0 | 0.150 | 6.67 | +78 % |

**Read the right-hand column.** From 60 m to 20 m the rate creeps up by about 8 % per
10 m — you can feel it, but slowly. Inside 10 m each step adds 15–25 %, and the final
approach nearly doubles it. The rate at 15 m (1.82 Hz) is 41 % faster than at 40 m
(1.29 Hz); the rate at 1 m is **triple** the rate at 40 m. That asymmetry is the whole
design requirement, expressed as a curve.

### 4.3 Direction cone

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-COMPASS-CONE-HALFWIDTH` | 12.0 | deg | 8–20 | The rendered arc's half-width. ±12° at 30 m is ±6 m of positional ambiguity — about one market stall. It tells you *which part of the plaza*, never *which body*. (ASM-0012) |
| `TUN-COMPASS-CONE-WOBBLE` | 4.0 | deg | 0–8 | Deterministic slow drift of the cone's centre, seeded per contract so it is a stable property of this hunt rather than a per-frame lie. |
| `TUN-COMPASS-CONE-WOBBLE-PERIOD` | 3.1 | s | 2–6 | Wobble period. Non-integer and prime-ish so it does not visibly sync with the pulse. |
| `TUN-COMPASS-UPDATE-RATE` | 30 | Hz | — | Matches the server tick. The Compass never contains information newer than the simulation. |

### 4.4 Lock

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-COMPASS-LOCK-CONE` | 25.0 | deg | 18–35 | Total facing cone (±12.5°) within which the contract must sit for the lock arc to fill. Narrow: locking is *aiming your attention*, and you cannot do it while scanning. |
| `TUN-COMPASS-LOCK-RANGE` | 20.0 | m | 15–28 | Maximum lock distance. Inside a third of Compass range, so a lock always means "I am in the same space as them". |
| `TUN-COMPASS-LOCK-FILL-TIME` | 1.6 | s | 1.0–2.5 | Time to fill the arc with an unbroken view. Deliberately longer than one NPC stride cycle, so incidental gaps in a walking group cannot complete a lock — you need a genuinely clear line. (ASM-0013) |
| `TUN-COMPASS-LOCK-DECAY-RATE` | 1.4 | × | 1.0–3.0 | Multiplier on the rate at which a partial lock drains when the conditions break. 1.4× means a broken lock is lost faster than it was gained, so peeking repeatedly is worse than committing once. |
| `TUN-COMPASS-LOCK-REQUIRES-LOS` | true | bool | — | Line of sight is mandatory, evaluated server-side. Never trust the client's view. |
| `TUN-COMPASS-REVEAL-DURATION` | 1.5 | s | 1.0–2.5 | How long a completed lock highlights the contract's silhouette. Long enough to start moving toward them; short enough that you must re-acquire, so a lock is not a permanent tag. |
| `TUN-COMPASS-REVEAL-COOLDOWN` | 4.0 | s | 2–8 | Minimum interval between reveals on the same contract, so a hunter cannot chain-lock a target into permanent visibility. |

### 4.5 The prey warning

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-COMPASS-WARN-RADIUS` | 15.0 | m | 10–22 | Your Compass flashes red when your **pursuer** is within this radius *and* at least **Noticed**. This is the prey's only warning and the reason recklessness is self-defeating. |
| `TUN-COMPASS-WARN-MIN-TIER` | 30.0 | pts | — | The tier threshold that triggers the warning. Equals `TUN-SUSPICION-TIER-NOTICED`. An **Anonymous** pursuer produces no warning at any distance — patience really does buy invisibility. |
| `TUN-COMPASS-WARN-DURATION` | 1.2 | s | 0.8–2.0 | How long the flash and audio sting persist after the condition ends. |
| `TUN-COMPASS-WARN-COOLDOWN` | 2.5 | s | 1.5–5.0 | Re-trigger interval, so a pursuer hovering at the tier boundary does not produce a strobe. |
| `TUN-COMPASS-WARN-GIVES-DIRECTION` | false | bool | — | **The warning is directionless.** You learn *that* you are hunted, never *from where*. Making it directional would convert the game's best moment — the panicked scan of a crowd — into a lookup. |

---

## 5. The kill — `SYS-KILL`

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-KILL-RANGE` | 2.5 | m | 2.0–3.2 | Conversational distance. You must be close enough that standing there is itself a commitment, and close enough that the victim could have looked at you. |
| `TUN-KILL-FACING-CONE` | 60.0 | deg | 45–90 | Total cone (±30°) the killer must face within. Generous enough that camera wobble does not eat a kill; tight enough that you cannot kill someone beside you. The victim's facing is **irrelevant** — killing someone facing away from you is the intended patient play. (ASM-0010) |
| `TUN-KILL-ANIM-DURATION` | 1.4 | s | 1.2–1.8 | The committed animation. The killer is fully visible and cannot act. This is the price of every kill and the reason a kill in the open is a bad idea even when it works. Sits exactly at `TUN-FEEL-MAX-COMMIT`. |
| `TUN-KILL-ANIM-CANCEL-WINDOW` | 0.0 | s | — | Zero. There is no cancel. Commitment is the mechanic. |
| `TUN-KILL-VALIDATION-GRACE` | 0.35 | m | 0.2–0.6 | Server-side range tolerance on top of `TUN-KILL-RANGE`, applied after lag-compensated rewind. Absorbs residual netcode error so a legitimate kill is not denied by 4 cm. |
| `TUN-KILL-CONTEST-WINDOW` | 0.4 | s | 0.25–0.6 | Two initiations on the same victim inside this window are contested; the earlier **server** timestamp wins. |
| `TUN-KILL-CONTEST-STAGGER` | 1.5 | s | 1.0–2.5 | The loser of a contest is staggered. Not stunned: no points to anyone, no lockout. Losing a race should cost tempo, not the match. |
| `TUN-KILL-INVALID-TARGET-PENALTY` | true | bool | — | Pressing kill on a valid-range non-contract player applies `TUN-SUSPICION-GAIN-FAILED-KILL` and plays the whiff animation. You cannot safely test whether a stranger is your contract. |
| `TUN-KILL-CORPSE-SPAWN-DELAY` | 0.9 | s | — | Point within the kill animation at which the corpse and its `SYS-CORPSE` information object appear. Aligned to the animation's contact frame. |

---

## 6. Stun — `SYS-STUN`

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-STUN-RANGE` | 3.0 | m | 2.5–4.0 | Slightly longer than `TUN-KILL-RANGE`. Deliberate: the prey's reach must exceed the hunter's, so a hunter who closes to kill range has already entered stun range. Recklessness is punished by geometry before it is punished by scoring. |
| `TUN-STUN-FACING-CONE` | 120.0 | deg | 90–180 | Wide (±60°). You are turning in panic; the game must not require precision from a player who has just been startled. |
| `TUN-STUN-MIN-TIER` | 30.0 | pts | — | The pursuer must be at least **Noticed**. Equals `TUN-SUSPICION-TIER-NOTICED`. An Anonymous hunter cannot be stunned — patience is genuinely safe, which is the whole point. |
| `TUN-STUN-FREEZE` | 4.0 | s | 3.0–6.0 | The hunter is frozen and helpless. Four seconds is long enough to walk away, blend, and be gone. It must feel catastrophic. |
| `TUN-STUN-LOCKOUT` | 12.0 | s | 8–18 | The stunned hunter cannot re-initiate on that specific target for this long. Without it, stun merely delays the kill by four seconds and is not counterplay at all. |
| `TUN-STUN-FORCES-EXPOSED` | true | bool | — | The stunned hunter is set to `TUN-SUSPICION-MAX` and held at **Exposed** for `TUN-STUN-FREEZE`. Everyone nearby now knows what they are. |
| `TUN-STUN-SCORE` | 100 | pts | 75–150 | Equal to `SCORE-CONTRACT`. Successfully defending yourself is worth exactly as much as a base kill — the statement that defence is a scoring strategy, not a survival tax. |
| `TUN-STUN-ANIM-DURATION` | 0.7 | s | 0.5–1.0 | The stunner's own commitment. Half the kill animation: defence is faster than offence. |
| `TUN-STUN-INVALID-STAGGER` | 2.0 | s | 1.5–3.5 | Stunning a non-pursuer: zero points and this stagger. Longer than `TUN-STUN-ANIM-DURATION` so flailing is strictly worse than doing nothing. |
| `TUN-STUN-INVALID-SUSPICION` | 20.0 | pts | 10–30 | And you look ridiculous doing it. Stops "stun everyone who comes near" from being free. |
| `TUN-STUN-COOLDOWN` | 3.0 | s | 2–6 | Minimum interval between stun attempts by the same player. Anti-spam backstop. |
| `TUN-STUN-VS-LUNGE-WINDOW` | true | bool | — | A player mid-`ABIL-LUNGE` is stunnable for the entire dash. The dash is loud and telegraphed; it must lose to a prepared defender. |

---

## 7. Contracts and respawn — `SYS-CONTRACT`, `SYS-SPAWN`

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-CONTRACT-REASSIGN-DELAY` | 3.0 | s | 2–5 | After a successful kill, the delay before a new contract is issued. A breath: it converts a kill from a link in a chain into a moment. Also covers the kill animation's tail. |
| `TUN-CONTRACT-ANTI-REPEAT-DEPTH` | 1 | count | 1–3 | The reassignment algorithm avoids handing you the same contract you just had, to this depth of history, *where a valid alternative exists*. Prevents the two-player death spiral. |
| `TUN-CONTRACT-MIN-CYCLE-LENGTH` | 3 | count | — | Below three living players the cycle degenerates to a mutual duel. At 2 players the game issues mutual contracts and flags the match as degenerate in telemetry. |
| `TUN-CONTRACT-REPAIR-DEBOUNCE` | 0.25 | s | 0.1–0.5 | Multiple deaths/disconnects within this window are repaired in one pass, so a double kill does not produce two conflicting cycle rebuilds. |
| `TUN-RESPAWN-DELAY` | 5.0 | s | 3–8 | Long enough to punish death, short enough not to bench a player. On an 8-minute clock, five deaths costs 25 s — noticeable, not ruinous. |
| `TUN-RESPAWN-MIN-DIST-FROM-KILLER` | 40.0 | m | 25–60 | One third of the map diagonal. Far enough that instant revenge is not the default; near enough that the map does not feel teleported through. Falls back to the farthest available point if unsatisfiable — a spawn system that can fail is a crash waiting for a playtest. (ASM-0014) |
| `TUN-RESPAWN-MIN-DIST-FROM-ANY-PLAYER` | 12.0 | m | 8–20 | Secondary constraint: never spawn inside someone's kill range. |
| `TUN-RESPAWN-INVULN` | 1.0 | s | 0.5–2.0 | Brief spawn protection. Just enough to orient. Long enough to be abusable would be worse than none. |
| `TUN-RESPAWN-SUSPICION` | 0.0 | pts | — | You respawn Anonymous. Death wipes the slate; the punishment is the 5 s and the lost streak, not a lingering handicap. |
| `TUN-SPAWN-POINT-COUNT` | 6 | count | 6–8 | One per player at maximum count, so a full simultaneous respawn is always satisfiable. |

---

## 8. Abilities — `SYS-ABILITY`

Shared rules first, then per ability. Cooldowns are authoritative on the server and start at
**activation**, not at effect end.

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-ABILITY-SLOTS-ACTIVE` | 2 | count | 2–2 | Two actives. Fixed for MVP: three would make loadout reading (a core skill) too high-dimensional to learn in one session. |
| `TUN-ABILITY-SLOTS-PASSIVE` | 1 | count | 1–1 | One passive. |
| `TUN-ABILITY-LOCK-AT-MATCH-START` | true | bool | — | Loadouts are immutable for the match, including across deaths, so kit knowledge is durable. (ASM-0015) |
| `TUN-ABILITY-GLOBAL-COOLDOWN` | 0.5 | s | 0.3–1.0 | Minimum interval between any two ability activations. Prevents ability-chaining combos that no victim can read. |
| `TUN-ABILITY-INPUT-BUFFER` | 0.20 | s | 0.1–0.3 | Ability input pressed this long before it becomes legal is queued. |

### 8.1 `ABIL-CINDERFALL` — area denial

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-CINDERFALL-COOLDOWN` | 45.0 | s | 35–60 | Roughly once per 90-second hunt cycle. It is an escape, not a tool. |
| `TUN-CINDERFALL-CAST-TIME` | 0.45 | s | 0.3–0.7 | The wind-and-throw. Short enough to be a panic button, long enough to be a visible tell. |
| `TUN-CINDERFALL-THROW-RANGE` | 8.0 | m | 5–12 | You may place it ahead of you or at your feet. Placing it ahead is the aggressive use (deny a chaser's line); at your feet is the escape. |
| `TUN-CINDERFALL-RADIUS` | 5.0 | m | 4–7 | Twice `TUN-KILL-RANGE`. Covers a doorway or an alley mouth, not a plaza. |
| `TUN-CINDERFALL-DURATION` | 4.0 | s | 3–6 | Long enough to break a lock (`TUN-COMPASS-LOCK-FILL-TIME` is 1.6 s) and leave; short enough that it cannot be used to camp a corner. |
| `TUN-CINDERFALL-BLOCKS-LOS` | true | bool | — | Blocks line of sight for detection, Compass lock, and `SCORE-FOCUS` accumulation. |
| `TUN-CINDERFALL-BLOCKS-KILL` | true | bool | — | No kill may be *initiated* inside the radius, by anyone, including the caster. A kill already in progress completes. Otherwise it becomes an offensive tool for forcing blind kills. |
| `TUN-CINDERFALL-SUSPICION` | 40.0 | pts | — | Equals `TUN-SUSPICION-GAIN-LOUD-ABILITY`. |
| `TUN-CINDERFALL-STARTLE-RADIUS` | 9.0 | m | 6–14 | NPCs within this radius **Startle**. The cloud hides you and simultaneously paints a fleeing-crowd arrow at your position for everyone in the district. This is the ability's honest cost. |
| `TUN-CINDERFALL-TELL-AUDIO-RADIUS` | 25.0 | m | 18–35 | The crack is audible this far. Promoted from prose in 04_abilities.md § Tell; the audio tell channel must be a tunable like every other number, because design law 3 is enforced by the schema. |

### 8.2 `ABIL-WHISPERBOLT` — thrown blade

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-WHISPERBOLT-COOLDOWN` | 40.0 | s | 30–55 | Slightly shorter than Cinderfall: it is a kill tool with a much higher failure rate. |
| `TUN-WHISPERBOLT-WINDUP` | 1.0 | s | 0.8–1.4 | The whole balance of the ability. One full second during which you are forced **Exposed** and visibly winding up — enough for an alert target to break line of sight or close and stun. |
| `TUN-WHISPERBOLT-RANGE-MIN` | 3.0 | m | 2.5–4.0 | Just outside `TUN-KILL-RANGE`. You cannot use it as a free melee kill. |
| `TUN-WHISPERBOLT-RANGE-MAX` | 12.0 | m | 9–16 | Long enough to reach a rooftop camper from the street below; short enough that it is not a sniping tool. |
| `TUN-WHISPERBOLT-PROJECTILE-SPEED` | 22.0 | m/s | 16–30 | 0.55 s of flight at maximum range — the target has a real, if small, dodge window after release. |
| `TUN-WHISPERBOLT-FORCES-EXPOSED` | true | bool | — | For the full wind-up plus `TUN-WHISPERBOLT-EXPOSED-TAIL`. This is the tell. |
| `TUN-WHISPERBOLT-EXPOSED-TAIL` | 1.5 | s | 1.0–2.5 | Exposed persists after release, hit or miss. You threw a knife in a market; people noticed. |
| `TUN-WHISPERBOLT-SUSPICION-ON-MISS` | 30.0 | pts | — | Equals `TUN-SUSPICION-GAIN-FAILED-KILL`. A miss is a failed kill. |
| `TUN-WHISPERBOLT-REQUIRES-LOS` | true | bool | — | Server-validated at release *and* at impact against the lag-compensated world. |
| `TUN-WHISPERBOLT-TELL-AUDIO-RADIUS` | 30.0 | m | 25–40 | THE LOUDEST TELL IN THE GAME, and the entire balance of the ability. 2.5x Whisperbolt's own 12 m reach, so everyone who could plausibly be the target hears the draw. |

### 8.3 `ABIL-SECONDFACE` — disguise

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-SECONDFACE-COOLDOWN` | 60.0 | s | 45–90 | The longest cooldown in the set. It is the strongest ability, because it attacks the one thing the whole game is built on: identity. |
| `TUN-SECONDFACE-CAST-TIME` | 0.8 | s | 0.6–1.2 | A visible transition — the tell is a brief silhouette morph, readable at 20 m by anyone watching. |
| `TUN-SECONDFACE-DURATION` | 15.0 | s | 10–22 | Two full Compass hunt cycles. Long enough to cross a plaza and set up; short enough that you cannot wear it as armour. |
| `TUN-SECONDFACE-BREAK-SPEED` | 6.2 | m/s | — | Sprinting breaks it. Equals `TUN-SPEED-SPRINT`. You may run; you may not sprint. |
| `TUN-SECONDFACE-BREAK-ON-HIT` | true | bool | — | Any stun, stagger or kill-attempt against you breaks it. |
| `TUN-SECONDFACE-BREAK-ON-KILL` | true | bool | — | Breaks *after* the kill resolves, so `SCORE-MASKED` still applies. You get paid for the disguised kill, and then everyone sees who you are. |
| `TUN-SECONDFACE-SUSPICION` | 10.0 | pts | 5–20 | Cheap but not free. It is a quiet ability; the cost is the cooldown, not the noise. |
| `TUN-SECONDFACE-PERSONA-SOURCE` | nearest_clone | enum | — | You adopt the persona of the nearest visible NPC clone, not a free choice. Ties the ability to reading the crowd, which is why it exists. Falls back to a random other persona if no clone is visible. |
| `TUN-SECONDFACE-BREAK-TELL-DURATION` | 0.6 | s | 0.4–1.0 | The un-morph is as visible as the morph. Being unmasked in a crowd is an event other players can see. |
| `TUN-SECONDFACE-TELL-AUDIO-RADIUS` | 8.0 | m | 5–12 | A soft cloth rush — deliberately the quietest ability tell, because Second Face's cost is paid in its visual morph. Promoted from prose. |

### 8.4 `ABIL-LUNGE` — committed dash

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-LUNGE-COOLDOWN` | 30.0 | s | 20–45 | The shortest cooldown. It is the weakest ability by expected value and the strongest by desperation value. |
| `TUN-LUNGE-DISTANCE` | 6.0 | m | 4–8 | 2.4× `TUN-KILL-RANGE`. Closes the "they saw me and turned" gap and nothing more. |
| `TUN-LUNGE-SPEED` | 9.0 | m/s | 7–12 | 0.67 s of travel. Faster than sprint, so it genuinely closes; slow enough that a prepared defender can stun it. |
| `TUN-LUNGE-WINDUP` | 0.25 | s | 0.15–0.4 | Short, but present, and audible. The tell. |
| `TUN-LUNGE-STUNNABLE` | true | bool | — | For the entire wind-up and dash. The dash is loud and telegraphed; it must lose to a prepared defender. This is `TUN-STUN-VS-LUNGE-WINDOW`. |
| `TUN-LUNGE-SUSPICION` | 40.0 | pts | — | Equals `TUN-SUSPICION-GAIN-LOUD-ABILITY`. You are Noticed the instant you press it, and if the kill lands you take `SCORE-RECKLESS` unless you were near-clean beforehand. |
| `TUN-LUNGE-AUTO-KILL` | true | bool | — | If the dash ends within `TUN-KILL-RANGE` and cone of the contract, the kill auto-initiates. It is one button, not two, because it is the panic button. |
| `TUN-LUNGE-WHIFF-STAGGER` | 1.2 | s | 0.8–2.0 | Missing leaves you standing in the open, Noticed, unable to act. |
| `TUN-LUNGE-STARTLE-RADIUS` | 7.0 | m | 5–10 | NPCs scatter from the dash path. You have drawn an arrow to yourself. |
| `TUN-LUNGE-TELL-AUDIO-RADIUS` | 20.0 | m | 14–28 | The shout and footfall carry this far. Promoted from prose. |

### 8.5 Passives

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-PASV-STILLNESS-MULT` | 1.40 | × | 1.2–1.8 | `PASV-STILLNESS`: suspicion decay is 40 % faster while stationary (11.2/s). Full 100 → 0 in 8.9 s instead of 12.5 s. The passive for a player who commits to the thesis. |
| `TUN-PASV-STILLNESS-SPEED-CEILING` | 0.15 | m/s | 0.0–0.5 | "Stationary" means below this. Non-zero so that micro-drift from a walking-group slot does not disable it. |
| `TUN-PASV-COLDREAD-MULT` | 1.30 | × | 1.15–1.6 | `PASV-COLDREAD`: lock arc fills 30 % faster (1.23 s instead of 1.6 s). The offensive passive. |
| `TUN-PASV-SECONDWIND-REDUCTION` | 4.0 | s | 2–6 | `PASV-SECONDWIND`: `TUN-STUN-LOCKOUT` drops from 12 s to 8 s for this player. Explicitly does **not** reduce `TUN-STUN-FREEZE` — being stunned must always be catastrophic in the moment; the passive only shortens the exile afterwards. |

---

## 9. Crowd — `SYS-CROWD`, `SYS-NPC-AI`

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-CROWD-COUNT-MIN` | 60 | count | 60–60 | Absolute floor. Below 60 on a 120 × 120 m map the district reads as abandoned and `TUN-SUSPICION-GAIN-OPEN` applies almost everywhere, which turns the game into a shooter. |
| `TUN-CROWD-COUNT-MAX` | 90 | count | 90–90 | Absolute ceiling, set by `TUN-PERF-CROWD-BUDGET`. |
| `TUN-CROWD-COUNT-DEFAULT-6P` | 78 | count | 66–90 | The 6-player default. Chosen as 48 clones (4 personas × 12) + 30 filler. |
| `TUN-CROWD-COUNT-DEFAULT-4P` | 66 | count | 60–78 | The 4-player default: 40 clones (4 × 10) + 26 filler. Fewer players need fewer clones for the same per-player anonymity, and the saved budget goes to frame time. See [`../10_gdd/07_balance.md`](../10_gdd/07_balance.md) §7. |
| `TUN-CROWD-COUNT-DEFAULT-5P` | 72 | count | 63–84 | The 5-player default: 44 clones (4 × 11) + 28 filler. Interpolates the 4P and 6P rows; defined explicitly rather than derived so the 5-player crowd is reviewable in this table like every other number. |
| `TUN-CROWD-CLONES-PER-PERSONA-MIN` | 8 | count | 8–8 | Below 8, a persona's clone population can be locally depleted (all on the far side of the map) and the player wearing it becomes unique. |
| `TUN-CROWD-CLONES-PER-PERSONA-MAX` | 12 | count | 12–12 | Above 12 the crowd starts reading as a police lineup of repeats rather than a city. |
| `TUN-CROWD-CLONE-LOCAL-MIN` | 2 | count | 1–4 | The crowd director maintains at least this many clones of each *in-use* persona within 25 m of each player. Without this rule the statistical guarantee above fails locally, which is where it matters. |
| `TUN-CROWD-DIRECTOR-INTERVAL` | 2.0 | s | 1–5 | How often the crowd director rebalances clone distribution. Slow, because visible re-routing is itself an information leak. |
| `TUN-CROWD-NPC-SPEED-STROLL` | 1.4 | m/s | — | Must equal `TUN-SPEED-BLENDWALK`. |
| `TUN-CROWD-NPC-SPEED-FLEE` | 5.0 | m/s | 4–6 | Startle speed. Below `TUN-SPEED-SPRINT`, so a sprinting player cannot hide inside a startle wave. |
| `TUN-CROWD-GROUP-SIZE` | 4 | count | 3–6 | Walking-group size. Four is the minimum that reads as a group and leaves a joinable slot. |
| `TUN-CROWD-GROUP-COUNT` | 4 | count | 3–6 | Number of walking-group circuits on `MAP-VETRAIO`. |
| `TUN-CROWD-GROUP-SPACING` | 1.3 | m | 1.0–2.0 | Formation slot spacing. Loose enough for a player to slot in without collision-shoving. |
| `TUN-CROWD-IDLE-GROUP-SIZE-MIN` | 2 | count | 2–2 | Conversation clusters. |
| `TUN-CROWD-IDLE-GROUP-SIZE-MAX` | 4 | count | 4–6 | " |
| `TUN-CROWD-STARTLE-DURATION` | 4.0 | s | 3–6 | How long a startled NPC flees. Long enough that the wave is visible from across a plaza — a startle is a public announcement. |
| `TUN-CROWD-STARTLE-RADIUS-VIOLENCE` | 12.0 | m | 8–18 | Startle radius for a kill or stun. |
| `TUN-CROWD-STARTLE-RADIUS-SPRINT` | 5.0 | m | 3–8 | Startle radius for a sprinting player brushing past. Smaller: it is a ripple, not a wave, but it still marks your path. |
| `TUN-CROWD-STARTLE-PROPAGATION` | 0.4 | × | 0.0–0.7 | A startled NPC startles others within `TUN-CROWD-STARTLE-RADIUS-SPRINT` with this probability, once. Produces a decaying wave rather than a hard-edged circle, which reads as organic and — more usefully — gives the wave a *direction* a distant player can read. |
| `TUN-CROWD-GAWK-DURATION` | 6.0 | s | 4–10 | How long NPCs crowd a corpse. Shorter than `TUN-CORPSE-LIFETIME` so the crowd disperses before the body does, giving two distinct phases of information. |
| `TUN-CROWD-GAWK-RADIUS` | 10.0 | m | 6–15 | Recruitment radius for gawkers. |
| `TUN-CROWD-GAWK-MAX` | 6 | count | 4–10 | Cap on gawkers, so a corpse in a dense pocket does not depopulate the pocket — which would perversely make a kill site *safer* to stand in. |
| `TUN-CORPSE-LIFETIME` | 20.0 | s | 12–30 | How long a corpse persists. It is a deliberate information object: it says "someone died here, recently, and their killer was here 20 seconds ago". |
| `TUN-CORPSE-FADE-TIME` | 1.5 | s | — | Visual dissolve at end of life. |
| `TUN-CROWD-BUMP-PUSH` | 1.2 | m/s | 0.8–2.0 | Impulse applied to an NPC a player collides with. Enough to be visible to onlookers — a bump is an information event, not just a suspicion charge. |

---

## 10. Match flow — `SYS-MATCH`

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-LOBBY-MIN-PLAYERS` | 4 | count | 4–4 | Below 4 the contract cycle degenerates (see `TUN-CONTRACT-MIN-CYCLE-LENGTH`). |
| `TUN-LOBBY-MAX-PLAYERS` | 6 | count | 6–6 | The design centre. See ASM-0006. |
| `TUN-LOBBY-COUNTDOWN` | 5.0 | s | 3–10 | From all-ready to match start. Long enough to cancel a misclick, short enough not to be dead air. |
| `TUN-MATCH-DURATION` | 480.0 | s | 420–600 | Eight minutes. Long enough for ~5 hunt cycles per player and for a comeback; short enough that a bad match is cheap and a queue is worth rejoining. |
| `TUN-MATCH-FINALPHASE-DURATION` | 30.0 | s | 20–60 | The **Final Contract** phase. Short and loud. |
| `TUN-MATCH-FINALPHASE-MULT` | 2.0 | × | 1.5–3.0 | Score multiplier during the final phase. 2× makes one good final kill (up to ~1200 pts) able to overturn a moderate deficit, without making the preceding 7:30 irrelevant. Derived in [`BALANCE_MODEL.md`](BALANCE_MODEL.md) §6. |
| `TUN-MATCH-FINALPHASE-WARNING` | 5.0 | s | 3–10 | Warning before the final phase begins, so players can position rather than be ambushed by a rule change. |
| `TUN-MATCH-RESULTS-DURATION` | 25.0 | s | 15–45 | Results screen before returning to lobby. Long enough to read your own bonus breakdown — which is the game's primary teaching moment — and skippable by unanimous input. |
| `TUN-MATCH-TICK-RATE` | 30 | Hz | — | The authority clock for all gameplay. Equals `TUN-NET-SERVER-TICK`. (ASM-0020) |

---

## 11. Scoring — `SYS-SCORE`

All values are pre-multiplier; `TUN-MATCH-FINALPHASE-MULT` is applied at fold time to
events timestamped within the final phase. Derivations are in
[`BALANCE_MODEL.md`](BALANCE_MODEL.md).

| ID | Score event | Value | Unit | Range | Condition & rationale |
|---|---|---|---|---|---|
| `TUN-SCORE-CONTRACT` | `SCORE-CONTRACT` | 100 | pts | 100–100 | Any valid kill on your contract. **The unit of account** — every other value is expressed as a multiple of this, so it is fixed by definition, not tuned. |
| `TUN-SCORE-SILENT` | `SCORE-SILENT` | +100 | pts | 75–150 | Suspicion ≤ 29 (Anonymous) at initiation. Doubles the kill. The floor of good play. |
| `TUN-SCORE-PATIENT` | `SCORE-PATIENT` | +150 | pts | 100–200 | Never exceeded `TUN-SPEED-JOG` in the 10 s before initiation. The most valuable single bonus, because it is the thesis. |
| `TUN-SCORE-PATIENT-WINDOW` | — | 10.0 | s | 8–15 | The lookback window for `SCORE-PATIENT`. Long enough that it cannot be gamed by decelerating at the last moment. |
| `TUN-SCORE-MASKED` | `SCORE-MASKED` | +150 | pts | 100–200 | `ABIL-SECONDFACE` active at initiation. Equal to Patient: disguise is a *different* route to the same virtue. |
| `TUN-SCORE-FOCUS` | `SCORE-FOCUS` | +100 | pts | 75–150 | Unbroken line of sight on the contract for the last 6 s. Pays for the hardest thing in the game: standing still and watching one person in a moving crowd. |
| `TUN-SCORE-FOCUS-WINDOW` | — | 6.0 | s | 4–10 | The required unbroken-LOS duration. |
| `TUN-SCORE-FOCUS-BREAK-GRACE` | — | 0.4 | s | 0.2–0.8 | LOS may lapse this long (an NPC passing between you) without resetting the window. Without it the bonus is unearnable in a crowd — which is exactly where it should be earned. |
| `TUN-SCORE-FROMABOVE` | `SCORE-FROMABOVE` | +100 | pts | 75–150 | Initiated from ≥ `TUN-SCORE-FROMABOVE-HEIGHT` above the target. Pays for the roof route, which otherwise only costs. |
| `TUN-SCORE-FROMABOVE-HEIGHT` | — | 3.0 | m | 2.5–4.5 | Roughly one storey. Above balcony rail height, below full roof height, so both strata qualify. |
| `TUN-SCORE-BLENDED` | `SCORE-BLENDED` | +200 | pts | 150–250 | Inside a blend action within `TUN-BLEND-SCORE-GRACE` of initiation. **The largest bonus in the game**, because it is the purest expression of the thesis: you waited, hidden, in plain sight, and let them come to you. |
| `TUN-SCORE-POISONED` | `SCORE-POISONED` | +75 | pts | 50–125 | Delayed-kill ability. **Dormant in MVP** — no MVP ability triggers it. Reserved for post-MVP `ABIL-NIGHTSHADE`. (ASM-0016) |
| `TUN-SCORE-LONGHUNT-1` | `SCORE-LONGHUNT` | +50 | pts | 25–100 | Chase > `TUN-SCORE-LONGHUNT-T1` before the kill. |
| `TUN-SCORE-LONGHUNT-2` | `SCORE-LONGHUNT` | +150 | pts | 100–200 | Chase > `TUN-SCORE-LONGHUNT-T2`. Replaces, does not stack with, tier 1. |
| `TUN-SCORE-LONGHUNT-T1` | — | 20.0 | s | 15–30 | Tier-1 threshold, measured from contract assignment or from first Compass lock, whichever is later. |
| `TUN-SCORE-LONGHUNT-T2` | — | 45.0 | s | 35–70 | Tier-2 threshold. Pays for the patient stalk that the whole game is about, and specifically counteracts the incentive to rush a kill before someone else's contract graph shifts. |
| `TUN-SCORE-VENDETTA` | `SCORE-VENDETTA` | +100 | pts | 75–150 | Killing the player who last killed you. Only the most recent killer counts, and only until you die again. Emotional payoff, cheap to implement, generates stories. |
| `TUN-SCORE-VARIETY` | `SCORE-VARIETY` | +50 × n | pts | 25–75 | `n` = bonus types earned on this kill for the **first time in the current life**. Excludes itself, `SCORE-CONTRACT` and `SCORE-RECKLESS`. Resets on death. Pays for varying your approach across a streak. (ASM-0017) |
| `TUN-SCORE-RECKLESS` | `SCORE-RECKLESS` | −50 | pts | −100–−25 | Suspicion ≥ `TUN-SUSPICION-TIER-EXPOSED` at initiation. The only penalty. Makes a sprinting kill worth 50 points against a blended kill's 550+ — the 11× ratio the design brief demands, and then some. |
| `TUN-SCORE-STUN` | `SCORE-STUN` | 100 | pts | 75–150 | Equals `TUN-STUN-SCORE`. Defence pays like offence. |
| `TUN-SCORE-STUN-INVALID` | — | 0 | pts | — | Stunning a non-pursuer. Zero, plus `TUN-STUN-INVALID-STAGGER` and `TUN-STUN-INVALID-SUSPICION`. |
| `TUN-SCORE-DEATH-PENALTY` | — | 0 | pts | — | **Dying costs no points.** Only time. A points penalty for dying would make a losing player's position unrecoverable and would push them toward the safest, most boring play — which is the opposite of what a trailing player should do. |

### 11.1 Reference kill values

| Kill archetype | Bonuses | Total |
|---|---|---|
| Sprinting tackle-kill while Exposed | 100 − 50 | **50** |
| Careless but not Exposed | 100 | **100** |
| Clean walk-up kill | 100 + Silent 100 + Patient 150 | **350** |
| Watched, waited, struck | 100 + Silent 100 + Patient 150 + Focus 100 | **450** |
| The full patient blend kill | 100 + Silent 100 + Patient 150 + Focus 100 + Blended 200 | **650** |
| …plus Variety (5 new types) | + 250 | **900** |
| …in the Final Contract phase (2×) | | **1800** |

Ratio of the best patient kill to the sprint tackle: **13:1** (650 : 50), or 18:1 including
Variety. The brief requires 3–5×; the *best-case* spread is deliberately far wider.

The ratio that actually governs play is the **expected** one, once bonus-fire probabilities,
failure rates and time costs are modelled. That works out at **2.68 : 1** per kill and
**2.5 : 1** over a full match — derived in [`BALANCE_MODEL.md`](BALANCE_MODEL.md) §3 and
summarised in [`../10_gdd/07_balance.md`](../10_gdd/07_balance.md) §4. Note this is *stronger*
than it sounds: carried through to win probability it puts a patient player ahead of an
equally-skilled aggressive one in ~90 % of matches, against a ~60 % design target. That
discrepancy is deliberately **not** pre-tuned away before telemetry exists; the reasoning and
the ordered lever list are in [`../10_gdd/07_balance.md`](../10_gdd/07_balance.md) §4.6–§4.8.

---

## 12. Camera — `SYS-CAMERA`

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-CAM-FOV-BLEND` | 55.0 | deg | 50–60 | Narrow FOV at blend-walk. Compresses the scene and makes faces readable at 20 m — you are *looking at people*. |
| `TUN-CAM-FOV-STROLL` | 60.0 | deg | 55–65 | " |
| `TUN-CAM-FOV-JOG` | 65.0 | deg | 60–70 | " |
| `TUN-CAM-FOV-RUN` | 69.0 | deg | 64–74 | " |
| `TUN-CAM-FOV-SPRINT` | 72.0 | deg | 68–80 | Wide FOV at sprint. Speed lines and peripheral distortion. The camera itself tells you that you are doing something conspicuous. |
| `TUN-CAM-FOV-BLEND-RATE` | 90.0 | deg/s | 60–140 | FOV transition speed between states. Fast enough to track a speed change, slow enough not to snap. |
| `TUN-CAM-ARM-LENGTH` | 2.6 | m | 2.2–3.2 | Spring-arm length. Far enough to see your own silhouette (you must be able to judge how you look), close enough to keep the crowd legible. |
| `TUN-CAM-ARM-HEIGHT` | 1.55 | m | 1.4–1.8 | Pivot height — roughly shoulder height on the tallest persona. |
| `TUN-CAM-SHOULDER-OFFSET` | 0.45 | m | 0.3–0.7 | Lateral offset. |
| `TUN-CAM-SHOULDER-SWAP-TIME` | 0.25 | s | 0.15–0.4 | Time to swap shoulders. |
| `TUN-CAM-OCCLUSION-PULL-RATE` | 12.0 | m/s | 8–20 | Speed at which the arm pulls in on collision. Fast, because a camera stuck in a wall in a game about looking at people is a critical failure. |
| `TUN-CAM-OCCLUSION-RESTORE-RATE` | 4.0 | m/s | 2–8 | Speed of restoration. Slower than pull-in, to avoid oscillation in doorways. |
| `TUN-CAM-CROWDSCAN-SPEED` | 0.45 | × | 0.3–0.7 | Look-sensitivity multiplier while holding the crowd-scan input. Slow, precise panning for reading a crowd — the game's central act, given its own input. |
| `TUN-CAM-CROWDSCAN-FOV` | 48.0 | deg | 42–54 | FOV while crowd-scanning. Narrower than any speed state: leaning in. |

---

## 13. Networking — `SYS-NET-*`

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-NET-SERVER-TICK` | 30 | Hz | 30–30 | Server simulation and authority rate. Fixed: every gameplay system is written against it. (ASM-0020) |
| `TUN-NET-CLIENT-INPUT-RATE` | 60 | Hz | 60–60 | Client input sample and send rate. Two input commands per server tick, so a 16 ms input is never lost to tick aliasing. |
| `TUN-NET-SNAPSHOT-RATE` | 30 | Hz | 15–30 | Snapshot send rate to each client. Equals the tick rate in MVP; the hook to halve it under bandwidth pressure exists and is untested. |
| `TUN-NET-INTERP-BUFFER` | 100 | ms | 80–150 | Snapshot interpolation delay for remote entities. Three server ticks. Fixed, not adaptive, in MVP. (ASM-0021) |
| `TUN-NET-LAGCOMP-MIN` | 100 | ms | — | Minimum rewind for kill/stun validation. |
| `TUN-NET-LAGCOMP-MAX` | 200 | ms | 150–250 | Maximum rewind. The ceiling is the important half: it caps how far into the past a high-ping player may reach, putting the cost of bad connections on the player who has one. (ASM-0022) |
| `TUN-NET-LAGCOMP-HISTORY` | 500 | ms | 300–1000 | Length of the server's positional history ring buffer. 2.5× the max rewind, so the buffer is never the binding constraint. |
| `TUN-NET-RECONCILE-THRESHOLD` | 0.10 | m | 0.05–0.25 | Positional error above which the client replays its input buffer against the server state. Below it, error is smoothed silently. Set at 10 cm: smaller than a step, larger than float noise. |
| `TUN-NET-RECONCILE-SMOOTH-TIME` | 0.12 | s | 0.08–0.25 | Time over which a small correction is visually blended, so reconciliation never produces a visible snap. |
| `TUN-NET-INPUT-BUFFER-SIZE` | 32 | count | 16–64 | Client-side unacknowledged input history. ~0.5 s at 60 Hz. |
| `TUN-NET-BANDWIDTH-BUDGET-DOWN` | 96 | kbit/s | 64–160 | Per-client downstream budget at 6 players + 90 NPCs. Budget breakdown in [`../20_tdd/04_networking.md`](../20_tdd/04_networking.md) §7. |
| `TUN-NET-BANDWIDTH-BUDGET-UP` | 16 | kbit/s | 8–32 | Per-client upstream. Input commands only. |
| `TUN-NET-TIMEOUT` | 10.0 | s | 5–20 | Peer timeout before the server treats a client as disconnected and repairs the contract cycle. |
| `TUN-NET-QUANT-POS` | 0.01 | m | — | Position quantisation step for replication (1 cm). |
| `TUN-NET-QUANT-YAW` | 1.0 | deg | — | Yaw quantisation step (8 bits over 360°). |
| `TUN-NET-NPC-CULL-RADIUS` | 70.0 | m | 50–90 | NPCs beyond this radius from a client are not replicated to that client. Slightly beyond `TUN-COMPASS-RANGE-MAX` so a culled NPC can never affect anything the client can perceive. |

---

## 14. Performance budgets — see [`../30_bible/PERFORMANCE_BUDGET.md`](../30_bible/PERFORMANCE_BUDGET.md)

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-PERF-FRAME-BUDGET` | 16.6 | ms | — | 60 fps at 1080p on the reference machine. Non-negotiable target. |
| `TUN-PERF-CROWD-BUDGET` | 2.0 | ms | — | Total CPU for 90 NPCs: AI, navigation, animation LOD. Caps `TUN-CROWD-COUNT-MAX`. |
| `TUN-PERF-NET-BUDGET` | 1.5 | ms | — | Client-side serialisation, interpolation and reconciliation. |
| `TUN-PERF-GAMEPLAY-BUDGET` | 2.0 | ms | — | Suspicion, detection, abilities, scoring on the client mirror. |
| `TUN-PERF-UI-BUDGET` | 1.0 | ms | — | HUD, Compass, score feed. |
| `TUN-PERF-RENDER-BUDGET` | 9.0 | ms | — | Everything the renderer does. |
| `TUN-PERF-SERVER-TICK-BUDGET` | 8.0 | ms | — | Headless server, per 33 ms tick. Leaves 25 ms of headroom — a server that is merely *usually* on time produces intermittent, unreproducible feel bugs. |
| `TUN-PERF-CROWD-LOD-NEAR` | 20.0 | m | 15–30 | Full animation and 30 Hz AI update inside this radius. |
| `TUN-PERF-CROWD-LOD-MID` | 45.0 | m | 30–60 | Reduced animation, 10 Hz AI update. |
| `TUN-PERF-CROWD-LOD-FAR` | 70.0 | m | — | Beyond: 2 Hz AI, no animation, impostor rendering. Equals `TUN-NET-NPC-CULL-RADIUS`. |

**Note on LOD and fairness:** animation LOD must never change an NPC's *silhouette or gait*
inside `TUN-COMPASS-RANGE-MAX`, because that is a distance at which a player is trying to
distinguish clones from players. LOD may reduce fidelity; it may not change what the crowd
*says*. This constraint is why `TUN-PERF-CROWD-LOD-MID` is set at 45 m rather than lower.

---

## 15. UI and audio timing

| ID | Value | Unit | Range | Rationale |
|---|---|---|---|---|
| `TUN-UI-READABILITY-TARGET` | 0.5 | s | — | Every HUD state must be parseable in this long. The test procedure is in [`../30_bible/UI_UX_SPEC.md`](../30_bible/UI_UX_SPEC.md) §9. |
| `TUN-UI-SCOREFEED-DURATION` | 4.0 | s | 3–6 | How long a score-feed line persists. Long enough to read three stacked bonuses. |
| `TUN-UI-SCOREFEED-MAX-LINES` | 4 | count | 3–6 | Simultaneous lines before the oldest is dropped. |
| `TUN-UI-SCOREFEED-STAGGER` | 0.12 | s | 0.08–0.25 | Delay between stacked bonuses appearing on one kill. They arrive as a *sequence*, which is far more readable — and more satisfying — than a block. |
| `TUN-UI-TIER-TRANSITION-TIME` | 0.25 | s | 0.15–0.4 | Visual transition when your own suspicion tier changes. |
| `TUN-UI-DAMAGE-VIGNETTE-TIME` | 0.8 | s | — | Duration of the exposed-tier screen-edge vignette fade. |
| `TUN-AUDIO-COMPASS-DUCK` | −6.0 | dB | −3–−12 | Ducking applied to ambience when the Compass pulse plays. The pulse must never be masked by crowd noise: it is the primary information channel. |
| `TUN-AUDIO-STING-DUCK` | −12.0 | dB | −8–−18 | Ducking on the prey warning sting. Aggressive, because this is the single most important sound in the game. |
| `TUN-AUDIO-OCCLUSION-LOWPASS` | 900 | Hz | 600–1600 | Low-pass cutoff for sound sources occluded by geometry. |
| `TUN-AUDIO-FOOTSTEP-RADIUS-BLEND` | 4.0 | m | 3–6 | Audible radius of a blend-walking player's footsteps. |
| `TUN-AUDIO-FOOTSTEP-RADIUS-SPRINT` | 18.0 | m | 12–26 | Audible radius at sprint. 4.5× — running is *loud*, and the audio channel is a genuine, unblockable information leak. |

---

## 16. Player-count scaling

Values that change with lobby size. Everything not listed here is constant.

| Tunable | 4 players | 5 players | 6 players (centre) | Rationale |
|---|---|---|---|---|
| `TUN-CROWD-COUNT-DEFAULT-4P` / `-5P` / `-6P` | 66 | 72 | 78 | Fewer players need fewer clones for equal per-player anonymity. *Corrected 2026-08-04: this row previously cited `TUN-CROWD-COUNT`, which has no definition row anywhere — see §9.* |
| Clones per persona | 10 | 11 | 12 | Derived: `(count − filler) / 4`. |
| Filler count | 26 | 28 | 30 | Roughly constant — the city's texture does not depend on lobby size. |
| Playable area | Inner 90 × 90 m | Full | Full | At 4 players the outer ring is soft-bounded (see [`../10_gdd/05_level_design.md`](../10_gdd/05_level_design.md) §6), so encounters stay frequent. |
| `TUN-COMPASS-RANGE-MAX` | 50 m | 55 m | 60 m | Scaled with the playable area so signal density is constant. |
| `TUN-MATCH-DURATION` | 480 s | 480 s | 480 s | Unchanged. Match length is a scheduling property, not a balance one. |
| Expected kills/player/match | ~4.0 | ~4.3 | ~4.6 | Modelled in [`BALANCE_MODEL.md`](BALANCE_MODEL.md) §3. |

---

## 17. Validation rules (asserted by `test_tuning_ranges.gd`)

Beyond each row's own Range, these cross-field invariants are asserted at load:

| # | Invariant | Why |
|---|---|---|
| 1 | `TUN-SPEED-BLENDWALK == TUN-CROWD-NPC-SPEED-STROLL` | A player at blend-walk must be indistinguishable from an NPC by motion. The single most important invariant in the file. |
| 2 | `TUN-SPEED-BLENDWALK < STROLL < JOG < RUN < SPRINT` | The ladder must be monotonic. |
| 3 | `TUN-SUSPICION-DECAY-SPEED-CEILING == TUN-SPEED-STROLL` | The decay cliff sits exactly at the top civilian speed. |
| 4 | `TUN-SUSPICION-TIER-NOTICED < TUN-SUSPICION-TIER-EXPOSED` | — |
| 5 | `TUN-SUSPICION-HYSTERESIS < TUN-SUSPICION-TIER-NOTICED` | Hysteresis cannot exceed the first tier or a player can never leave it. |
| 6 | `TUN-STUN-RANGE > TUN-KILL-RANGE` | The prey's reach must exceed the hunter's. Non-negotiable. |
| 7 | `TUN-STUN-MIN-TIER == TUN-SUSPICION-TIER-NOTICED` | An Anonymous hunter is unstunnable; patience is genuinely safe. |
| 8 | `TUN-COMPASS-WARN-MIN-TIER == TUN-SUSPICION-TIER-NOTICED` | The prey warning and the stun gate use the same threshold, so "I can stun them" and "I was warned about them" are the same condition. Two thresholds here would be unlearnable. |
| 9 | `TUN-COMPASS-PULSE-MIN < TUN-COMPASS-PULSE-MAX` | — |
| 10 | `TUN-COMPASS-LOCK-RANGE < TUN-COMPASS-RANGE-MAX` | — |
| 11 | `TUN-WHISPERBOLT-RANGE-MIN > TUN-KILL-RANGE` | Whisperbolt may never substitute for melee. |
| 12 | `TUN-CINDERFALL-RADIUS >= 2 × TUN-KILL-RANGE` | The cloud must actually deny a kill attempt, not merely obscure one. |
| 13 | `TUN-CROWD-GAWK-DURATION < TUN-CORPSE-LIFETIME` | Two distinct information phases. |
| 14 | `TUN-CROWD-NPC-SPEED-FLEE < TUN-SPEED-SPRINT` | A sprinting player cannot hide inside a startle wave. |
| 15 | `TUN-KILL-ANIM-DURATION <= TUN-FEEL-MAX-COMMIT` | — |
| 16 | `TUN-NET-LAGCOMP-MAX <= TUN-NET-LAGCOMP-HISTORY / 2` | The history buffer is never the binding constraint. |
| 17 | `TUN-NET-NPC-CULL-RADIUS >= TUN-COMPASS-RANGE-MAX` | A culled NPC can never affect anything the client can perceive. |
| 18 | `TUN-SCORE-BLENDED > TUN-SCORE-PATIENT > TUN-SCORE-SILENT` | The bonus hierarchy encodes the design thesis. If a tuning change inverts it, the tuning change is wrong. |
| 19 | `TUN-SCORE-STUN == TUN-SCORE-CONTRACT` | Defence pays like offence. |
| 20 | `sum(TUN-PERF-*-BUDGET for client) <= TUN-PERF-FRAME-BUDGET` | The budget must actually add up. Currently 15.5 / 16.6 ms, leaving 1.1 ms of margin. |

---

## 18. Open questions

| # | Question | Blocking? | Needed by |
|---|---|---|---|
| 1 | Is `TUN-SUSPICION-GAIN-WITNESSED-KILL` (§3.3) an addition beyond the brief? Yes — it was added to give theatre spaces mechanical weight. It can be set to 0 to disable without any other change. | No | M4 |
| 2 | `TUN-COMPASS-RANGE-MAX` scaling by player count (§16) assumes the map soft-bounds at 4 players. If the soft-bound is cut, this scaling must be cut too. | No | M5 |
| 3 | `TUN-SCORE-DEATH-PENALTY = 0` is a strong design position. If playtests show players suiciding to reroll a bad contract, a small penalty or a respawn-delay escalation is the first lever. | No | M6 |
| 4 | Whether `TUN-NET-SNAPSHOT-RATE` can be halved to 15 Hz for distant NPCs. Would buy ~30 % of the bandwidth budget. Untested. | No | M3 |
